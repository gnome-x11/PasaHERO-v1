//models


import 'package:transit/models/nearest_point.dart';

class TransferPoint {
  final NearestPoint startTransfer;
  final NearestPoint endTransfer;
  final double distance;

  TransferPoint({
    required this.startTransfer,
    required this.endTransfer,
    required this.distance,
  });
}
