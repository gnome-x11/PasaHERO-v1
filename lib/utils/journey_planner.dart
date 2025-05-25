//jpurney_planner_model.dart

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit/pages/home_page.dart';
import 'package:google_maps_utils/poly_utils.dart';
import 'package:transit/helpers/loadgpx_files.dart';

import '../helpers/route_data.dart';
import '../models/route_segment.dart';
import '../models/transfer_point.dart';
import '../models/nearest_point.dart';
import '../models/journey_plan.dart';

double calculateDistanceToPath(LatLng point, List<LatLng> path) {
  return path.map((p) => calculateDistance(point, p)).reduce((
        a,
        b,
      ) =>
          a < b ? a : b);
}

double calculateDistance(LatLng point1, LatLng point2) {
  const double R = 6371000;
  final lat1 = point1.latitude * pi / 180;
  final lat2 = point2.latitude * pi / 180;
  final deltaLat = (point2.latitude - point1.latitude) * pi / 180;
  final deltaLng = (point2.longitude - point1.longitude) * pi / 180;

  final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
      cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return R * c;
}

Map<String, dynamic> findNearestJeepneyStopWithIndex(
  LatLng userLocation, {
  RouteData? route,
  String? direction,
}) {
  final List<RouteData> routesToCheck = route != null
      ? [route]
      : routes.where((r) {
          return direction == null ||
              r.direction == direction ||
              r.direction == 'bidirectional';
        }).toList();

  LatLng? nearestPoint;
  int nearestIndex = -1;
  double minDistance = double.infinity;

  for (final r in routesToCheck) {
    for (int i = 0; i < r.path.length; i++) {
      final distance = calculateDistance(userLocation, r.path[i]);
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = r.path[i];
        nearestIndex = i;
      }
    }
  }

  return {'point': nearestPoint, 'index': nearestIndex};
}

RouteData? findNearestRoute(LatLng point, {String? preferredDirection}) {
  return routes
      .where((r) =>
          preferredDirection == null ||
          r.direction == 'bidirectional' ||
          r.direction == preferredDirection)
      .reduce((a, b) {
    final d1 = calculateDistanceToPath(point, a.path);
    final d2 = calculateDistanceToPath(point, b.path);
    return d1 < d2 ? a : b;
  });
}

NearestPoint findNearestPointOnRoute(LatLng target, RouteData route) {
  int nearestIndex = 0;
  double minDistance = double.infinity;

  for (int i = 0; i < route.path.length; i++) {
    final distance = calculateDistance(target, route.path[i]);
    if (distance < minDistance) {
      minDistance = distance;
      nearestIndex = i;
    }
  }

  return NearestPoint(route.path[nearestIndex], nearestIndex);
}

List<TransferPoint> findTransferPoints(RouteData route1, RouteData route2) {
  const double maxTransferDistance = 500;
  const double overlapThreshold = 100;
  final transfers = <TransferPoint>[];

  if (areRoutesOverlapping(route1, route2, threshold: overlapThreshold)) {
    return [];
  }

  for (int i = 0; i < route1.path.length; i += 5) {
    final point1 = route1.path[i];
    final nearestOnRoute2 = findNearestPointOnRoute(point1, route2);
    final distance = calculateDistance(point1, nearestOnRoute2.point);

    if (distance <= maxTransferDistance) {
      transfers.add(TransferPoint(
        startTransfer: point1,
        endTransfer: nearestOnRoute2.point,
        distance: distance,
      ));
    }
  }

  transfers.sort((a, b) => a.distance.compareTo(b.distance));
  return transfers;
}

bool areRoutesOverlapping(RouteData r1, RouteData r2, {double threshold = 20}) {
  int overlapCount = 0;
  const int overlapLimit = 10;

  for (int i = 0; i < r1.path.length; i += 3) {
    final p1 = r1.path[i];
    final nearest = findNearestPointOnRoute(p1, r2);
    final distance = calculateDistance(p1, nearest.point);
    if (distance < threshold) {
      overlapCount++;
      if (overlapCount >= overlapLimit) return true;
    }
  }

  return false;
}

RouteData? findSingleRoute(LatLng start, LatLng end) {
  for (final r in routes) {
    final startDist = calculateDistanceToPath(start, r.path);
    final endDist = calculateDistanceToPath(end, r.path);

    // Increased threshold to 200 meters
    if (startDist < 200 && endDist < 200) {
      final startPointResult = findNearestPointOnRoute(start, r);
      final endPointResult = findNearestPointOnRoute(end, r);

      // Handle direction-specific index checks
      bool isValidDirection = false;
      if (r.direction == 'bidirectional') {
        isValidDirection = true;
      } else if (r.direction == 'southbound') {
        // Ensure path is ordered north to south; start index <= end index
        isValidDirection = startPointResult.index <= endPointResult.index;
      } else if (r.direction == 'northbound') {
        // Ensure path is ordered south to north; start index <= end index
        isValidDirection = startPointResult.index <= endPointResult.index;
      }

      if (isValidDirection) {
        return r;
      }
    }
  }
  return null;
}

