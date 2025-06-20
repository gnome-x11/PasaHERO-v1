import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit/helpers/loadgpx_files.dart';
import '../helpers/route_data.dart';
import '../models/route_segment.dart';
import '../models/transfer_point.dart';
import '../models/nearest_point.dart';
import '../models/journey_plan.dart';

// ========== Spatial Indexing System ==========
class RouteSpatialIndex {
  final Map<String, List<IndexedPoint>> _grid = {};
  static const double _cellSize = 0.002; // ~200m at equator

  void addRoute(RouteData route) {
    for (int i = 0; i < route.path.length; i++) {
      final point = route.path[i];
      final latIndex = (point.latitude / _cellSize).floor();
      final lonIndex = (point.longitude / _cellSize).floor();
      final key = '$latIndex,$lonIndex';
      _grid.putIfAbsent(key, () => []).add(IndexedPoint(point, route, i));
    }
  }

  List<IndexedPoint> getNearbyPoints(LatLng point) {
    final latIndex = (point.latitude / _cellSize).floor();
    final lonIndex = (point.longitude / _cellSize).floor();
    final points = <IndexedPoint>[];

    for (int i = latIndex - 1; i <= latIndex + 1; i++) {
      for (int j = lonIndex - 1; j <= lonIndex + 1; j++) {
        final key = '$i,$j';
        final cellPoints = _grid[key];
        if (cellPoints != null) points.addAll(cellPoints);
      }
    }
    return points;
  }
}

class IndexedPoint {
  final LatLng point;
  final RouteData route;
  final int index;

  IndexedPoint(this.point, this.route, this.index);
}

final spatialIndex = RouteSpatialIndex();

// Initialize this after loading routes
void buildSpatialIndex() {
  for (final route in routes) {
    spatialIndex.addRoute(route);
  }
}

// ========== Distance Calculations ==========
const double _earthRadius = 6371000; // meters

double calculateDistance(LatLng p1, LatLng p2) {
  if (p1 == p2) return 0;

  final lat1 = p1.latitude * pi / 180;
  final lat2 = p2.latitude * pi / 180;
  final dLat = (p2.latitude - p1.latitude) * pi / 180;
  final dLon = (p2.longitude - p1.longitude) * pi / 180;

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
  return _earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
}

// ========== Optimized Search Functions ==========
Map<String, dynamic> findNearestJeepneyStopWithIndex(
  LatLng userLocation, {
  RouteData? route,
  String? direction,
}) {
  final nearbyPoints = spatialIndex.getNearbyPoints(userLocation);
  double minDistance = double.infinity;
  LatLng? nearestPoint;
  int nearestIndex = -1;
  RouteData? nearestRoute;

  for (final indexedPoint in nearbyPoints) {
    if (route != null && indexedPoint.route != route) {
      continue;
    }
    if (direction != null &&
        indexedPoint.route.direction != direction &&
        indexedPoint.route.direction != 'bidirectional') {
      continue;
    }

    final distance = calculateDistance(userLocation, indexedPoint.point);
    if (distance < minDistance) {
      minDistance = distance;
      nearestPoint = indexedPoint.point;
      nearestIndex = indexedPoint.index;
      nearestRoute = indexedPoint.route;
    }
  }

  // Fallback to linear search if spatial index fails
  if (nearestPoint == null) {
    return _linearNearestSearch(userLocation,
        route: route, direction: direction);
  }

  return {'point': nearestPoint, 'index': nearestIndex, 'route': nearestRoute};
}

Map<String, dynamic> _linearNearestSearch(
  LatLng userLocation, {
  RouteData? route,
  String? direction,
}) {
  final routesToCheck = route != null
      ? [route]
      : routes
          .where((r) =>
              direction == null ||
              r.direction == direction ||
              r.direction == 'bidirectional')
          .toList();

  double minDistance = double.infinity;
  LatLng? nearestPoint;
  int nearestIndex = -1;
  RouteData? nearestRoute;

  for (final r in routesToCheck) {
    for (int i = 0; i < r.path.length; i++) {
      final distance = calculateDistance(userLocation, r.path[i]);
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = r.path[i];
        nearestIndex = i;
        nearestRoute = r;
      }
    }
  }

  return {'point': nearestPoint, 'index': nearestIndex, 'route': nearestRoute};
}

