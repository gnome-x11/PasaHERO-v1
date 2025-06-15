//utils

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/custom_prediction.dart';

class SearchService {
  final String googleApiKey;
  LatLng? currentLocation;
  final LatLng _muntinlupaCenter = const LatLng(14.4134, 121.0225);
  final double _searchRadius = 5000;

  SearchService({required this.googleApiKey, this.currentLocation});

  void updateCurrentLocation(LatLng? newLocation) {
    currentLocation = newLocation;
  }

  Future<void> saveSearchHistory(List<CustomPrediction> searchHistory) async {
    final prefs = await SharedPreferences.getInstance();
    // Modified: Deduplicate and limit history while preserving order
    final uniqueHistory =
        searchHistory.reversed.toSet().toList().reversed.take(5).toList();

    List<String> historyList =
        uniqueHistory.map((entry) => json.encode(entry.toJson())).toList();
    await prefs.setStringList("search_history", historyList);
  }

  Future<List<CustomPrediction>> loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? historyList = prefs.getStringList("search_history");

    if (historyList != null) {
      return historyList
          .map((entry) => CustomPrediction.fromJson(json.decode(entry)))
          .toList();
    }
    return [];
  }

  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("search_history");
  }

  Future<List<CustomPrediction>> getCustomPredictions(String input) async {
    if (input.isEmpty) return [];
    try {
      final location = currentLocation ?? _muntinlupaCenter;

      final String url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=$input'
          '&key=$googleApiKey'
          // New: Add location biasing
          '&location=${location.latitude},${location.longitude}'
          '&radius=$_searchRadius'
          '&region=ph'
          '&components=country:ph'
          '&types=establishment|geocode';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        List<CustomPrediction> predictions = [];

        for (var prediction in data['predictions']) {
          predictions.add(CustomPrediction(
            description: prediction['description'],
            placeId: prediction['place_id'],
            // New optional fields (won't break existing code)
            mainText: prediction['structured_formatting']?['main_text'] ?? '',
            secondaryText:
                prediction['structured_formatting']?['secondary_text'] ?? '',
          ));
        }

        // Original current location insertion logic preserved
        if (currentLocation != null) {
          predictions.insert(
            1,
            CustomPrediction(
              description: "Use Current Location",
              placeId: "current_location",
              isCurrentLocation: true,
            ),
          );
        }

        return predictions;
      }
    } catch (e) {
      print("Error fetching predictions: $e");
    }
    return [];
  }

  Future<LatLng?> getPlaceDetails(String placeId) async {
    if (placeId == "current_location" && currentLocation != null) {
      return currentLocation;
    }

    try {
      final String url =
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=geometry${currentLocation != null ? ',name,formatted_address' : ''}'
          '&key=$googleApiKey';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final result = data['result'];
        double lat = result['geometry']['location']['lat'];
        double lng = result['geometry']['location']['lng'];

        // Enhanced: Save more details if available
        if (currentLocation != null) {
          final prediction = CustomPrediction(
            description: result['formatted_address'] ??
                result['name'] ??
                'Unknown Location',
            placeId: placeId,
            mainText: result['name'] ?? '',
            secondaryText: result['formatted_address'] ?? '',
          );

          final history = await loadSearchHistory();
          history.add(prediction);
          await saveSearchHistory(history);
        }

        return LatLng(lat, lng);
      }
    } catch (e) {
      print("Error fetching place details: $e");
    }
    return null;
  }

  Future<String> getAddressFromLatLngV2(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        final address = [
          place.street,
          place.subLocality,
          place.locality,
          place.country
        ].where((part) => part?.isNotEmpty ?? false).join(', ');

        // Enhanced: Save to history with location marker
        final prediction = CustomPrediction(
          description: address,
          placeId: "geo_${location.latitude}_${location.longitude}",
          isCurrentLocation: false,
          secondaryText: "Saved Location",
        );

        final history = await loadSearchHistory();
        history.add(prediction);
        await saveSearchHistory(history);

        return address;
      }
      return "Unknown Location";
    } catch (e) {
      print("Error getting address: $e");
      return "Unknown Location";
    }
  }

  // New feature: Optional nearby search (won't affect existing code)
  Future<List<CustomPrediction>> findNearbyPlaces(
      LatLng location, String type) async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=${location.latitude},${location.longitude}'
          '&radius=1000'
          '&type=$type'
          '&key=$googleApiKey';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        return (data['results'] as List).map((result) {
          return CustomPrediction(
            description: result['name'],
            placeId: result['place_id'],
            secondaryText: result['vicinity'] ?? '',
          );
        }).toList();
      }
    } catch (e) {
      print("Error finding nearby places: $e");
    }
    return [];
  }
}
