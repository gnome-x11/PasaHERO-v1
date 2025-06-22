//dart packeges
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

//map packages
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

//firebase pacakges
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:transit/helpers/jpurney_step.dart';

//models
import '../models/route_cards.dart';
import '../../models/journey_plan.dart';
import '../../models/custom_prediction.dart';

// helpers
import '../helpers/alarm_manager.dart';
import '../helpers/loadgpx_files.dart';
import '../helpers/location.dart';
import '../helpers/user_service.dart';
import '../helpers/navigation_helper.dart';
import '../helpers/journey_content.dart';
import '../helpers/home_tutorial.dart';
import '../helpers/noti_service.dart';

// utils
import '../../utils/custom_markers.dart';
import '../utils/journey_planner.dart';
import '../utils/search_service.dart';

// pages
import '../login_page.dart';
import 'about_us_page.dart';
import 'saved_routes_page.dart';
import 'account_settings_page.dart';

//google api key
final String googleApiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
final String graphHopperApiKey = dotenv.env['GRAPHHOPPER_API_KEY'] ?? '';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PasaHERO',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomePage(title: 'Home Page'),
      builder: (context, child) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: child!,
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.title,
    this.initialStart,
    this.initialEnd,
  });

  final String title;
  final LatLng? initialStart;
  final LatLng? initialEnd;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  //home tutorial state
  final GlobalKey _logoIconKey = GlobalKey();
  final GlobalKey _searchToggleKey = GlobalKey();
  final GlobalKey _trafficToggleKey = GlobalKey();
  final GlobalKey _locationButtonKey = GlobalKey();

  // user info state
  late SearchService _searchService;
  String userName = "Loading...";
  bool _isDialogShowing = false;

  //map state
  final LatLng _initialLocation = const LatLng(14.4126, 121.0343);
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  List<Polyline> _originalPolylines = [];
  LatLng? _startLocationPoint;
  LatLng? _destinationPoint;
  final keyboardVisible = false;
  bool _isLoading = false;
  bool isAlarmAcknowledged = false;

  //navigation state
  StreamSubscription<Position>? _positionStream;
  String _nextInstruction = "";
  int timeRemaining = 0;
  double distanceRemaining = 0.0;
  GoogleMapController? _mapController;
  bool trafficEnabled = false;
  void _toggleTraffic() {
    setState(() {
      trafficEnabled = !trafficEnabled;
    });
  }

  // searchbar state
  bool _showSearchBar = false;
  bool _showStartPredictions = false;
  bool _showDestPredictions = false;
  bool _isNavigating = false;
  final TextEditingController _routeNameController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _startLocationController =
      TextEditingController();
  List<CustomPrediction> _customStartPredictions = [];
  List<CustomPrediction> _customDestPredictions = [];
  List<CustomPrediction> _searchHistory = [];
  Timer? _debounce;

  // alarm state
  late AlarmManager _alarmManager;
  Set<Circle> _alarmCircles = {};
  late VoidCallback _startListener;
  late VoidCallback _destListener;
  final FocusNode _startLocationFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
    });
    _searchService = SearchService(
      googleApiKey: googleApiKey,
      currentLocation: currentLocation,
    );
    if (widget.initialStart != null && widget.initialEnd != null) {
      _loadSavedRoute(widget.initialStart!, widget.initialEnd!);
    }
    _alarmManager = AlarmManager();
    _alarmManager.initialize();
    _fetchUserName();
    _getUserLocation();
    _setupTextControllerListeners();
    findNearestJeepneyStopWithIndex;
    _loadSearchHistory();
    loadGPX();
    HomeTutorial(
      context: context,
      logoIconKey: _logoIconKey,
      searchToggleKey: _searchToggleKey,
      trafficToggleKey: _trafficToggleKey,
      locationButtonKey: _locationButtonKey,
    ).showIfFirstLaunch();
  }

  @override
  void dispose() {
    _startLocationFocusNode.dispose();
    _destinationFocusNode.dispose();
    _positionStream?.cancel();
    _alarmManager.dispose();
    _mapController?.dispose();
    _startLocationController.dispose();
    _destinationController.dispose();
    _stopNavigation();
    _mapController?.dispose();
    _startLocationController.removeListener(_setupTextControllerListeners);
    _destinationController.removeListener(_setupTextControllerListeners);
    _startLocationFocusNode.dispose();
    _destinationFocusNode.dispose();
    _startLocationController.dispose();
    _destinationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _loadSavedRoute(LatLng start, LatLng end) async {
    _startLocationController.text =
        await _searchService.getAddressFromLatLngV2(start);
    _destinationController.text =
        await _searchService.getAddressFromLatLngV2(end);
    _startLocationPoint = start;
    _destinationPoint = end;
    await updateMarkers(
      context: context,
      startLocationPoint: _startLocationPoint,
      destinationPoint: _destinationPoint,
      startLocationController: _startLocationController,
      destinationController: _destinationController,
      onUpdate: (newMarkers, newPolylines) {
        setState(() {
          markers = newMarkers;
          polylines = newPolylines;
        });
      },
    );
  }

// For user name
  Future<void> _fetchUserName() async {
    final name = await UserService.fetchUserName();
    if (mounted) {
      setState(() {
        userName = name;
      });
    }
  }

// For location
  Future<void> _getUserLocation() async {
    final location = await LocationService.getUserLocation(context);
    if (location != null && mounted) {
      setState(() {
        currentLocation = location as LatLng?;
      });
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: currentLocation ?? _initialLocation, zoom: 15),
        ),
      );
    }
  }