RouteData? findNearestRoute(LatLng point, {String? preferredDirection}) {
  RouteData? nearestRoute;
  double minDistance = double.infinity;

  for (final route in routes) {
    final directDistance = calculateDistance(point, route.path[0]);
    if (directDistance < 500 && route.vehicleType == 'tricycle') {
      return route;
    }

    if (preferredDirection != null &&
        route.direction != preferredDirection &&
        route.direction != 'bidirectional') {
      continue;
    }

    final nearest = findNearestPointOnRoute(point, route);
    final distance = calculateDistance(point, nearest.point);
    if (distance < minDistance) {
      minDistance = distance;
      nearestRoute = route;
    }
  }
  return nearestRoute;
}

NearestPoint findNearestPointOnRoute(LatLng target, RouteData route) {
  // Use cache if available
  if (route.indexCache.containsKey(target)) {
    return route.indexCache[target]!;
  }

  int nearestIndex;

  // Tricycles: ignore direction, just find closest point
  if (route.vehicleType == 'tricycle') {
    nearestIndex = _findNearestIndex(target, route.path);
  } else {
    // Jeepneys or other vehicles might need directional-aware search in future
    nearestIndex = _findNearestIndex(target, route.path);
  }

  final result = NearestPoint(route.path[nearestIndex], nearestIndex);
  route.indexCache[target] = result; // Cache result
  return result;
}

int _findNearestIndex(LatLng target, List<LatLng> path) {
  int nearestIndex = 0;
  double minDistance = double.infinity;

  for (int i = 0; i < path.length; i++) {
    final distance = calculateDistance(target, path[i]);
    if (distance < minDistance) {
      minDistance = distance;
      nearestIndex = i;
    }
  }
  return nearestIndex;
}

// ========== Transfer Point Optimization ==========
List<TransferPoint> findTransferPoints(RouteData route1, RouteData route2) {
  // Adjust thresholds for tricycles (shorter routes and tighter proximity)
  final bool isTricycleTransfer =
      route1.vehicleType == 'tricycle' || route2.vehicleType == 'tricycle';

  final double maxTransferDistance = isTricycleTransfer ? 300 : 500;
  final double proximityThreshold = isTricycleTransfer ? 30 : 50;
  final transfers = <TransferPoint>[];

  // Skip if routes already overlap significantly
  if (areRoutesOverlapping(route1, route2, threshold: 100)) {
    return [];
  }

  TransferPoint? bestTransfer;
  final step = max(1, route1.path.length ~/ 100); // Adaptive sampling

  for (int i = 0; i < route1.path.length; i += step) {
    final point1 = route1.path[i];
    final nearestOnRoute2 = findNearestPointOnRoute(point1, route2);
    final distance = calculateDistance(point1, nearestOnRoute2.point);

    // Prefer direct transfer if very close
    if (distance < proximityThreshold) {
      return [
        TransferPoint(
          startTransfer: point1,
          endTransfer: nearestOnRoute2.point,
          distance: distance,
        )
      ];
    }

    if (distance <= maxTransferDistance) {
      if (bestTransfer == null || distance < bestTransfer.distance) {
        bestTransfer = TransferPoint(
          startTransfer: point1,
          endTransfer: nearestOnRoute2.point,
          distance: distance,
        );
      }
    }
  }

  if (bestTransfer != null) transfers.add(bestTransfer);
  return transfers;
}

bool areRoutesOverlapping(RouteData r1, RouteData r2, {double threshold = 20}) {
  int overlapCount = 0;
  const int overlapLimit = 10;

  for (int i = 0; i < r1.path.length; i += 3) {
    final nearest = findNearestPointOnRoute(r1.path[i], r2);
    if (calculateDistance(r1.path[i], nearest.point) < threshold) {
      if (++overlapCount >= overlapLimit) return true;
    }
  }
  return false;
}

// ========== Journey Planning Optimization ==========
Future<JourneyPlan?> calculateJourneyPlan({
  required LatLng startPoint,
  required LatLng endPoint,
  required RouteData startRoute,
  required RouteData destRoute,
}) async {
  List<RouteSegment> vehicleSegments = []; // Changed from jeepSegments
  final walkingSegments = <List<LatLng>>[];

  // FIXED: Consolidated tricycle handling with correct spelling
  if (startRoute.vehicleType == 'tricycle' &&
      destRoute.vehicleType == 'tricycle' &&
      startRoute == destRoute) {
    return createTricycleJourney(
      startPoint: startPoint,
      endPoint: endPoint,
      tricycleRoute: startRoute,
    );
  }

  // Try direct route first
  final directRoute = findSingleRoute(startPoint, endPoint);
  if (directRoute != null) {
    return _buildDirectJourney(
      startPoint,
      endPoint,
      directRoute,
      vehicleSegments,
      walkingSegments,
    );
  }

  // Same route handling
  if (startRoute == destRoute) {
    return _buildSingleRouteJourney(
      startPoint,
      endPoint,
      startRoute,
      vehicleSegments,
      walkingSegments,
    );
  }

  // Multi-route handling
  final directTransfers = findTransferPoints(startRoute, destRoute);
  if (directTransfers.isNotEmpty) {
    return _buildTransferJourney(
      startPoint,
      endPoint,
      startRoute,
      destRoute,
      directTransfers.first,
      vehicleSegments,
      walkingSegments,
    );
  }

  // Intermediate route handling
  return _buildIntermediateJourney(
    startPoint,
    endPoint,
    startRoute,
    destRoute,
    vehicleSegments,
    walkingSegments,
  );
}

