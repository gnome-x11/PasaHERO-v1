//helper

import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteData {
  final String name;
  final List<LatLng> path;
  final LatLng startPoint;
  final LatLng endPoint;
  final String direction;
  final String baseName;
  final String displayName;

  RouteData({
    required this.name,
    required this.path,
    required this.startPoint,
    required this.endPoint,
    required this.direction,
    required this.baseName,
  }) : displayName = _getDisplayName(name);

  static String _getDisplayName(String fileName) {
    String cleanName = fileName
        .replaceAll('P_', '')
        .replaceAll('_NORTHBOUND', '')
        .replaceAll('_SOUTHBOUND', '')
        .replaceAll('_NORTHBOUND_SOUTHBOUND', '')
        .replaceAll('_', ' ')
        .replaceAll('LASPINAS', 'LAS PINAS');

    if (cleanName.contains('ALABANG TO MUNTINLUPA LAS PINAS BOUNDARY')) {
      return 'Alabang to Muntinlupa-Las Piñas Boundary';
    } else if (cleanName.contains('ALABANG TO SUCAT BAYBAYIN')) {
      return 'Alabang to Sucat (Baybayin)';
    } else if (cleanName.contains('ALABANG TO SUCAT KALIWA')) {
      return 'Alabang to Sucat (Kaliwa)';
    } else if (cleanName.contains('ALABANG TO SUCAT KANAN')) {
      return 'Alabang to Sucat (Kanan)';
    } else if (cleanName.contains('ALABANG TO TUNASAN')) {
      return 'Alabang to Tunasan';
    } else if (cleanName.contains('BAYAN TO MAIN GATE')) {
      return 'Bayan to Main Gate';
    } else if (cleanName
        .contains('MUNTINLUPA LAS PINAS BOUNDARY TO SOUTHVILLE3')) {
      return 'Muntinlupa-Las Piñas Boundary to Southville 3';
    } else if (cleanName.contains('POBLACION SOUTHVILLE 3')) {
      return 'Poblacion to Southville 3';
    } else if (cleanName.contains('SOUTHVILLE3 TO ALABANG')) {
      return 'Southville 3 to Alabang';
    } else if (cleanName.contains('TUNASAN TO ALABANG')) {
      return 'Tunasan to Alabang';
    } else if (cleanName
        .contains('BIAZON ROAD TO MUNTINLUPA LAS PINAS BOUNDARY')) {
      return 'Biazon Road to Muntinlupa-Las Piñas Boundary';
    } else if (cleanName.contains('LAS PINAS BOUNDARY TO ALABANG')) {
      return 'Muntinlupa-Las Piñas Boundary to Alabang';
    } else if (cleanName.contains('SOUTHVILLE3 TO POBLACION')) {
      return 'Southville 3 to Bayan, Poblacion';
    }

    // Format remaining names with proper capitalization
    return cleanName.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
