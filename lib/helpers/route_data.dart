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
  final String vehicleType;
  final Map<LatLng, NearestPoint> indexCache = {};

  RouteData({
    required this.name,
    required this.path,
    required this.startPoint,
    required this.endPoint,
    required this.direction,
    required this.baseName,
    required this.vehicleType,

  }) : displayName = _getDisplayName(name);

  static String _getDisplayName(String fileName) {
    String cleanName = fileName
        .replaceAll('P_', '')
        .replaceAll('_NORTHBOUND', '')
        .replaceAll('_SOUTHBOUND', '')
        .replaceAll('_NORTHBOUND_SOUTHBOUND', '')
        .replaceAll('_', ' ')
        .replaceAll('_TRICYCLE' , '')
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
    } else if (cleanName.contains('MUNISIPYO TRICYCLE TERMINAL')) {
      return 'PRILASSCATODA | Munisipyo';
    } else if (cleanName.contains('MAINGATE TRICYCLE TERMINAL')) {
      return 'NBPTODAI | Type B';
    } else if (cleanName.contains('BAYAN TRICYCLE TERMINAL')) {
      return 'NBPTODAI | Bayan';
    } else if (cleanName.contains('NBP TRICYCLE TERMINAL')) {
      return 'NBPTODA | NBP Reservation';
    } else if (cleanName.contains('TYPEB TRICYCLE TERMINAL')) {
      return 'NBPTODAI | Maximum';
    } else if (cleanName.contains('MAIN TRICYCLE TERMINAL')) {
      return 'PLMUNTODA | PLMun';
    } else if (cleanName.contains('BRUGER TRICYCLE TERMINAL')) {
      return 'BSPPMTODAI | Putatan';
    } else if (cleanName.contains("BUKAL TRICYCLE TERMINAL")) {
      return 'ABSBPMTODA | Bukal';
    } else if (cleanName.contains('SOLDIERS TRICYCLE TERMINAL')) {
      return 'SHIMCTODA | Soldiers';
    } else if (cleanName.contains("PHASE3 TRICYCLE TERMINAL")){
      return 'SHIMCTODA | Soldiers';
    } else if (cleanName.contains('BAYANAN2 TRICYCLE TERMINAL')) {
      return 'BBTODAI | Bayanan';
    } else if (cleanName.contains('BAYANAN TRICYCLE TERMINAL')) {
      return 'BBTODAI | Bayanan';
    } else if (cleanName.contains('NOVO TRICYCLE TEMRINAL')) {
      return 'ACMSTODA | Alabang';
    } else if (cleanName.contains('KATARUNGAN TRICYCLE TERMINAL')) {
      return 'JUSVILTODA | Katarungan Village';
    }

    // Format remaining names with proper capitalization
    return cleanName.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // int indexOfPoint(LatLng point, {double tolerance = 0.00001}) {
  //   for (int i = 0; i < path.length; i++) {
  //     if ((path[i].latitude - point.latitude).abs() < tolerance &&
  //         (path[i].longitude - point.longitude).abs() < tolerance) {
  //       return i;
  //     }
  //   }
  //   return -1;
  // }
}