// ========== Simplified Tricycle Journey Creation ==========
Future<JourneyPlan?> createTricycleJourney({
  required LatLng startPoint,
  required LatLng endPoint,
  required RouteData tricycleRoute,
}) async {
  final List<RouteSegment> vehicleSegments = [];
  final List<List<LatLng>> walkingSegments = [];

  // Find nearest points on the route
  final startNearest = findNearestPointOnRoute(startPoint, tricycleRoute);
  final destNearest = findNearestPointOnRoute(endPoint, tricycleRoute);

  // Create the vehicle segment - always use full route but with proper boarding/alighting
  vehicleSegments.add(RouteSegment(
    route: tricycleRoute,
    boardingPoint: startNearest.point,
    alightingPoint: destNearest.point,
    pathSegment: _getTricyclePathSegment(
        tricycleRoute.path, startNearest.index, destNearest.index),
  ));

  // Add walking segments
  final boardingWalk = await getWalkingRoute(startPoint, startNearest.point);
  final alightingWalk = await getWalkingRoute(destNearest.point, endPoint);

  if (boardingWalk != null) walkingSegments.add(boardingWalk);
  if (alightingWalk != null) walkingSegments.add(alightingWalk);

  return JourneyPlan(
    vehicleSegments: vehicleSegments,
    walkingSegments: walkingSegments,
  );
}

// ========== Tricycle Path Segment Logic ==========
List<LatLng> _getTricyclePathSegment(
    List<LatLng> fullPath, int startIndex, int endIndex) {
  // FIXED: Always return the actual segment between points
  final minIndex = min(startIndex, endIndex);
  final maxIndex = max(startIndex, endIndex);

  return fullPath.sublist(minIndex, maxIndex + 1);
}

Future<JourneyPlan?> _buildDirectJourney(
  LatLng startPoint,
  LatLng endPoint,
  RouteData route,
  List<RouteSegment> jeepSegments,
  List<List<LatLng>> walkingSegments,
) async {
  final startNearest = findNearestPointOnRoute(startPoint, route);
  final destNearest = findNearestPointOnRoute(endPoint, route);
  final segment = createRouteSegment(
    route: route,
    startPoint: startNearest,
    endPoint: destNearest,
  );

  if (segment == null) return null;

  jeepSegments.add(segment);

  final walkFutures = [
    getWalkingRoute(startPoint, segment.boardingPoint),
    getWalkingRoute(segment.alightingPoint, endPoint),
  ];

  final walkResults = await Future.wait(walkFutures);

  if (walkResults[0] != null) walkingSegments.add(walkResults[0]!);
  if (walkResults[1] != null) walkingSegments.add(walkResults[1]!);

  return JourneyPlan(
    vehicleSegments: jeepSegments,
    walkingSegments: walkingSegments,
  );
}

Future<JourneyPlan?> _buildSingleRouteJourney(
  LatLng startPoint,
  LatLng endPoint,
  RouteData route,
  List<RouteSegment> jeepSegments,
  List<List<LatLng>> walkingSegments,
) async {
  final startNearest = findNearestPointOnRoute(startPoint, route);
  final destNearest = findNearestPointOnRoute(endPoint, route);
  final segment = createRouteSegment(
    route: route,
    startPoint: startNearest,
    endPoint: destNearest,
  );

  if (segment == null) return null;

  jeepSegments.add(segment);

  final walkFutures = [
    getWalkingRoute(startPoint, segment.boardingPoint),
    getWalkingRoute(segment.alightingPoint, endPoint),
  ];

  final walkResults = await Future.wait(walkFutures);

  if (walkResults[0] != null) walkingSegments.add(walkResults[0]!);
  if (walkResults[1] != null) walkingSegments.add(walkResults[1]!);

  return JourneyPlan(
    vehicleSegments: jeepSegments,
    walkingSegments: walkingSegments,
  );
}

