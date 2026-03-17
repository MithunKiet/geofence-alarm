class Validators {
  Validators._();

  static String? validateAlarmTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Alarm title is required';
    }
    if (value.trim().length < 2) {
      return 'Title must be at least 2 characters';
    }
    if (value.trim().length > 50) {
      return 'Title must be 50 characters or fewer';
    }
    return null;
  }

  static String? validateLocation(double? lat, double? lng) {
    if (lat == null || lng == null) {
      return 'Please select a location on the map';
    }
    if (lat < -90 || lat > 90) {
      return 'Invalid latitude value';
    }
    if (lng < -180 || lng > 180) {
      return 'Invalid longitude value';
    }
    return null;
  }

  static String? validateRadius(double? radius) {
    if (radius == null || radius <= 0) {
      return 'Please select a valid radius';
    }
    return null;
  }
}
