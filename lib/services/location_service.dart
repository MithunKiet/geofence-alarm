import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  Future<bool> isGpsEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled = await isGpsEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return false;
    }
    return true;
  }

  Future<bool> requestBackgroundPermission() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  Future<Position?> getCurrentLocation() async {
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    );
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