Future<JourneyPlan?> _buildTransferJourney(
  LatLng startPoint,
  LatLng endPoint,
  RouteData startRoute,
  RouteData destRoute,
  TransferPoint transfer,
  List<RouteSegment> jeepSegments,
  List<List<LatLng>> walkingSegments,
) async {
  final segment1 = createRouteSegment(
    route: startRoute,
    startPoint: findNearestPointOnRoute(startPoint, startRoute),
    endPoint: findNearestPointOnRoute(transfer.startTransfer, startRoute),
  );

  final segment2 = createRouteSegment(
    route: destRoute,
    startPoint: findNearestPointOnRoute(transfer.endTransfer, destRoute),
    endPoint: findNearestPointOnRoute(endPoint, destRoute),
  );

  if (segment1 == null || segment2 == null) return null;

  jeepSegments.addAll([segment1, segment2]);

  final walkFutures = [
    getWalkingRoute(startPoint, segment1.boardingPoint),
    getWalkingRoute(segment1.alightingPoint, segment2.boardingPoint),
    getWalkingRoute(segment2.alightingPoint, endPoint),
  ];

  final walkResults = await Future.wait(walkFutures);

  if (walkResults[0] != null) walkingSegments.add(walkResults[0]!);
  if (walkResults[1] != null) walkingSegments.add(walkResults[1]!);
  if (walkResults[2] != null) walkingSegments.add(walkResults[2]!);

  return JourneyPlan(
    vehicleSegments: jeepSegments,
    walkingSegments: walkingSegments,
  );
}

Future<JourneyPlan?> _buildIntermediateJourney(
  LatLng startPoint,
  LatLng endPoint,
  RouteData startRoute,
  RouteData destRoute,
  List<RouteSegment> jeepSegments,
  List<List<LatLng>> walkingSegments,
) async {
  final intermediateRoute = findBestIntermediateRoute(startRoute, destRoute);
  if (intermediateRoute == null) return null;

  final transfer1 = findTransferPoints(startRoute, intermediateRoute);
  final transfer2 = findTransferPoints(intermediateRoute, destRoute);

  if (transfer1.isEmpty || transfer2.isEmpty) return null;
  final t1 = transfer1.first;
  final t2 = transfer2.first;

  if (t1.distance > 500 || t2.distance > 500) return null;

  final segment1 = createRouteSegment(
    route: startRoute,
    startPoint: findNearestPointOnRoute(startPoint, startRoute),
    endPoint: findNearestPointOnRoute(t1.startTransfer, startRoute),
  );

  final segment2 = createRouteSegment(
    route: intermediateRoute,
    startPoint: findNearestPointOnRoute(t1.endTransfer, intermediateRoute),
    endPoint: findNearestPointOnRoute(t2.startTransfer, intermediateRoute),
  );

  final segment3 = createRouteSegment(
    route: destRoute,
    startPoint: findNearestPointOnRoute(t2.endTransfer, destRoute),
    endPoint: findNearestPointOnRoute(endPoint, destRoute),
  );

  if (segment1 == null || segment2 == null || segment3 == null) return null;

  jeepSegments.addAll([segment1, segment2, segment3]);

  final walkFutures = [
    getWalkingRoute(startPoint, segment1.boardingPoint),
    getWalkingRoute(segment1.alightingPoint, segment2.boardingPoint),
    getWalkingRoute(segment2.alightingPoint, segment3.boardingPoint),
    getWalkingRoute(segment3.alightingPoint, endPoint),
  ];

  final walkResults = await Future.wait(walkFutures);

  if (walkResults[0] != null) walkingSegments.add(walkResults[0]!);
  if (walkResults[1] != null) walkingSegments.add(walkResults[1]!);
  if (walkResults[2] != null) walkingSegments.add(walkResults[2]!);
  if (walkResults[3] != null) walkingSegments.add(walkResults[3]!);

  return JourneyPlan(
    vehicleSegments: jeepSegments,
    walkingSegments: walkingSegments,
  );
}

RouteData? findBestIntermediateRoute(
    RouteData startRoute, RouteData destRoute) {
  final candidates = <Map<String, dynamic>>[];

  for (final r in routes.where((r) => r != startRoute && r != destRoute)) {
    final transfer1 = findTransferPoints(startRoute, r);
    final transfer2 = findTransferPoints(r, destRoute);

    if (transfer1.isNotEmpty && transfer2.isNotEmpty) {
      final totalDist = transfer1.first.distance + transfer2.first.distance;
      candidates.add({
        'route': r,
        'distance': totalDist,
      });
    }
  }

  candidates.sort((a, b) => a['distance'].compareTo(b['distance']));
  return candidates.isNotEmpty ? candidates.first['route'] as RouteData : null;
}

