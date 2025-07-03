//helpers

import 'package:xml/xml.dart' as xml;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:transit/helpers/route_data.dart';

List<RouteData> routes = [];

Future<void> loadGPX() async {
  List<String> gpxFiles = [
    'assets/gpx/P_ALABANG_TO_MUNTINLUPA_LAS_PINAS_BOUNDARY_NORTHBOUND.gpx',
    'assets/gpx/P_ALABANG_TO_SUCAT_BAYBAYIN_NORTHBOUND_SOUTHBOUND.gpx',
    'assets/gpx/P_ALABANG_TO_SUCAT_KALIWA_NORTHBOUND.gpx',
    'assets/gpx/P_ALABANG_TO_SUCAT_KALIWA_SOUTHBOUND.gpx',
    'assets/gpx/P_ALABANG_TO_SUCAT_KANAN_NORTHBOUND.gpx',
    'assets/gpx/P_ALABANG_TO_SUCAT_KANAN_SOUTHBOUND.gpx',
    'assets/gpx/P_ALABANG_TO_TUNASAN_SOUTHBOUND.gpx',
    'assets/gpx/P_TUNASAN_TO_ALABANG_NORTHBOUND.gpx',
    //'assets/gpx/P_BAYAN_TO_MAIN_GATE_NORTHBOUND_SOUTHBOUND.gpx',
    'assets/gpx/P_BAYANAN2_TRICYCLE_TERMINAL.gpx',
    'assets/gpx/P_BIAZON_ROAD_TO_MUNTINLUPA_LASPINAS_BOUNDARY_NORTHBOUND.gpx',
    //'assets/gpx/P_MUNISIPYO_TRICYCLE_TERMINAL.gpx',
    'assets/gpx/P_KATARUNGAN_TRICYCLE_TERMINAL.gpx',
    'assets/gpx/P_BAYANAN_TRICYCLE_TERMINAL.gpx',
    'assets/gpx/P_MAIN_TRICYCLE_TERMINAL.gpx',
    'assets/gpx/P_MUNTINLUPA_LAS_PINAS_BOUNDARY_TO_SOUTHVILLE3_SOUTHBOUND.gpx',
    'assets/gpx/P_MUNTINLUPA_TO_LASPINAS_BOUNDARY_TO_ALABANG_SOUTHBOUND.gpx',
    'assets/gpx/P_NBP_TRICYCLE_TERMINAL.gpx',
    //'assets/gpx/P_MAINGATE_TRICYCLE_TERMINAL.gpx',
    'assets/gpx/P_NOVO_TRICYCLE_TERMINAL.gpx',
    'assets/gpx/P_PHASE3_TRICYCLE_TERMINAL.gpx',
    'assets/gpx/P_SOLDIERS_TRICYCLE_TERMINAL.gpx',
    'assets/gpx/P_BAYAN_TO_MAIN_NORTHBOUND_SOUTHBOUND.gpx',
    //'assets/gpx/P_POBLACION_SOUTHVILLE_3_SOUTHBOUND.gpx',
    //'assets/gpx/P_TYPEB_TRICYCLE_TERMINAL.gpx',
  ];

  for (String file in gpxFiles) {
    try {
      String gpxString = await rootBundle.loadString(file);
      List<LatLng> path = parseGpx(gpxString);

      String fileName = file.split('/').last.replaceAll('.gpx', '');
      String direction = parseDirectionFromFileName(fileName);
      String baseName = getBaseRouteName(fileName);
      String vehicleType = fileName.contains('TERMINAL') ? 'tricycle' : 'jeep';

      routes.add(RouteData(
        name: fileName,
        path: path,
        startPoint: path.first,
        endPoint: path.last,
        direction: direction,
        baseName: baseName,
        vehicleType: vehicleType,
      ));

      print('loaded gpx file $file: ');
    } catch (e) {
      print("Error loading GPX $file: $e");
    }
  }
}

String parseDirectionFromFileName(String fileName) {
  if (fileName.contains('NORTHBOUND_SOUTHBOUND')) {
    return 'bidirectional';
  } else if (fileName.contains('NORTHBOUND')) {
    return 'northbound';
  } else if (fileName.contains('SOUTHBOUND')) {
    return 'southbound';
  } else if (fileName.contains('TERMINAL')) {
    return 'bidirectional';
  }
  return 'bidirectional';
}

String getBaseRouteName(String fileName) {
  return fileName
      .replaceAll('_NORTHBOUND', '')
      .replaceAll('_SOUTHBOUND', '')
      .replaceAll('_NORTHBOUND_SOUTHBOUND', '')
      .replaceAll('_TRICYCLE', '');
}

String determineTravelDirection(LatLng start, LatLng end) {
  return end.latitude > start.latitude ? 'northbound' : 'southbound';
}

List<LatLng> parseGpx(String gpxContent) {
  final document = xml.XmlDocument.parse(gpxContent);
  final List<xml.XmlElement> trkpts =
      document.findAllElements('trkpt').toList();

  return trkpts.map((trkpt) {
    final lat = double.parse(trkpt.getAttribute('lat')!);
    final lon = double.parse(trkpt.getAttribute('lon')!);
    return LatLng(lat, lon);
  }).toList();
}
