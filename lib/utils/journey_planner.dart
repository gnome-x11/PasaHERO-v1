
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

class RouteSpatialIndex {
  final Map<String, List<IndexedPoint>> _grid = {};
  static const double _cellSize = 0.005;

  void addRoute(RouteData route) {
    final step = route.vehicleType == 'tricycle' ? 1 : 2;
    for (int i = 0; i < route.path.length; i += step) {
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

void buildSpatialIndex() {
  for (final route in routes) {
    spatialIndex.addRoute(route);
  }
}

const double _earthRadius = 6371000;

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
  final candidates = <RouteData>[];
  double minDistance = double.infinity;
  RouteData? nearestRoute;

  for (final route in routes) {
    if (preferredDirection != null &&
        route.direction != preferredDirection &&
        route.direction != 'bidirectional') {
      continue;
    }

    final nearest = findNearestPointOnRoute(point, route);
    final distance = calculateDistance(point, nearest.point);

    if (route.vehicleType == 'tricycle' && distance <= 100) {
      candidates.add(route);
    }

    if (distance < minDistance) {
      minDistance = distance;
      nearestRoute = route;
    }
  }

  if (candidates.isNotEmpty) {
    return candidates[Random().nextInt(candidates.length)];
  }

  return nearestRoute;
}

NearestPoint findNearestPointOnRoute(LatLng target, RouteData route) {
  if (route.indexCache.containsKey(target)) {
    return route.indexCache[target]!;
  }

  int nearestIndex;
  if (route.vehicleType == 'tricycle') {
    nearestIndex = _findNearestIndex(target, route.path);
  } else {
    nearestIndex = _findNearestIndex(target, route.path);
  }

  final result = NearestPoint(route.path[nearestIndex], nearestIndex);
  route.indexCache[target] = result;
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

List<TransferPoint> findTransferPoints(RouteData route1, RouteData route2) {
  final bool isTricycleTransfer =
      route1.vehicleType == 'tricycle' || route2.vehicleType == 'tricycle';

  final double maxTransferDistance = isTricycleTransfer ? 500 : 500;

  final transfers = <TransferPoint>[];

  if (route1.vehicleType == 'tricycle' && route2.vehicleType == 'tricycle') {
    return _findTricycleToTricycleTransfers(
        route1, route2, maxTransferDistance);
  }
  if (areRoutesOverlapping(route1, route2, threshold: 200)) {
    return [];
  }

  TransferPoint? bestTransfer;
  final step = max(1, route1.path.length ~/ 100);

  for (int i = 0; i < route1.path.length; i += step) {
    final point1 = route1.path[i];
    final nearestOnRoute2 = findNearestPointOnRoute(point1, route2);
    final distance = calculateDistance(point1, nearestOnRoute2.point);

    if (distance <= maxTransferDistance) {
      if (bestTransfer == null || distance < bestTransfer.distance) {
        bestTransfer = TransferPoint(
          startTransfer: NearestPoint(point1, route1.path.indexOf(point1)),
          endTransfer: nearestOnRoute2,
          distance: distance,
        );
      }
    }
  }

  if (bestTransfer != null) transfers.add(bestTransfer);
  return transfers;
}

List<TransferPoint> _findTricycleToTricycleTransfers(
    RouteData trike1, RouteData trike2, double maxDistance) {
  final transfers = <TransferPoint>[];

  for (final point in trike1.path) {
    final nearest = findNearestPointOnRoute(point, trike2);
    final distance = calculateDistance(point, nearest.point);

    if (distance <= maxDistance) {
      transfers.add(TransferPoint(
        startTransfer: NearestPoint(point, trike1.path.indexOf(point)),
        endTransfer: nearest,
        distance: distance,
      ));
    }
  }

  return transfers;
}

bool areRoutesOverlapping(RouteData r1, RouteData r2, {double threshold = 50}) {
  int overlapCount = 0;
  const int overlapLimit = 50;

  for (int i = 0; i < r1.path.length; i += 4) {
    final nearest = findNearestPointOnRoute(r1.path[i], r2);
    if (calculateDistance(r1.path[i], nearest.point) < threshold) {
      if (++overlapCount >= overlapLimit) return true;
    }
  }
  return false;
}

Future<JourneyPlan?> calculateJourneyPlan({
  required LatLng startPoint,
  required LatLng endPoint,
  required RouteData startRoute,
  required RouteData destRoute,
}) async {
  List<RouteSegment> vehicleSegments = [];
  final walkingSegments = <List<LatLng>>[];

  if (startRoute.vehicleType == 'tricycle' &&
      destRoute.vehicleType == 'tricycle' &&
      startRoute == destRoute) {
    return _buildDirectJourney(
      startPoint,
      endPoint,
      startRoute,
      vehicleSegments,
      walkingSegments,
    );
  }

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

  if (startRoute == destRoute) {
    return _buildSingleRouteJourney(
      startPoint,
      endPoint,
      startRoute,
      vehicleSegments,
      walkingSegments,
    );
  }

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

  if (startRoute.vehicleType == 'tricycle' &&
      destRoute.vehicleType == 'jeep') {
    final plan = await calculateTricycleJeepJeepJeepJourney(
      startPoint: startPoint,
      endPoint: endPoint,
    );
    if (plan != null) return plan;
  }

  if (startRoute.vehicleType == 'tricycle' &&
      destRoute.vehicleType == 'tricycle') {
    final plan = await calculateTricycleJeepJeepTricycleJourney(
      startPoint: startPoint,
      endPoint: endPoint,
    );
    if (plan != null) return plan;
  }
  if (startRoute.vehicleType == 'tricycle' &&
      destRoute.vehicleType == 'jeep') {
    final plan = await calculateTrikeTrikeTrikeJeepJeepJourney(
      startPoint: startPoint,
      endPoint: endPoint,
    );
    if (plan != null) return plan;
  }

  if (startRoute.vehicleType == 'tricycle' &&
      destRoute.vehicleType == 'tricycle') {
    final plan = await calculateTricycleJeepTricycleJourney(
      startPoint: startPoint,
      endPoint: endPoint,
    );
    if (plan != null) return plan;
  }

  return buildIntermediateJourney(
    startPoint,
    endPoint,
    startRoute,
    destRoute,
    vehicleSegments,
    walkingSegments,
  );
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
    endPoint: findNearestPointOnRoute(transfer.startTransfer.point, startRoute),
  );

  final segment2 = createRouteSegment(
    route: destRoute,
    startPoint: findNearestPointOnRoute(transfer.endTransfer.point, destRoute),
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



Future<JourneyPlan?> buildIntermediateJourney(
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
    endPoint: findNearestPointOnRoute(t1.startTransfer.point, startRoute),
  );

  final segment2 = createRouteSegment(
    route: intermediateRoute,
    startPoint: findNearestPointOnRoute(t1.endTransfer.point, intermediateRoute),
    endPoint: findNearestPointOnRoute(t2.startTransfer.point, intermediateRoute),
  );

  final segment3 = createRouteSegment(
    route: destRoute,
    startPoint: findNearestPointOnRoute(t2.endTransfer.point, destRoute),
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


Future<JourneyPlan?> calculateTricycleJeepJeepJeepJourney({
  required LatLng startPoint,
  required LatLng endPoint,
}) async {
  final tricycleRoutes = routes.where((r) => r.vehicleType == 'tricycle').toList();
  final jeepneyRoutes = routes.where((r) => r.vehicleType == 'jeep').toList();

  for (final trikeRoute in tricycleRoutes) {
    final startNearest = findNearestPointOnRoute(startPoint, trikeRoute);
    if (calculateDistance(startPoint, startNearest.point) > 200) continue;

    for (final jeep1 in jeepneyRoutes) {
      final transfer1 = findTransferPoints(trikeRoute, jeep1);
      if (transfer1.isEmpty) continue;

        for (final jeep2 in jeepneyRoutes) {
          if (jeep2 == jeep1) continue;
          final transfer2 = findTransferPoints(jeep1, jeep2);
          if (transfer2.isEmpty) continue;

            for (final jeep3 in jeepneyRoutes) {
            if (jeep3 == jeep2 || jeep3 == jeep1) continue;
            final transfer3 = findTransferPoints(jeep2, jeep3);
            if (transfer3.isEmpty) continue;

          final endNearest = findNearestPointOnRoute(endPoint, jeep3);
          if (calculateDistance(endPoint, endNearest.point) > 200) continue;

          final segment1 = createRouteSegment(
            route: trikeRoute,
            startPoint: startNearest,
            endPoint: findNearestPointOnRoute(transfer1.first.startTransfer.point, trikeRoute),
          );

          final segment2 = createRouteSegment(
            route: jeep1,
            startPoint: findNearestPointOnRoute(transfer1.first.endTransfer.point, jeep1),
            endPoint: findNearestPointOnRoute(transfer2.first.startTransfer.point, jeep1),
          );

          final segment3 = createRouteSegment(
            route: jeep2,
            startPoint: findNearestPointOnRoute(transfer2.first.endTransfer.point, jeep2),
            endPoint: findNearestPointOnRoute(transfer3.first.startTransfer.point, jeep2),
          );

          final segment4 = createRouteSegment(
            route: jeep3,
            startPoint: findNearestPointOnRoute(transfer3.first.endTransfer.point, jeep3),
            endPoint: endNearest,
          );

          if (segment1 == null || segment2 == null || segment3 == null || segment4 == null) continue;

          final walkSegments = <List<LatLng>>[];
          final walk1 = await getWalkingRoute(startPoint, segment1.boardingPoint);
          final walk2 = await getWalkingRoute(segment1.alightingPoint, segment2.boardingPoint);
          final walk3 = await getWalkingRoute(segment2.alightingPoint, segment3.boardingPoint);
          final walk4 = await getWalkingRoute(segment3.alightingPoint, segment4.boardingPoint);
          final walk5 = await getWalkingRoute(segment4.alightingPoint, endPoint);

          if (walk1 != null) walkSegments.add(walk1);
          if (walk2 != null) walkSegments.add(walk2);
          if (walk3 != null) walkSegments.add(walk3);
          if (walk4 != null) walkSegments.add(walk4);
          if (walk5 != null) walkSegments.add(walk5);

          return JourneyPlan(
            vehicleSegments: [segment1, segment2, segment3, segment4],
            walkingSegments: walkSegments,
          );
        }
      }
    }
  }
  return null;
}

Future<JourneyPlan?> calculateTricycleJeepTricycleJourney({
  required LatLng startPoint,
  required LatLng endPoint,
}) async {
  final tricycleRoutes = routes.where((r) => r.vehicleType == 'tricycle').toList();
  final jeepneyRoutes = routes.where((r) => r.vehicleType == 'jeep').toList();

  for (final startTrike in tricycleRoutes) {

    final startNearest = findNearestPointOnRoute(startPoint, startTrike);
    if (calculateDistance(startPoint, startNearest.point) > 200) continue;

    for (final jeepRoute in jeepneyRoutes) {

      final toJeepTransfer = findTransferPoints(startTrike, jeepRoute);
      if (toJeepTransfer.isEmpty) continue;

      for (final endTrike in tricycleRoutes) {
        if (endTrike == startTrike) continue;

        final toEndTrikeTransfer = findTransferPoints(jeepRoute, endTrike);
        if (toEndTrikeTransfer.isEmpty) continue;

        final endNearest = findNearestPointOnRoute(endPoint, endTrike);
        if (calculateDistance(endPoint, endNearest.point) > 200) continue;

        final segment1 = createRouteSegment(
          route: startTrike,
          startPoint: startNearest,
          endPoint: findNearestPointOnRoute(toJeepTransfer.first.startTransfer.point, startTrike),
        );

        final segment2 = createRouteSegment(
          route: jeepRoute,
          startPoint: findNearestPointOnRoute(toJeepTransfer.first.endTransfer.point, jeepRoute),
          endPoint: findNearestPointOnRoute(toEndTrikeTransfer.first.startTransfer.point, jeepRoute),
        );

        final segment3 = createRouteSegment(
          route: endTrike,
          startPoint: findNearestPointOnRoute(toEndTrikeTransfer.first.endTransfer.point, endTrike),
          endPoint: endNearest,
        );

        if (segment1 == null || segment2 == null || segment3 == null) continue;

        final walkSegments = <List<LatLng>>[];
        final walk1 = await getWalkingRoute(startPoint, segment1.boardingPoint);
        final walk2 = await getWalkingRoute(segment1.alightingPoint, segment2.boardingPoint);
        final walk3 = await getWalkingRoute(segment2.alightingPoint, segment3.boardingPoint);
        final walk4 = await getWalkingRoute(segment3.alightingPoint, endPoint);

        if (walk1 != null) walkSegments.add(walk1);
        if (walk2 != null) walkSegments.add(walk2);
        if (walk3 != null) walkSegments.add(walk3);
        if (walk4 != null) walkSegments.add(walk4);

        return JourneyPlan(
          vehicleSegments: [segment1, segment2, segment3],
          walkingSegments: walkSegments,
        );
      }
    }
  }
  return null;
}


Future<JourneyPlan?> calculateTricycleJeepJeepTricycleJourney({
  required LatLng startPoint,
  required LatLng endPoint,
}) async {
  final tricycleRoutes = routes.where((r) => r.vehicleType == 'tricycle').toList();
  final jeepneyRoutes = routes.where((r) => r.vehicleType == 'jeep').toList();

  for (final startTrike in tricycleRoutes) {
    final startNearest = findNearestPointOnRoute(startPoint, startTrike);
    if (calculateDistance(startPoint, startNearest.point) > 500) continue;

    for (final jeep1 in jeepneyRoutes) {
      final transfer1 = findTransferPoints(startTrike, jeep1);
      if (transfer1.isEmpty) continue;

      for (final jeep2 in jeepneyRoutes) {
        if (jeep2 == jeep1) continue;
        final transfer2 = findTransferPoints(jeep1, jeep2);
        if (transfer2.isEmpty) continue;

        for (final endTrike in tricycleRoutes) {
          if (endTrike == startTrike) continue;

          final transfer3 = findTransferPoints(jeep2, endTrike);
          if (transfer3.isEmpty) continue;

          final endNearest = findNearestPointOnRoute(endPoint, endTrike);
          if (calculateDistance(endPoint, endNearest.point) > 500) continue;

          final segment1 = createRouteSegment(
            route: startTrike,
            startPoint: startNearest,
            endPoint: findNearestPointOnRoute(transfer1.first.startTransfer.point, startTrike),
          );

          final segment2 = createRouteSegment(
            route: jeep1,
            startPoint: findNearestPointOnRoute(transfer1.first.endTransfer.point, jeep1),
            endPoint: findNearestPointOnRoute(transfer2.first.startTransfer.point, jeep1),
          );

          final segment3 = createRouteSegment(
            route: jeep2,
            startPoint: findNearestPointOnRoute(transfer2.first.endTransfer.point, jeep2),
            endPoint: findNearestPointOnRoute(transfer3.first.startTransfer.point, jeep2),
          );

          final segment4 = createRouteSegment(
            route: endTrike,
            startPoint: findNearestPointOnRoute(transfer3.first.endTransfer.point, endTrike),
            endPoint: endNearest,
          );

          if (segment1 == null || segment2 == null || segment3 == null || segment4 == null) continue;

          final walkSegments = <List<LatLng>>[];
          final walk1 = await getWalkingRoute(startPoint, segment1.boardingPoint);
          final walk2 = await getWalkingRoute(segment1.alightingPoint, segment2.boardingPoint);
          final walk3 = await getWalkingRoute(segment2.alightingPoint, segment3.boardingPoint);
          final walk4 = await getWalkingRoute(segment3.alightingPoint, segment4.boardingPoint);
          final walk5 = await getWalkingRoute(segment4.alightingPoint, endPoint);

          if (walk1 != null) walkSegments.add(walk1);
          if (walk2 != null) walkSegments.add(walk2);
          if (walk3 != null) walkSegments.add(walk3);
          if (walk4 != null) walkSegments.add(walk4);
          if (walk5 != null) walkSegments.add(walk5);

          return JourneyPlan(
            vehicleSegments: [segment1, segment2, segment3, segment4],
            walkingSegments: walkSegments,
          );
        }
      }
    }
  }
  return null;
}


Future<JourneyPlan?> calculateTrikeTrikeTrikeJeepJeepJourney({
  required LatLng startPoint,
  required LatLng endPoint,
}) async {
  final tricycleRoutes = routes.where((r) => r.vehicleType == 'tricycle').toList();
  final jeepneyRoutes = routes.where((r) => r.vehicleType == 'jeep').toList();

  for (final trike1 in tricycleRoutes) {
    final startNearest = findNearestPointOnRoute(startPoint, trike1);
    if (calculateDistance(startPoint, startNearest.point) > 500) continue;

    for (final trike2 in tricycleRoutes) {
      if (trike2 == trike1) continue;
      final transfer1 = findTransferPoints(trike1, trike2);
      if (transfer1.isEmpty) continue;

      for (final trike3 in tricycleRoutes) {
        if (trike3 == trike2 || trike3 == trike1) continue;
        final transfer2 = findTransferPoints(trike2, trike3);
        if (transfer2.isEmpty) continue;

        for (final jeep1 in jeepneyRoutes) {
          final transfer3 = findTransferPoints(trike3, jeep1);
          if (transfer3.isEmpty) continue;

          for (final jeep2 in jeepneyRoutes) {
            if (jeep2 == jeep1) continue;
            final transfer4 = findTransferPoints(jeep1, jeep2);
            if (transfer4.isEmpty) continue;

            final endNearest = findNearestPointOnRoute(endPoint, jeep2);
            if (calculateDistance(endPoint, endNearest.point) > 500) continue;

            final segment1 = createRouteSegment(
              route: trike1,
              startPoint: startNearest,
              endPoint: findNearestPointOnRoute(transfer1.first.startTransfer.point, trike1),
            );

            final segment2 = createRouteSegment(
              route: trike2,
              startPoint: findNearestPointOnRoute(transfer1.first.endTransfer.point, trike2),
              endPoint: findNearestPointOnRoute(transfer2.first.startTransfer.point, trike2),
            );

            final segment3 = createRouteSegment(
              route: trike3,
              startPoint: findNearestPointOnRoute(transfer2.first.endTransfer.point, trike3),
              endPoint: findNearestPointOnRoute(transfer3.first.startTransfer.point, trike3),
            );

            final segment4 = createRouteSegment(
              route: jeep1,
              startPoint: findNearestPointOnRoute(transfer3.first.endTransfer.point, jeep1),
              endPoint: findNearestPointOnRoute(transfer4.first.startTransfer.point, jeep1),
            );

            final segment5 = createRouteSegment(
              route: jeep2,
              startPoint: findNearestPointOnRoute(transfer4.first.endTransfer.point, jeep2),
              endPoint: endNearest,
            );

            if (segment1 == null || segment2 == null || segment3 == null || segment4 == null || segment5 == null) continue;

            final walkSegments = <List<LatLng>>[];
            final walk1 = await getWalkingRoute(startPoint, segment1.boardingPoint);
            final walk2 = await getWalkingRoute(segment1.alightingPoint, segment2.boardingPoint);
            final walk3 = await getWalkingRoute(segment2.alightingPoint, segment3.boardingPoint);
            final walk4 = await getWalkingRoute(segment3.alightingPoint, segment4.boardingPoint);
            final walk5 = await getWalkingRoute(segment4.alightingPoint, segment5.boardingPoint);
            final walk6 = await getWalkingRoute(segment5.alightingPoint, endPoint);

            if (walk1 != null) walkSegments.add(walk1);
            if (walk2 != null) walkSegments.add(walk2);
            if (walk3 != null) walkSegments.add(walk3);
            if (walk4 != null) walkSegments.add(walk4);
            if (walk5 != null) walkSegments.add(walk5);
            if (walk6 != null) walkSegments.add(walk6);

            return JourneyPlan(
              vehicleSegments: [segment1, segment2, segment3, segment4, segment5],
              walkingSegments: walkSegments,
            );
          }
        }
      }
    }
  }

  return null;
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

  candidates.sort((
    a,
    b,
  ) =>
      a['distance'].compareTo(b['distance']));
  return candidates.isNotEmpty ? candidates.first['route'] as RouteData : null;
}

RouteData? findSingleRoute(LatLng start, LatLng end) {
  final List<Map<String, dynamic>> candidates = [];

  for (final r in routes) {
    final startNearest = findNearestPointOnRoute(start, r);
    final endNearest = findNearestPointOnRoute(end, r);

    final startDist = calculateDistance(start, startNearest.point);
    final endDist = calculateDistance(end, endNearest.point);

    if (r.vehicleType == 'tricycle') {
      if (startDist <= 200 && endDist <= 200) {
        candidates.add({
          'route': r,
          'score': startDist + endDist,
        });
      }
    } else {
      if (startDist > 80 || endDist > 80) continue;
      bool isValidDirection = r.direction == 'bidirectional' ||
          (r.direction == 'southbound' &&
              startNearest.index <= endNearest.index) ||
          (r.direction == 'northbound' &&
              startNearest.index >= endNearest.index);

      if (isValidDirection) {
        candidates.add({
          'route': r,
          'score': startDist + endDist,
        });
      }
    }
  }

  candidates.sort((a, b) => a['score'].compareTo(b['score']));
  return candidates.isNotEmpty ? candidates.first['route'] : null;
}

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

RouteSegment? createRouteSegment({
  required RouteData route,
  required NearestPoint startPoint,
  required NearestPoint endPoint,
}) {
  try {
    List<LatLng> segment;

    if (route.vehicleType == 'tricycle') {
      segment = route.path;
    } else {

      if (startPoint.index <= endPoint.index) {
        segment = route.path.sublist(startPoint.index, endPoint.index + 1);
      } else {
        segment = route.path
            .sublist(endPoint.index, startPoint.index + 1)
            .reversed
            .toList();
      }
    }

    return RouteSegment(
      route: route,
      boardingPoint: startPoint.point,
      alightingPoint: endPoint.point,
      pathSegment: segment,
      vehicleType: route.vehicleType,
    );
  } catch (e) {
    debugPrint("Segment creation error: $e");
    return null;
  }
}
