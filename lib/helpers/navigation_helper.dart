// helper

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit/utils/journey_planner.dart';

class NavigationUpdateResult {
  final Set<Polyline> updatedPolylines;
  final double distanceRemaining;
  final int timeRemaining;
  final String nextInstruction;

  NavigationUpdateResult({
    required this.updatedPolylines,
    required this.distanceRemaining,
    required this.timeRemaining,
    required this.nextInstruction,
  });
}

NavigationUpdateResult updateNavigationInfo({
  required LatLng currentPos,
  required List<Polyline> originalPolylines,
  required LatLng destinationPoint,
  required String currentInstruction,
  required bool isNavigating,
}) {
  Set<Polyline> updatedPolylines = {};
  String newInstruction = currentInstruction;

  for (Polyline original in originalPolylines) {
    List<LatLng> points = original.points;
    if (points.isEmpty) continue;

    int closestIndex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < points.length; i++) {
      double distance = calculateDistance(currentPos, points[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    if (closestIndex < points.length - 1) {
      double nextDistance =
          calculateDistance(currentPos, points[closestIndex + 1]);
      if (nextDistance < minDistance) {
        closestIndex++;
      }
    }

    if (isNavigating) {
      List<LatLng> passedPoints = points.sublist(0, closestIndex + 1);
      List<LatLng> remainingPoints = points.sublist(closestIndex);

      updatedPolylines.add(Polyline(
        polylineId: PolylineId('${original.polylineId}_passed'),
        points: passedPoints,
        color: original.color.withOpacity(0.10),
        width: original.width,
        patterns: original.patterns,
        geodesic: original.geodesic,
      ));

      updatedPolylines.add(Polyline(
        polylineId: PolylineId('${original.polylineId}_remaining'),
        points: remainingPoints,
        color: original.color,
        width: original.width,
        patterns: original.patterns,
        geodesic: original.geodesic,
      ));

    } else {
      updatedPolylines.add(original);
    }
  }

  double calculatePolylineDistance(LatLng from, LatLng to) {
    for (var poly in originalPolylines) {
      if (poly.points.contains(from) && poly.points.contains(to)) {
        int fromIndex = poly.points.indexOf(from);
        int toIndex = poly.points.indexOf(to);
        if (fromIndex < toIndex) {
          double distance = 0;
          for (int i = fromIndex; i < toIndex; i++) {
            distance += calculateDistance(poly.points[i], poly.points[i + 1]);
          }
          return distance;
        }
      }
    }
    return calculateDistance(from, to);
  }

  double distanceRemaining =
      calculatePolylineDistance(currentPos, destinationPoint);
  int timeRemaining = (distanceRemaining / (5000 / 60)).round();

  return NavigationUpdateResult(
    updatedPolylines: updatedPolylines,
    distanceRemaining: distanceRemaining,
    timeRemaining: timeRemaining,
    nextInstruction: newInstruction,
  );
}
