//models/
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit/models/route_segment.dart';

class JourneyPlan {
  final List<RouteSegment> jeepSegments;
  final List<List<LatLng>> walkingSegments;


  JourneyPlan({
    required this.jeepSegments,
    required this.walkingSegments,

  });
}

