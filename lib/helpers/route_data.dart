//helper

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit/models/nearest_point.dart';

class RouteData {
  final String name;
  final List<LatLng> path;
  final LatLng startPoint;
  final LatLng endPoint;
  final String direction;
  final String baseName;
  final String displayName;
  final Map<LatLng, NearestPoint> indexCache = {};

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
      return 'South Station, Alabang to Las Piñas';
    } else if (cleanName.contains('ALABANG TO SUCAT BAYBAYIN')) {
      return 'Alabang, Montillano to Sucat via Baybayin';
    } else if (cleanName.contains('ALABANG TO SUCAT KALIWA')) {
      return 'South Station, Alabang to Sucat Kaliwa via West Service Road';
    } else if (cleanName.contains('ALABANG TO SUCAT KANAN')) {
      return 'Montillano, Alabang to Sucat via East Service Road';
    } else if (cleanName.contains('ALABANG TO TUNASAN')) {
      return 'Alabang to Muntinlupa, Tunasan via National Road';
    } else if (cleanName.contains('BAYAN TO MAIN GATE')) {
      return 'Muntinlupa, Bayan to Main Gate Katihan';
    } else if (cleanName
        .contains('MUNTINLUPA LAS PINAS BOUNDARY TO SOUTHVILLE3')) {
      return 'Investment Drive to Southville 3 Terminal';
    } else if (cleanName.contains('POBLACION SOUTHVILLE 3')) {
      return 'Bayan, Muntinlupa to Southville 3 via Susana';
    } else if (cleanName.contains('SOUTHVILLE3 TO ALABANG')) {
      return 'Southville 3 to Alabang via National Road';
    } else if (cleanName.contains('TUNASAN TO ALABANG')) {
      return 'Muntinlupa, Tunasan to Alabang via National Road';
    } else if (cleanName
        .contains('BIAZON ROAD TO MUNTINLUPA LAS PINAS BOUNDARY')) {
      return 'Biazon Road to Investment Drive Las Piñas/Muntinlupa Boundary';
    } else if (cleanName.contains('LAS PINAS BOUNDARY TO ALABANG')) {
      return 'Alabang Zapote - Alabang Palengke ';
    } else if (cleanName.contains('SOUTHVILLE3 TO POBLACION')) {
      return 'Southville 3 Terminal to Bayan, Poblacion';
    }

    // Format remaining names with proper capitalization
    return cleanName.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
