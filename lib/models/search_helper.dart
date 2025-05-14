//models

import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<String> getAddressFromLatLngV2(LatLng position) async {
  try {
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isNotEmpty) {
      Placemark place = placemarks.first;
      return "${place.street}, ${place.subLocality}, ${place.locality}";
    }
  } catch (e) {
    print("Error getting address: $e");
  }
  return "Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})";
}
