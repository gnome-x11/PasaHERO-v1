//models

import 'package:google_maps_flutter/google_maps_flutter.dart';

class TransferPoint {
  final LatLng startTransfer;
  final LatLng endTransfer;
  final double distance;

  TransferPoint({
    required this.startTransfer,
    required this.endTransfer,
    required this.distance,
  });
}
