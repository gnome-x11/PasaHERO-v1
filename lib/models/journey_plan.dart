import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit/models/route_segment.dart';

class JourneyPlan {
  List<RouteSegment> vehicleSegments; // Generalized from jeepSegments
  List<List<LatLng>> walkingSegments;

  JourneyPlan({
    required this.vehicleSegments,
    required this.walkingSegments,
  });
}