// For sign out
  void _signOut(BuildContext context) async {
    await UserService.signOut(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Signed out successfully"),
        backgroundColor: Colors.redAccent,
      ),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginRegisterPage()),
    );
  }

  void _setupTextControllerListeners() {
    _startListener = () {
      if (_startLocationController.text.isNotEmpty &&
          _startLocationPoint == null) {
        _onTextChanged(_startLocationController.text, true);
      } else {
        setState(() {
          _showStartPredictions = true;
        });
      }
    };

    _destListener = () {
      if (_destinationController.text.isNotEmpty && _destinationPoint == null) {
        _onTextChanged(_destinationController.text, false);
      } else {
        setState(() {
          _customDestPredictions = [];
          _showDestPredictions = false;
        });
      }
    };

    _startLocationController.addListener(_startListener);
    _destinationController.addListener(_destListener);
  }

  void _onTextChanged(String input, bool isStart) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      getCustomPredictions(input, isStart);
    });
  }

  Widget _buildSectionHeader(String title, VoidCallback? onClear) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          if (onClear != null)
            TextButton(
              onPressed: onClear,
              child: const Text("Clear", style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hintText,
    required bool isStart,
    IconData leadingIcon = Icons.location_on,
    Color iconColor = Colors.grey,
    TextStyle? hintTextStyle,
  }) {
    return Container(
      decoration: isStart
          ? BoxDecoration(
              border: Border(
                  bottom: BorderSide(
              color: Color.fromARGB(69, 183, 183, 183),
              width: 1.2,
            )))
          : null,
      child: Row(
        children: [
          isStart
              ? Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(Icons.my_location_outlined, color: iconColor))
              : Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(Icons.location_on_outlined, color: iconColor)),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode:
                  isStart ? _startLocationFocusNode : _destinationFocusNode,
              decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: hintTextStyle ?? TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
              onTap: () {
                setState(() {
                  if (isStart) {
                    _showStartPredictions = true;
                    _showDestPredictions = false;
                  } else {
                    _showStartPredictions = false;
                    _showDestPredictions = true;
                  }
                });
              },
            ),
          ),
          IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey),
              onPressed: () {
                _clearTextField(isStart);
                if (isStart) {
                  _startLocationFocusNode.unfocus();
                } else {
                  _destinationFocusNode.unfocus();
                }
              }),
        ],
      ),
    );
  }

  void _clearTextField(bool isStart) {
    setState(() {
      if (isStart) {
        _startLocationController.clear();
        _startLocationPoint = null;
        _customStartPredictions = [];
        _showStartPredictions = false;
      } else {
        _destinationController.clear();
        _destinationPoint = null;
        _customDestPredictions = [];
        _showDestPredictions = false;
      }
      updateMarkers(
        context: context,
        startLocationPoint: _startLocationPoint,
        destinationPoint: _destinationPoint,
        startLocationController: _startLocationController,
        destinationController: _destinationController,
        onUpdate: (newMarkers, newPolylines) {
          setState(() {
            markers = newMarkers;
            polylines = newPolylines;
          });
        },
      );
    });
  }

  void _toggleSearchBar() {
    _startLocationFocusNode.unfocus();
    _destinationFocusNode.unfocus();
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (_showSearchBar) {
        _showStartPredictions = false;
        _showDestPredictions = false;
      }
    });
  }

  Widget _buildPredictionsList({
    required List<CustomPrediction> predictions,
    required bool isStart,
  }) {
    List<CustomPrediction> combinedList = [
      ..._searchHistory,
      ...predictions,
    ];

    return SizedBox(
      child: Stack(
        children: [
          Positioned(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 360),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4)
                ],
              ),
              child: ListView.builder(
                  shrinkWrap: true,
                  physics: BouncingScrollPhysics(),
                  itemCount: combinedList.length +
                      (_searchHistory.isNotEmpty ? 1 : 0) +
                      (predictions.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    int headerOffset = 0;
                    if (index == 0 && _searchHistory.isNotEmpty) {
                      return _buildSectionHeader(
                          "Recent Searches", clearSearchHistory);
                    } else if (_searchHistory.isNotEmpty) {
                      headerOffset += 1;
                      if (index <= _searchHistory.length) {
                        final recentItem = _searchHistory[index - 1];
                        return ListTile(
                          title: Text(recentItem.description),
                          leading: Icon(
                            recentItem.isCurrentLocation
                                ? Icons.my_location
                                : Icons.history,
                            color: recentItem.isCurrentLocation
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          onTap: () =>
                              _onPredictionSelected(recentItem, isStart),
                        );
                      }
                      headerOffset += _searchHistory.length;
                    }

                    if (predictions.isNotEmpty &&
                        index == headerOffset &&
                        predictions.isNotEmpty) {
                      return _buildSectionHeader("Suggested Locations", null);
                    } else if (predictions.isNotEmpty) {
                      headerOffset += 0;
                      final predictionIndex = index - headerOffset;
                      if (predictionIndex < predictions.length) {
                        final prediction = predictions[predictionIndex];
                        return ListTile(
                          title: Text(prediction.description),
                          leading: Icon(
                            prediction.isCurrentLocation
                                ? Icons.my_location
                                : Icons.location_on,
                            color: prediction.isCurrentLocation
                                ? Colors.blue
                                : (isStart ? Colors.blue : Colors.red),
                          ),
                          onTap: () =>
                          _onPredictionSelected(prediction, isStart),
                        );
                      }
                    }
                    return const SizedBox.shrink();

                  }),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> getCustomPredictions(String input, bool isStart) async {
    if (input.isEmpty) return;

    _searchService.updateCurrentLocation(currentLocation);
    final predictions = await _searchService.getCustomPredictions(input);
    if (mounted) {
      setState(() {
        if (isStart) {
          _customStartPredictions = predictions;
          _showStartPredictions = predictions.isNotEmpty;
          _showDestPredictions = false;
        } else {
          _customDestPredictions = predictions;
          _showDestPredictions = predictions.isNotEmpty;
          _showStartPredictions = false;
        }
      });
    }
  }

  Future<LatLng?> getPlaceDetails(String placeId) async {
    if (placeId == "current_location" && currentLocation != null) {
      return currentLocation;
    }

    try {
      final String url =
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$googleApiKey';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        double lat = data['result']['geometry']['location']['lat'];
        double lng = data['result']['geometry']['location']['lng'];
        return LatLng(lat, lng);
      }
    } catch (e) {
      print("Error fetching place details: $e");
    }
    return null;
  }

  Future<void> _useCurrentLocation() async {
    if (currentLocation != null) {
      try {
        String address =
            await _searchService.getAddressFromLatLngV2(currentLocation!);

        setState(() {
          _startLocationController.text = address;
          _startLocationPoint = currentLocation;
          _showStartPredictions = false;
          _showDestPredictions = false;
          _showSearchBar = false;
          updateMarkers(
            context: context,
            startLocationPoint: _startLocationPoint,
            destinationPoint: _destinationPoint,
            startLocationController: _startLocationController,
            destinationController: _destinationController,
            onUpdate: (newMarkers, newPolylines) {
              setState(() {
                markers = newMarkers;
                polylines = newPolylines;
              });
            },
          );

          _searchHistory.removeWhere((entry) => entry.description == address);
          _searchService.saveSearchHistory(_searchHistory);
        });

        _mapController?.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(target: currentLocation!, zoom: 20)));
      } catch (e) {
        print("Error getting address: $e");
      }
    }
  }

  void _onPredictionSelected(CustomPrediction prediction, bool isStart) async {
    if (isStart) {
      _startLocationFocusNode.unfocus();
    } else {
      _destinationFocusNode.unfocus();
    }

    if (!_searchHistory
        .any((entry) => entry.description == prediction.description)) {
      _searchHistory.insert(
          0,
        CustomPrediction(
          description: prediction.description,
          placeId: prediction.placeId,
          isHistory: false,
          isCurrentLocation: prediction.isCurrentLocation,
        ),
      );
      await _searchService.saveSearchHistory(_searchHistory);
    }

    if (prediction.isCurrentLocation) {
      _useCurrentLocation();
      return;
    }

    LatLng? location = await _searchService.getPlaceDetails(prediction.placeId);
    if (location == null) return;

    setState(() {
      if (isStart) {
        _startLocationController.text = prediction.description;
        _startLocationPoint = location;
        _showStartPredictions = false;
      } else {
        _destinationController.text = prediction.description;
        _destinationPoint = location;
        _showDestPredictions = false;
      }
      _showSearchBar = false;

      _searchHistory
          .removeWhere((entry) => entry.description == prediction.description);
      _searchHistory.insert(
        0,
        CustomPrediction(
          description: prediction.description,
          placeId: prediction.placeId,
          isHistory: true,
        ),
      );

      _searchService.saveSearchHistory(_searchHistory);
      updateMarkers(
        context: context,
        startLocationPoint: _startLocationPoint,
        destinationPoint: _destinationPoint,
        startLocationController: _startLocationController,
        destinationController: _destinationController,
        onUpdate: (newMarkers, newPolylines) {
          setState(() {
            markers = newMarkers;
            polylines = newPolylines;
          });
        },
      );
    });

    _mapController?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: location, zoom: 20),
    ));
  }

  Future<void> _loadSearchHistory() async {
    final history = await _searchService.loadSearchHistory();
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> clearSearchHistory() async {
    await _searchService.clearSearchHistory();
    setState(() {
      _searchHistory.clear();
    });
  }

  Future<int> getDurationInMinutes(
      LatLng start, LatLng end, String mode) async {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&mode=$mode&key=$googleApiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final durationSec = data['routes'][0]['legs'][0]['duration']['value'];
      return (durationSec / 60).round(); // return in minutes
    } else {
      throw Exception('Failed to get duration from Directions API');
    }
  }

  Future<Map<String, dynamic>> _buildStepByStepGuide(
      JourneyPlan journeyPlan) async {
    final steps = <Widget>[];
    final journeySteps = <JourneyStep>[];
    final walkingDistanceThreshold = 10;

    // Add initial walk to first boarding point
    if (journeyPlan.walkingSegments.isNotEmpty &&
        journeyPlan.walkingSegments.first.isNotEmpty) {
      final distance = calculateWalkDistance(journeyPlan.walkingSegments.first);
      if (distance > walkingDistanceThreshold) {
        final boardingPoint = journeyPlan.vehicleSegments.first.boardingPoint;

        // Get address of destination point of the walk
        final boardingAddress =
            await _searchService.getAddressFromLatLngV2(boardingPoint);

        // Calculate walking duration using Directions API for more accurate time
        // Calculate total walking distance for the segment
        final walkPoints = journeyPlan.walkingSegments.first;
        double totalWalkDistance = 0.0;
        for (int i = 0; i < walkPoints.length - 1; i++) {
          totalWalkDistance +=
              calculateDistance(walkPoints[i], walkPoints[i + 1]);
        }
        // Estimate duration based on average walking speed (1.4 m/s ≈ 5 km/h)
        final duration =
            (totalWalkDistance / 1.4 / 60).round(); // duration in minutes

        steps.add(WalkCard(
          distance: distance,
          direction: 'Walk to $boardingAddress',
          duration: duration, // ← show destination
        ));

        journeySteps.add(JourneyStep(
            type: 'walk', price: 0, duration: duration, distance: distance));
      }
    }

    // Add vehicle segments
    for (int i = 0; i < journeyPlan.vehicleSegments.length; i++) {
      final segment = journeyPlan.vehicleSegments[i];
      final boardingAddress =
          await _searchService.getAddressFromLatLngV2(segment.boardingPoint);
      final alightingAddress =
          await _searchService.getAddressFromLatLngV2(segment.alightingPoint);

      final duration = await getDurationInMinutes(
        segment.boardingPoint,
        segment.alightingPoint,
        'motor',
      );

      if (segment.route.vehicleType == 'tricycle') {
        steps.add(TricycleCard(
            routeName: segment.route.displayName,
            boarding: boardingAddress,
            alighting: alightingAddress,
            distance: distanceRemaining,
            duration: duration));
        journeySteps.add(JourneyStep(
          type: 'tricycle',
          price: 13,
          duration: duration,
          distance: distanceRemaining,
        ));
      } else {
        steps.add(JeepCard(
          routeName: segment.route.displayName,
          boarding: boardingAddress,
          alighting: alightingAddress,
          distance: distanceRemaining,
          duration: duration,
        ));
        journeySteps.add(JourneyStep(
            type: 'jeep',
            price: 13,
            duration: duration,
            distance: distanceRemaining));
      }

      // Add transfer walk
      if (i < journeyPlan.vehicleSegments.length - 1) {
        final nextSegment = journeyPlan.vehicleSegments[i + 1];
        final transferDistance = calculateDistance(
            segment.alightingPoint, nextSegment.boardingPoint);
        if (transferDistance > walkingDistanceThreshold) {
          final nextBoardingAddress = await _searchService
              .getAddressFromLatLngV2(nextSegment.boardingPoint);

          final duration = await getDurationInMinutes(
            segment.alightingPoint,
            nextSegment.boardingPoint,
            'walking',
          );

          steps.add(WalkCard(
            distance: transferDistance,
            direction: 'Walk to $nextBoardingAddress',
            duration: duration, // ← transfer destination
          ));
          journeySteps.add(JourneyStep(
              type: 'walk',
              price: 0,
              duration: duration,
              distance: distanceRemaining));
        }
      }
    }

    final lastWalkSegment = journeyPlan.walkingSegments.last;
    if (lastWalkSegment.length > 1) {
      final distance = calculateWalkDistance(lastWalkSegment);
      if (distance > walkingDistanceThreshold) {
        final start = lastWalkSegment.first;
        final end = lastWalkSegment.last;

        final destinationAddress =
            await _searchService.getAddressFromLatLngV2(_destinationPoint!);

        int duration = await getDurationInMinutes(start, end, 'walking');
        if (duration == 0 || duration > 30) {
          // fallback if too big or failed
          duration = (distance / 1.4 / 60).round();
        }

        steps.add(WalkCard(
          distance: distance,
          direction: 'Walk to $destinationAddress',
          duration: duration,
        ));
        journeySteps.add(JourneyStep(
          type: 'walk',
          price: 0,
          duration: duration,
          distance: distance,
        ));
      }
    }

    // Add arrival card
    steps.add(ArrivalCard(destination: _destinationController.text));

    // RETURN both UI widgets and journey steps
    return {
      'steps': steps,
      'journeySteps': journeySteps,
    };
  }

  void _showBottomSheet(
      BuildContext context, Future<JourneyPlan?> journeyFuture) {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: FutureBuilder<JourneyPlan?>(
            future: journeyFuture,
            builder: (context, snapshot) {
              return JourneyContent(
                snapshot: snapshot,
                routeNameController: _routeNameController,
                onSaveRoute: _saveRouteToFirestore,
                startLocationController: _startLocationController,
                destinationController: _destinationController,
                buildStepByStepGuide: _buildStepByStepGuide,
              );
            },
          ),
        );
      },
    );
  }

  void _showInfoBottomSheet(BuildContext context) {
    String travelDirection = determineTravelDirection(
      _startLocationPoint!,
      _destinationPoint!,
    );

    final startRoute = findNearestRoute(_startLocationPoint!,
        preferredDirection: travelDirection);
    final destRoute = findNearestRoute(_destinationPoint!,
        preferredDirection: travelDirection);

    if (startRoute == null || destRoute == null) {
      _showSnackBar(context, "No available routes found");
      return;
    }

    final journeyFuture = calculateJourneyPlan(
      startPoint: _startLocationPoint!,
      endPoint: _destinationPoint!,
      startRoute: startRoute,
      destRoute: destRoute,
    );

    _showBottomSheet(context, journeyFuture);
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  Future<List<LatLng>> snapToRoads(List<LatLng> points) async {
    const maxPointsPerRequest = 100;
    List<LatLng> allSnappedPoints = [];

    for (int i = 0; i < points.length; i += maxPointsPerRequest) {
      int end = i + maxPointsPerRequest;
      if (end > points.length) end = points.length;
      var batch = points.sublist(i, end);

      final path = batch.map((p) => '${p.latitude},${p.longitude}').join('|');
      final url = Uri.parse(
        'https://roads.googleapis.com/v1/snapToRoads?path=$path&interpolate=true&key=$googleApiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        var snappedBatch = (data['snappedPoints'] as List)
            .map((p) =>
                LatLng(p['location']['latitude'], p['location']['longitude']))
            .toList();
        allSnappedPoints.addAll(snappedBatch);
      } else {
        throw Exception('Failed to snap to roads: ${response.body}');
      }
    }

    return allSnappedPoints;
  }

  Future<void> _startNavigation() async {
    _alarmManager.startMonitoring();
    await _alarmManager.initialize();
    List<Polyline> snappedPolylines = [];
    for (var polyline in polylines) {
      List<LatLng> snappedPoints = await snapToRoads(polyline.points);
      snappedPolylines.add(Polyline(
        polylineId: polyline.polylineId,
        points: snappedPoints,
        color: polyline.color,
        width: polyline.width,
      ));
    }

    final getOffPoints = _getAllGetOffPoints();
    _alarmManager.setAlarms(getOffPoints, radius: 50.0);
    _alarmManager.startMonitoring();

    _originalPolylines = snappedPolylines;
    _updateNavigationInfo(_startLocationPoint!);

    setState(() {
      _isNavigating = true;
      polylines = snappedPolylines.toSet();
      _alarmCircles = getOffPoints
          .map((point) => Circle(
                circleId:
                    CircleId('alarm_${point.latitude}_${point.longitude}'),
                center: point,
                radius: _alarmManager.alarmRadius ?? 50.0,
                strokeWidth: 2,
                strokeColor: Colors.red.withOpacity(0.7),
                fillColor: Colors.red.withOpacity(0.2),
              ))
          .toSet();
    });

    _showInfoBottomSheet(context);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((Position position) async {
      if (!_isNavigating) return;

      final currentPos = LatLng(position.latitude, position.longitude);

      for (final circle in _alarmCircles) {
        final distance = calculateDistance(currentPos, circle.center);
        if (distance <= circle.radius &&
            !_alarmManager.isAcknowledged(circle.center)) {
          _showAlarmDialog(circle.center);
          _alarmManager.triggerAlarm();
          break;
        }
      }

      _updateAlarmCircles();

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentPos,
            zoom: 20,
            bearing: position.heading,
            tilt: 45,
          ),
        ),
      );
    });
  }

  void _updateNavigationInfo(LatLng currentPos) {
    final result = updateNavigationInfo(
      currentPos: currentPos,
      originalPolylines: _originalPolylines,
      destinationPoint: _destinationPoint!,
      currentInstruction: _nextInstruction,
      isNavigating: _isNavigating,
    );

    setState(() {
      polylines = result.updatedPolylines;
      distanceRemaining = result.distanceRemaining;
      timeRemaining = result.timeRemaining;
      _nextInstruction = result.nextInstruction;
    });
  }

  List<LatLng> _getAllGetOffPoints() {
    final points = <LatLng>[];
    for (var marker in markers) {
      if (marker.infoWindow.title?.contains("Drop off location") == true ||
          marker.infoWindow.title?.contains('End') == true) {
        points.add(marker.position);
      }
    }
    return points;
  }

  void _updateAlarmCircles() {
    _alarmCircles.clear();
    for (var marker in markers) {
      if (marker.infoWindow.title?.contains("Drop off location") == true ||
          marker.infoWindow.title?.contains("End") == true) {
        _alarmCircles.add(Circle(
          circleId: CircleId(
              'alarm_${marker.position.latitude}_${marker.position.longitude}'),
          center: marker.position,
          radius: _alarmManager.alarmRadius ?? 50.0,
          strokeWidth: 2,
          strokeColor: Colors.orange.withOpacity(0.5),
          fillColor: Colors.orange.withOpacity(0.2),
        ));
      }
    }
    setState(() {});
  }

  void _stopNavigation() {
    _positionStream?.cancel();
    _positionStream = null;
    _alarmManager.dispose();
    setState(() {
      _isNavigating = false;
      _alarmCircles.clear();
      _originalPolylines = polylines.toList();
    });
  }

  void _showAlarmDialog(LatLng point) {
    if (_isDialogShowing) return;
    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("Time to Get Off!"),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 220, 138, 6),
        ),
        content:
            Text("You're approaching your stop. Please prepare to get off."),
        backgroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () {
              _alarmManager.acknowledgeAlarm(point);
              Navigator.of(context).pop();
              _isDialogShowing = false;
            },
            child: Text("OK"),
          ),
        ],
      ),
    );
    final notiService = NotiService();
    notiService.showNotification(
      title: "You are about to get off",
      body: 'Please get ready to get off!',
    );
  }

  void _showEndNavigationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("Are you sure you want to stop your navigation?"),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 220, 138, 6),
        ),
        content: Text("Check all your alarms if you reached your destination."),
        backgroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () {
              final notiService = NotiService();
              notiService.showNotification(
                title: "Navigation Ended",
                body:
                    'Need another guide? Search for a route, PasaHERO is here to help!',
              );

              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => HomePage(title: 'Home')),
              );
            },
            child: Text("OK"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _cancelNavigation() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(title: 'Home'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var buildLocationButton = _buildLocationButton();
    var buildTrafficButton = _buildTrafficButton();
    var gestureDetector = GestureDetector(
      onTap: _toggleTraffic,
      child: buildTrafficButton,
    );
    var buildSearchToggleButton = _buildSearchToggleButton();
    var buildSearchBar = _buildSearchBar();
    var buildNavigationHeader = _buildNavigationHeader();
    var buildStartNavigationButton = _buildStartNavigationButton();
    var buildCancelNavigationButton = _buildCancelNavigationButton();
    var buildEndNavigation = _buildEndNavigation();
    var buildDrawer = _buildDrawer();
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Color.fromARGB(255, 26, 163, 94),
          title: Text(
            'PasaHERO',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 25,
            ),
          ),
          iconTheme: IconThemeData(
            color: Colors.white,
          ),
          toolbarHeight: 65,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(5),
            ),
          ),
          actions: [
            IconButton(
              key: _logoIconKey,
              icon: Image.asset(
                'lib/assets/launcher_icon.png',
                width: 30,
                height: 30,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AboutUsPage()),
                );
              },
            ),
          ],
        ),
        extendBodyBehindAppBar: false,
        body: Stack(children: <Widget>[
          // Map View
          GoogleMap(
            minMaxZoomPreference: MinMaxZoomPreference(14, 20),
            initialCameraPosition: CameraPosition(
              target: currentLocation ?? _initialLocation,
              zoom: 10,
            ),
            padding: EdgeInsets.only(top: 0, right: 0, left: 0),
            buildingsEnabled: false,
            compassEnabled: true,
            trafficEnabled: trafficEnabled,
            mapType: MapType.terrain,
            tiltGesturesEnabled: true,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: true,
            mapToolbarEnabled: false,
            rotateGesturesEnabled: true,
            onCameraMove: (position) {
              if (_isNavigating) {
                _updateNavigationInfo(position.target);
              }
            },
            markers: markers,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            polylines: polylines,
            circles: _alarmCircles,
          ),

          if (_showSearchBar)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: buildSearchBar,
            ),

          Positioned(
            bottom: 30,
            left: 20,
            child: gestureDetector,
          ),

          Positioned(
            bottom: 140,
            right: 15,
            width: 50,
            height: 50,
            child: buildLocationButton,
          ),

          if (!_isNavigating)
            Positioned(
              bottom: 20,
              right: 10,
              width: 70,
              height: 70,
              child: buildSearchToggleButton,
            ),

          if (_isNavigating)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 125,
              child: buildNavigationHeader,
            ),

          if (_isNavigating)
            Positioned(
              bottom: 20,
              right: 10,
              width: 70,
              height: 70,
              child: buildEndNavigation,
            ),

          if (_startLocationPoint != null &&
              _destinationPoint != null &&
              !_isNavigating)
            Positioned(
              bottom: 200,
              left: 80,
              right: 80,
              child: buildStartNavigationButton,
            ),
          if (_startLocationPoint != null &&
              _destinationPoint != null &&
              !_isNavigating)
            Positioned(
              bottom: 150,
              left: 80,
              right: 80,
              child: buildCancelNavigationButton,
            ),

          if (_isLoading) _buildLoadingOverlay(),
        ]),
        drawer: buildDrawer);
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 4,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(
                  color: const Color.fromARGB(111, 0, 0, 0), blurRadius: 50)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildSearchField(
                controller: _startLocationController,
                hintText: "Your Current Location",
                isStart: true,
                leadingIcon: Icons.my_location,
                iconColor: const Color.fromARGB(255, 130, 195, 249),
              ),
              _buildSearchField(
                controller: _destinationController,
                hintText: "Choose Destination",
                isStart: false,
                leadingIcon: Icons.location_on_outlined,
                iconColor: Colors.red,
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
        if (_showStartPredictions)
          _buildPredictionsList(
              predictions: _customStartPredictions, isStart: true),
        if (_showDestPredictions)
          _buildPredictionsList(
              predictions: _customDestPredictions, isStart: false),
      ],
    );
  }

  Widget _buildTrafficButton() {
    return Container(
      key: _trafficToggleKey,
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(146, 255, 255, 255),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Icon(
        Icons.traffic_outlined,
        color: trafficEnabled
            ? const Color.fromARGB(255, 255, 0, 0)
            : Colors.black,
        size: 30,
      ),
    );
  }

  Widget _buildLocationButton() {
    return FloatingActionButton(
      key: _locationButtonKey,
      onPressed: () async {
        await _getUserLocation();
      },
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(50),
      ),
      child: Icon(
        Icons.my_location,
        color: Colors.lightBlue,
      ),
    );
  }

  Widget _buildSearchToggleButton() {
    return FloatingActionButton(
      key: _searchToggleKey,
      onPressed: () {
        _toggleSearchBar();
      },
      backgroundColor: ui.Color.fromARGB(255, 29, 189, 109),
      child: FittedBox(
        child: Icon(
          _showSearchBar ? Icons.close : Icons.search_outlined,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEndNavigation() {
    return FloatingActionButton(
      onPressed: () {
        _showEndNavigationDialog();
      },
      backgroundColor: Colors.redAccent,
      child: FittedBox(
        child: Icon(
          _showSearchBar ? Icons.close : Icons.square,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildNavigationHeader() {
    return Container(
      padding: EdgeInsets.all(10),
      color: ui.Color.fromARGB(210, 54, 161, 237),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _stopNavigation,
              ),
              Text(
                "Navigation Active",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.info_outline, color: Colors.white),
                onPressed: () {
                  _showInfoBottomSheet(context);
                },
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            "Press the information button to view route information",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStartNavigationButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        elevation: 10,
        backgroundColor: Colors.red,
        padding: EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: _isLoading
          ? null
          : () async {
              setState(() => _isLoading = true);

              await Future.delayed(Duration(milliseconds: 50));

              try {
                await _startNavigation();
                await NotiService().showNotification(
                  title: 'Navigation Started',
                  body: 'Please follow the directions',
                );
              } catch (e) {
                print('Error: $e');
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 200),
        child: _isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Starting...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Text(
                'Start Navigation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildCancelNavigationButton() {
    return TextButton(
      onPressed: () async {
        await NotiService().showNotification(
            title: 'Navigation Journey Cancelled',
            body: "Your Navigation Plan has been cancelled.");

        _cancelNavigation();
      },
      child: Text(
        'Cancel Navigation',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.orangeAccent,
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF04BE62)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const Text(
                  "Signed in as:",
                  textAlign: TextAlign.start,
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    userName,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.start,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  Icons.directions_bus_outlined,
                  "Home",
                  const HomePage(title: "Home"),
                ),
                _buildDrawerItem(context, Icons.star_border_rounded,
                    "Saved Routes", SavedRoutesPage()),
                _buildDrawerItem(context, Icons.settings_outlined, "Settings",
                    AccountSettingsPage()),
              ],
            ),
          ),
          const Divider(),
          ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title:
                  const Text("Sign Out", style: TextStyle(color: Colors.red)),
              onTap: () => {
                    NotiService().showNotification(
                        title: 'Sign out successfully',
                        body: 'Thank you for using PasaHERO'),
                    _signOut(context),
                  }),
        ],
      ),
    );
  }

  Future<void> _saveRouteToFirestore() async {
    if (_routeNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter route name!"),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final routeData = {
      'userId': user.uid,
      'routeName': _routeNameController.text,
      'start': {
        'lat': _startLocationPoint!.latitude,
        'lng': _startLocationPoint!.longitude,
      },
      'end': {
        'lat': _destinationPoint!.latitude,
        'lng': _destinationPoint!.longitude,
      },
      'savedDate': DateTime.now().toIso8601String(),
      'polylines': polylines
          .map((p) => {
                'points': p.points
                    .map((lp) => {'lat': lp.latitude, 'lng': lp.longitude})
                    .toList(),
                'color': p.color.value,
                'width': p.width,
              })
          .toList(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('saved_routes')
          .add(routeData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Route '${_routeNameController.text}' saved!"),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Failed to save route"),
            backgroundColor: Colors.redAccent),
      );
    }
  }
}

Widget _buildDrawerItem(
  BuildContext context,
  IconData icon,
  String title,
  Widget page,
) {
  return ListTile(
    leading: Icon(icon, color: const Color.fromARGB(255, 20, 124, 14)),
    title: Text(title, style: GoogleFonts.poppins(color: Colors.black)),
    onTap: () {
      Navigator.pop(context);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF04BE62)),
            ),
          ),
        ),
      );

      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      });
    },
  );
}
