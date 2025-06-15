// //models

// import 'package:geocoding/geocoding.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';

// Future<String> getAddressFromLatLngV2(LatLng position) async {
//   try {
//     List<Placemark> placemarks = await placemarkFromCoordinates(
//       position.latitude,
//       position.longitude,
//     );

//     if (placemarks.isNotEmpty) {
//       Placemark place = placemarks.first;
//       return [
//         place.street,
//         place.subLocality,
//         place.locality,
//         place.administrativeArea
//       ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ');
//     }

//   } catch (e) {
//     print("Error getting address: $e");
//   }
//   return "Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})";
// }



import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<String> getAddressFromLatLngV2(LatLng position) async {
final String googleApiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
    '?location=${position.latitude},${position.longitude}'
    '&radius=100' // You can increase this (e.g., 200–500) if needed
    '&type=point_of_interest'
    '&key=$googleApiKey',
  );

  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['results'] != null && data['results'].isNotEmpty) {
        final first = data['results'][0];
        final name = first['name'];

        return '$name';
      } else {
        return 'No nearby landmark found';
      }
    } else {
      print('Google Places API error: ${response.statusCode}');
    }
  } catch (e) {
    print('Error using Google Places API: $e');
  }

  return "Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})";
}
