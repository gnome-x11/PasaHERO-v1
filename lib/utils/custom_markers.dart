//utils

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit/models/journey_plan.dart';
import 'package:transit/helpers/noti_service.dart';
import '../helpers/loadgpx_files.dart';
import '../utils/journey_planner.dart';

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
      color: Color(0xFFFFFFF9),
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

  final double directDistance =
      calculateDistance(startLocationPoint, destinationPoint);

  if (directDistance <= 400) {
    final walkPath =
        await getWalkingRoute(startLocationPoint, destinationPoint);

    if (walkPath != null && walkPath.isNotEmpty) {
      updatedPolylines.add(Polyline(
        polylineId: const PolylineId('walk_direct'),
        points: walkPath,
        color: Colors.orange,
        width: 5,
        patterns: [PatternItem.dash(10), PatternItem.gap(15)],
        geodesic: true,
      ));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Destination is within walking distance (${directDistance.toStringAsFixed(0)}m)",
          ),
        ),
      );
    } else {
      updatedPolylines.add(Polyline(
        polylineId: const PolylineId('walk_direct'),
        points: [startLocationPoint, destinationPoint],
        color: const Color.fromARGB(255, 255, 115, 0),
        width: 8,
        patterns: [PatternItem.dash(10), PatternItem.gap(15)],
        geodesic: true,
      ));
    }

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

  // ✅ PATCH: Filter out short initial jeep segments
  if (journeyPlan.jeepSegments.length == 2) {
    final first = journeyPlan.jeepSegments.first;
    final second = journeyPlan.jeepSegments.last;

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
        jeepSegments: [second],
      );

      // replace the original journeyPlan with filtered one
      journeyPlan.jeepSegments.clear();
      journeyPlan.jeepSegments.addAll(filteredPlan.jeepSegments);

      journeyPlan.walkingSegments.clear();
      journeyPlan.walkingSegments.addAll(filteredPlan.walkingSegments);
    }
  }

  final routeColors = [Colors.blue, Colors.deepPurpleAccent, Colors.pink];
  int colorIndex = 0;

  for (final segment in journeyPlan.jeepSegments) {
    final color = routeColors[colorIndex % routeColors.length];

    final boardingMarkerId = MarkerId("boarding_${segment.route.name}");
    final boardingIcon = await createCustomMarker("Board", color);
    updatedMarkers[boardingMarkerId] = Marker(
      markerId: boardingMarkerId,
      position: segment.boardingPoint,
      icon: boardingIcon,
      infoWindow: InfoWindow(
        title: "Board ${segment.route.displayName}",
        snippet: "Start of jeepney ride",
      ),
    );

    final alightingMarkerId = MarkerId("alighting_${segment.route.name}");
    final alightingIcon = await createCustomMarker("Get Off", color);
    updatedMarkers[alightingMarkerId] = Marker(
      markerId: alightingMarkerId,
      position: segment.alightingPoint,
      icon: alightingIcon,
      infoWindow: InfoWindow(
        title: "Get Off ${segment.route.displayName}",
        snippet: "End of jeepney ride",
      ),
    );

    updatedPolylines.add(Polyline(
      polylineId: PolylineId("route_${segment.route.name}"),
      points: segment.pathSegment,
      color: color,
      width: 5,
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
      geodesic: true,
    ));
  }

  onUpdate(updatedMarkers.values.toSet(), updatedPolylines.toSet());
}
