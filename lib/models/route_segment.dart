//models

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit/helpers/route_data.dart';

class RouteSegment {
  final RouteData route;
  final LatLng boardingPoint;
  final LatLng alightingPoint;
  final List<LatLng> pathSegment;

  RouteSegment({
    required this.route,
    required this.boardingPoint,
    required this.alightingPoint,
    required this.pathSegment, required String vehicleType,
  });
}