Future<JourneyPlan?> calculateJourneyPlan({
  required LatLng startPoint,
  required LatLng endPoint,
  required RouteData startRoute,
  required RouteData destRoute,
}) async {
  final jeepSegments = <RouteSegment>[];
  final walkingSegments = <List<LatLng>>[];

  final oneRoute = findSingleRoute(startPoint, endPoint);
  if (oneRoute != null) {
    final startNearest = findNearestPointOnRoute(startPoint, oneRoute);
    final destNearest = findNearestPointOnRoute(endPoint, oneRoute);

    final segment = createRouteSegment(
      route: oneRoute,
      startPoint: startNearest,
      endPoint: destNearest,
    );

    if (segment == null) return null;

    jeepSegments.add(segment);

    final walkStart = await getWalkingRoute(startPoint, segment.boardingPoint);
    final walkEnd = await getWalkingRoute(segment.alightingPoint, endPoint);
    if (walkStart != null) walkingSegments.add(walkStart);
    if (walkEnd != null) walkingSegments.add(walkEnd);

    return JourneyPlan(
      jeepSegments: jeepSegments,
      walkingSegments: walkingSegments,
    );
  }

  if (startRoute == destRoute) {
    final startNearest = findNearestPointOnRoute(startPoint, startRoute);
    final destNearest = findNearestPointOnRoute(endPoint, destRoute);

    final segment = createRouteSegment(
      route: startRoute,
      startPoint: startNearest,
      endPoint: destNearest,
    );

    if (segment == null) return null;

    jeepSegments.add(segment);

    final walkStart = await getWalkingRoute(startPoint, segment.boardingPoint);
    final walkEnd = await getWalkingRoute(segment.alightingPoint, endPoint);
    if (walkStart != null) walkingSegments.add(walkStart);
    if (walkEnd != null) walkingSegments.add(walkEnd);
  } else {
    final directTransfers = findTransferPoints(startRoute, destRoute);
    if (directTransfers.isNotEmpty) {
      final transfer = directTransfers.first;

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

      final walkTransfer = await getWalkingRoute(
        segment1.alightingPoint,
        segment2.boardingPoint,
      );
      if (walkTransfer != null) walkingSegments.add(walkTransfer);
    } else {
      final intermediateRoute =
          findBestIntermediateRoute(startRoute, destRoute);
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

      if ([segment1, segment2, segment3].contains(null)) return null;

      jeepSegments.addAll([segment1!, segment2!, segment3!]);

      final walkStart =
          await getWalkingRoute(startPoint, segment1.boardingPoint);
      final walkTransfer1 = await getWalkingRoute(
          segment1.alightingPoint, segment2.boardingPoint);
      final walkTransfer2 = await getWalkingRoute(
          segment2.alightingPoint, segment3.boardingPoint);
      final walkEnd = await getWalkingRoute(segment3.alightingPoint, endPoint);

      if (walkTransfer1 == null || walkTransfer2 == null) return null;

      if (walkStart != null) walkingSegments.add(walkStart);
      walkingSegments.addAll([walkTransfer1, walkTransfer2]);
      if (walkEnd != null) walkingSegments.add(walkEnd);
    }
  }

  if (jeepSegments.isEmpty) return null;

  return JourneyPlan(
    jeepSegments: jeepSegments,
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
  return candidates.isNotEmpty ? candidates.first['route'] : null;
}

RouteSegment? createRouteSegment({
  required RouteData route,
  required NearestPoint startPoint,
  required NearestPoint endPoint,
}) {
  try {
    final path = route.path;
    final segment = (startPoint.index <= endPoint.index)
        ? path.sublist(startPoint.index, endPoint.index + 1)
        : path.sublist(endPoint.index, startPoint.index + 1).reversed.toList();

    return RouteSegment(
      route: route,
      boardingPoint: startPoint.point,
      alightingPoint: endPoint.point,
      pathSegment: segment,
    );
  } catch (e) {
    print("Error creating segment: $e");
    return null;
  }
}

Future<List<LatLng>?> getWalkingRoute(LatLng start, LatLng end) async {
  final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
      'origin=${start.latitude},${start.longitude}&'
      'destination=${end.latitude},${end.longitude}&'
      'mode=walking&'
      'alternatives=true&'
      'key=$googleApiKey';

  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      print('Google Maps API error: ${response.statusCode}');
      return [start, end]; // fallback: straight line
    }

    final data = json.decode(response.body);

    if (data['status'] != 'OK' || data['routes'].isEmpty) {
      print('No valid route found, falling back.');
      return [start, end]; // fallback: straight line
    }

    final routes = data['routes'] as List;

    // Sort routes by distance
    routes.sort((a, b) =>
        a['legs'][0]['distance']['value'].compareTo(b['legs'][0]['distance']['value']));

    // Try to get full detailed path from steps
    final steps = routes[0]['legs'][0]['steps'] as List;
    final List<LatLng> fullRoute = [];

    try {
      for (var step in steps) {
        final points = PolyUtils.decode(step['polyline']['points']);
        fullRoute.addAll(points.map((p) => LatLng(p.x.toDouble(), p.y.toDouble())));
      }

      if (fullRoute.isNotEmpty) return fullRoute;
    } catch (stepError) {
      print('Step decoding failed: $stepError');
    }

    // Fallback: overview_polyline
    try {
      final overviewPoints = routes[0]['overview_polyline']['points'] as String;
      final polyline = PolyUtils.decode(overviewPoints);

      return polyline.map((p) => LatLng(p.x.toDouble(), p.y.toDouble())).toList();
    } catch (overviewError) {
      print('Overview polyline decoding failed: $overviewError');
    }
  } catch (e) {
    print('Unexpected error: $e');
  }

  // Final fallback if all else fails
  return [start, end];
}


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
