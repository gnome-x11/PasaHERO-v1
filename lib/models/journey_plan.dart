//models/
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit/models/route_segment.dart';

class JourneyPlan {
  final List<RouteSegment> jeepSegments;
  final List<List<LatLng>> walkingSegments;
   final List<TricycleSegment> tricycleSegments; // Add this

  JourneyPlan({
    required this.jeepSegments,
    required this.walkingSegments,
     this.tricycleSegments = const [],
  });
}

class TricycleSegment {
  final LatLng boardingPoint;
  final LatLng alightingPoint;
  final String todaName;

  TricycleSegment({
    required this.boardingPoint,
    required this.alightingPoint,
    required this.todaName,
  });
}
