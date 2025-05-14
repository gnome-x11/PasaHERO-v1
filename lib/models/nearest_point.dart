//models
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NearestPoint {
  final LatLng point;
  final int index;

  NearestPoint(this.point, this.index);
}