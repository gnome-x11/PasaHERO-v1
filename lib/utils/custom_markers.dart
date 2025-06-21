//utils

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit/models/journey_plan.dart';
import 'package:transit/helpers/noti_service.dart';
import 'package:transit/models/search_helper.dart' as searchService;
import '../helpers/loadgpx_files.dart';
import '../utils/journey_planner.dart';

//for image icon
Future<BitmapDescriptor> createCustomMarkerWithImage(
    String assetPath, Color bgColor) async {
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  const double width = 60.0;
  const double height = 60.0;
  final Paint paint = Paint()..color = bgColor;

  // Draw background rounded rectangle
  final RRect rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, width, height),
    const Radius.circular(50),
  );
  canvas.drawRRect(rect, paint);

  // Draw triangle pointer
  final Path trianglePath = Path()
    ..moveTo(width / 2 - 15, height)
    ..lineTo(width / 2 + 15, height)
    ..lineTo(width / 2, height + 20)
    ..close();
  canvas.drawPath(trianglePath, paint);

  // Load image
  final ByteData data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetWidth: 50,
    targetHeight: 50,
  );
  final frame = await codec.getNextFrame();
  final ui.Image iconImage = frame.image;

  // Draw image centered
  final double imgX = (width - 50) / 2;
  final double imgY = (height - 50) / 2;
  canvas.drawImage(iconImage, Offset(imgX, imgY), Paint());

  // Finalize image
  final img = await pictureRecorder.endRecording().toImage(
        width.toInt(),
        (height + 20).toInt(),
      );
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final Uint8List uint8List = byteData!.buffer.asUint8List();

  return BitmapDescriptor.fromBytes(uint8List);
}

//for plain text icon controller
Future<BitmapDescriptor> createCustomMarker(String text, Color bgColor) async {
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  const double width = 120.0;
  const double height = 60.0;
  final Paint paint = Paint()..color = bgColor;

  final RRect rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, width, height),
    const Radius.circular(20),
  );
  canvas.drawRRect(rect, paint);

  final Path trianglePath = Path()
    ..moveTo(width / 2 - 15, height)
    ..lineTo(width / 2 + 15, height)
    ..lineTo(width / 2, height + 20)
    ..close();
  canvas.drawPath(trianglePath, paint);

  final TextPainter textPainter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );
  textPainter.text = TextSpan(
    text: text,
    style: const TextStyle(
      fontSize: 28,
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
  );
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset((width - textPainter.width) / 2, (height - textPainter.height) / 3),
  );

  final img = await pictureRecorder.endRecording().toImage(
        width.toInt(),
        (height + 20).toInt(),
      );
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final Uint8List uint8List = byteData!.buffer.asUint8List();

  return BitmapDescriptor.fromBytes(uint8List);
}

double pathLength(List<LatLng> path) {
  double total = 0.0;
  for (int i = 0; i < path.length - 1; i++) {
    total += calculateDistance(path[i], path[i + 1]);
  }
  return total;
}

