import 'dart:math';

class DistanceUtils {
  DistanceUtils._();

  static const double _earthRadiusMeters = 6371000.0;

  /// Calculates the distance in meters between two geographic coordinates
  /// using the Haversine formula.
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) => degrees * (pi / 180.0);

  /// Returns true if the point (lat2, lon2) is within [radiusMeters] of (lat1, lon1).
  static bool isWithinRadius(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    double radiusMeters,
  ) {
    return calculateDistance(lat1, lon1, lat2, lon2) <= radiusMeters;
  }

  /// Returns a human-readable string for the given radius in meters.
  static String formatRadius(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000.0;
      final rounded = km.roundToDouble();
      return '${rounded == km ? km.toInt() : km.toStringAsFixed(1)} km';
    }
    return '${meters.toInt()} m';
  }

  /// Returns a human-readable distance string.
  static String formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000.0).toStringAsFixed(1)} km';
    }
    return '${meters.toInt()} m';
  }
}
