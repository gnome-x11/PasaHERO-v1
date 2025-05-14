//models/alarm_state_helper.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';

class AlarmState {
  final LatLng point;
  final double radius;
  bool isTriggered;
  bool isAcknowledged;

  AlarmState({
    required this.point,
    required this.radius,
    this.isTriggered = false,
    this.isAcknowledged = false,
  });
}