Future<void> updateMarkers({
  required BuildContext context,
  required LatLng? startLocationPoint,
  required LatLng? destinationPoint,
  required TextEditingController startLocationController,
  required TextEditingController destinationController,
  required void Function(Set<Marker>, Set<Polyline>) onUpdate,
}) async {
  final Map<MarkerId, Marker> updatedMarkers = {};
  final List<Polyline> updatedPolylines = [];

  bool hasStart = startLocationPoint != null;
  bool hasEnd = destinationPoint != null;

  if (hasStart) {
    final startMarkerId = MarkerId("start_location");
    final startIcon = await createCustomMarker("Start", Colors.green);

    updatedMarkers[startMarkerId] = Marker(
      markerId: startMarkerId,
      position: startLocationPoint,
      infoWindow: InfoWindow(title: startLocationController.text),
      icon: startIcon,
    );
  }

  if (hasEnd) {
    final destMarkerId = MarkerId("destination");
    final destIcon = await createCustomMarker("End", Colors.red);
    updatedMarkers[destMarkerId] = Marker(
      markerId: destMarkerId,
      position: destinationPoint,
      infoWindow: InfoWindow(title: destinationController.text),
      icon: destIcon,
    );
  }

  if (!hasStart || !hasEnd) {
    onUpdate(updatedMarkers.values.toSet(), updatedPolylines.toSet());
    return;
  }

  final travelDirection =
      determineTravelDirection(startLocationPoint, destinationPoint);
  final startRoute =
      findNearestRoute(startLocationPoint, preferredDirection: travelDirection);
  final destRoute =
      findNearestRoute(destinationPoint, preferredDirection: travelDirection);

  // Show loading while calculating
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFFFAFAFA),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: Color(0xFF04BE62)),
            SizedBox(height: 20),
            Text(
              "Finding Optimal Route",
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      );
    },
  );

  if (startRoute == null || destRoute == null) {
    onUpdate(updatedMarkers.values.toSet(), updatedPolylines.toSet());
    return;
  }

  final journeyPlan = await calculateJourneyPlan(
    startPoint: startLocationPoint,
    endPoint: destinationPoint,
    startRoute: startRoute,
    destRoute: destRoute,
  );

  Navigator.of(context).pop();

  if (journeyPlan == null) return;

  final notiService = NotiService();
  await notiService.showNotification(
    title: 'Route Ready!',
    body: 'Your route has been successfully calculated.',
  );

  if (journeyPlan.vehicleSegments.length == 2) {
    final first = journeyPlan.vehicleSegments.first;
    final second = journeyPlan.vehicleSegments.last;

    final walkToSecondBoarding = calculateDistance(
      startLocationPoint,
      second.boardingPoint,
    );

    final firstJeepDistance = pathLength(first.pathSegment);

    if (walkToSecondBoarding < 150 && firstJeepDistance < 300) {
      final walkPath =
          await getWalkingRoute(startLocationPoint, second.boardingPoint);

      final filteredPlan = JourneyPlan(
        walkingSegments: [walkPath ?? []],
        vehicleSegments: [second],
      );

      // replace the original journeyPlan with filtered one
      journeyPlan.vehicleSegments.clear();
      journeyPlan.vehicleSegments.addAll(filteredPlan.vehicleSegments);

      journeyPlan.walkingSegments.clear();
      journeyPlan.walkingSegments.addAll(filteredPlan.walkingSegments);
    }
  }

  final routeColors = [Colors.blue, Colors.deepPurpleAccent, Colors.pink];
  int colorIndex = 0;

  for (final segment in journeyPlan.vehicleSegments) {
    Color color;
    String iconAsset;
    String markerText;

    if (segment.route.vehicleType == 'tricycle') {
      color = Colors.green; // Distinct color for tricycles
      iconAsset = 'lib/assets/tricycle-icon.png';
      markerText = "Ride this tricycle";
    } else {
      color = routeColors[colorIndex % routeColors.length];
      iconAsset = 'lib/assets/jeep-icon.png';
      markerText = "Ride this jeepney";
    }

    final boardingIcon = await createCustomMarkerWithImage(iconAsset, color);

    final boardingMarkerId = MarkerId("boarding_${segment.route.name}");
    updatedMarkers[boardingMarkerId] = Marker(
      markerId: boardingMarkerId,
      position: segment.boardingPoint,
      icon: boardingIcon,
      infoWindow: InfoWindow(
        title: markerText,
        snippet: segment.route.displayName,
      ),
    );

    final alightingIcon = await createCustomMarkerWithImage(iconAsset, color);
    final alightingMarkerId = MarkerId("alighting_${segment.route.name}");
    updatedMarkers[alightingMarkerId] = Marker(
      markerId: alightingMarkerId,
      position: segment.alightingPoint,
      icon: alightingIcon,
      infoWindow: InfoWindow(
        title: "Drop off location",
        snippet:
            "Landmark: ${await searchService.getAddressFromLatLngV2(segment.alightingPoint)}",
      ),
    );

    // Determine path for tricycles (show only partial segment)
    List<LatLng> displayPath;
    if (segment.route.vehicleType == 'tricycle') {
      final startIdx = segment.route.path.indexOf(segment.boardingPoint);
      final endIdx = segment.route.path.indexOf(segment.alightingPoint);

      if (startIdx != -1 && endIdx != -1) {
        displayPath = startIdx < endIdx
            ? segment.route.path.sublist(startIdx, endIdx + 1)
            : segment.route.path
                .sublist(endIdx, startIdx + 1)
                .reversed
                .toList();
      } else {
        displayPath = segment.pathSegment;
      }
    } else {
      displayPath = segment.pathSegment;
    }

    //   Future<void> _startNavigation() async {
    // _alarmManager.startMonitoring();
    // await _alarmManager.initialize();
    // List<Polyline> snappedPolylines = [];
    // for (var polyline in polylines) {
    //   List<LatLng> snappedPoints = await snapToRoads(polyline.points);
    //   snappedPolylines.add(Polyline(
    //     polylineId: polyline.polylineId,
    //     points: snappedPoints,
    //     color: polyline.color,
    //     width: polyline.width,
    //   ));
    // }

    updatedPolylines.add(Polyline(
      polylineId: PolylineId("route_${segment.route.name}"),
      points: displayPath,
      color: color,
      width: segment.route.vehicleType == 'tricycle' ? 4 : 5,
      geodesic: false,
    ));

    colorIndex++;
  }

  for (int i = 0; i < journeyPlan.walkingSegments.length; i++) {
    final walkPath = journeyPlan.walkingSegments[i];
    updatedPolylines.add(Polyline(
      polylineId: PolylineId('walk_$i'),
      points: walkPath,
      color: Colors.orange,
      width: 8,
      patterns: [PatternItem.dash(10), PatternItem.gap(15)],
      geodesic: false,
    ));
  }

  onUpdate(updatedMarkers.values.toSet(), updatedPolylines.toSet());
}
