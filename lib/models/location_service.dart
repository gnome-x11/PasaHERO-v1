//models

import 'package:geolocator/geolocator.dart';

class LocationService {
  Stream<Position> get positionStream => Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          //distanceFilter: 3, //3 meters per update
        ),
      );

  Future<Position> getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