RouteData? findSingleRoute(LatLng start, LatLng end) {
  for (final r in routes) {
    final startNearest = findNearestPointOnRoute(start, r);
    final endNearest = findNearestPointOnRoute(end, r);

    final startDist = calculateDistance(start, startNearest.point);
    final endDist = calculateDistance(end, endNearest.point);

    // FIXED: Improved tricycle handling logic
    if (r.vehicleType == 'tricycle') {
      // Tricycle-specific matching rules
      if (startDist <= 150 && endDist <= 150) {
        return r;
      }
      // Allow tricycle matching even if not perfect
      else if (startDist < 300 && endDist < 300) {
        return r;
      }
    }
    // Jeepney/other vehicle logic
    else {
      if (startDist > 200 || endDist > 200) continue;

      bool isValidDirection = false;
      if (r.direction == 'bidirectional') {
        isValidDirection = true;
      } else if (r.direction == 'southbound' || r.direction == 'northbound') {
        isValidDirection = startNearest.index <= endNearest.index;
      }

      if (isValidDirection) return r;
    }
  }
  return null;
}

// // ========== Walking Route Optimization ==========
// Future<List<LatLng>?> getWalkingRoute(LatLng start, LatLng end) async {
//   final distance = calculateDistance(start, end);
//   if (distance < 50) return [start, end]; // Skip API for short distances

//   final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
//       'origin=${start.latitude},${start.longitude}&'
//       'destination=${end.latitude},${end.longitude}&'
//       'mode=walking&key=$googleApiKey';

//   try {
//     final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

//     if (response.statusCode != 200) return _fallbackRoute(start, end);

//     final data = json.decode(response.body);
//     if (data['status'] != 'OK' || data['routes'].isEmpty) {
//       return _fallbackRoute(start, end);
//     }

//     return _decodeRoute(data['routes'][0], start, end);
//   } catch (_) {
//     return _fallbackRoute(start, end);
//   }
// }

Future<List<LatLng>?> getWalkingRoute(LatLng start, LatLng end) async {
  final distance = calculateDistance(start, end);
  if (distance < 50) return [start, end];

  return interpolatePath(start, end);
}

List<LatLng> interpolatePath(LatLng start, LatLng end, {int segments = 10}) {
  final latStep = (end.latitude - start.latitude) / segments;
  final lngStep = (end.longitude - start.longitude) / segments;

  return List.generate(
    segments + 1,
    (i) => LatLng(start.latitude + latStep * i, start.longitude + lngStep * i),
  );
}

// List<LatLng> _fallbackRoute(LatLng start, LatLng end) => [start, end];

// List<LatLng> _decodeRoute(Map<String, dynamic> route, LatLng start, LatLng end) {
//   try {
//     // Try detailed steps first
//     final steps = route['legs'][0]['steps'] as List;
//     final detailedPath = steps.expand((step) {
//       return PolyUtils.decode(step['polyline']['points']);
//     }).map((p) => LatLng(p.x.toDouble(), p.y.toDouble())).toList();

//     if (detailedPath.isNotEmpty) return detailedPath;
//   } catch (_) {}

//   //Fallback to overview polyline
//   try {
//     final overview = route['overview_polyline']['points'] as String;
//     return PolyUtils.decode(overview)
//         .map((p) => LatLng(p.x.toDouble(), p.y.toDouble()))
//         .toList();
//   } catch (_) {
//     return _fallbackRoute(start, end);
//   }
// }

// ========== Segment Creation ==========
// models/journey_planner_model.dart
RouteSegment? createRouteSegment({
  required RouteData route,
  required NearestPoint startPoint,
  required NearestPoint endPoint,
}) {
  try {
    List<LatLng> segment;

    // Unified logic for all vehicle types
    if (startPoint.index <= endPoint.index) {
      segment = route.path.sublist(startPoint.index, endPoint.index + 1);
    } else {
      segment = route.path
          .sublist(endPoint.index, startPoint.index + 1)
          .reversed
          .toList();
    }

    return RouteSegment(
      route: route,
      boardingPoint: startPoint.point,
      alightingPoint: endPoint.point,
      pathSegment: segment,
    );
  } catch (e) {
    debugPrint("Segment creation error: $e");
    return null;
  }
}

// ========== UI Helpers ==========
void showLoadingDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Calculating route..."),
          ],
        ),
      );
    },
  );
}
