class AppConstants {
  AppConstants._();

  static const String appName = 'GeoAlarm';
  static const String appVersion = '1.0.0';

  // Radius options in meters
  static const List<double> radiusOptions = [
    10.0,
    20.0,
    30.0,
    50.0,
    100.0,
    200.0,
    500.0,
    1000.0,
    2000.0,
    3000.0,
    4000.0,
    5000.0,
  ];
  static const double defaultRadius = 100.0;

  // Alarm behavior
  static const int snoozeDurationMinutes = 5;
  static const int autoStopSeconds = 60;

  // Database
  static const String dbName = 'geo_alarm.db';
  static const int dbVersion = 2;
  static const String tableName = 'alarms';
  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colLatitude = 'latitude';
  static const String colLongitude = 'longitude';
  static const String colRadius = 'radius';
  static const String colIsActive = 'is_active';
  static const String colCreatedAt = 'created_at';
  static const String colIsOneTime = 'is_one_time';

  // Notification channels
  static const String alarmChannelId = 'geo_alarm_channel';
  static const String alarmChannelName = 'Geofence Alarms';
  static const String alarmChannelDescription =
      'Notifications for geofence-triggered alarms';
  static const int alarmNotificationId = 1001;

  // Geofence foreground service (flutter_foreground_task)
  static const String geofenceChannelId = 'geo_fence_channel';
  static const String geofenceChannelName = 'Geofence Monitoring';
  static const String geofenceChannelDescription =
      'Persistent notification shown while GeoAlarm watches your zones';
  static const int geofenceServiceId = 256;

  // Background monitoring behavior. Monitoring is adaptive: the further the
  // user is from the nearest geofence edge, the less GPS is used.
  // - close (edge <= closeTierEdgeMeters): continuous high-accuracy stream
  // - near (edge <= farTierEdgeMeters): continuous balanced-power stream
  // - far (edge > farTierEdgeMeters): GPS off; one-shot low-power checks on
  //   a timer sized by distance / assumedMaxSpeedMps
  static const double closeTierEdgeMeters = 200;
  static const double farTierEdgeMeters = 2000;
  static const double assumedMaxSpeedMps = 28; // ~100 km/h
  static const Duration farCheckMinInterval = Duration(seconds: 30);
  static const Duration farCheckMaxInterval = Duration(minutes: 15);
  static const int closeDistanceFilterMeters = 10;
  static const int nearDistanceFilterMeters = 50;
  static const int monitorWatchdogIntervalMs = 60000;
  static const Duration positionStaleAfter = Duration(minutes: 3);
  static const Duration positionTimeout = Duration(seconds: 30);

  // Map defaults
  static const double defaultMapZoom = 15.0;
  static const double defaultLatitude = 37.7749;
  static const double defaultLongitude = -122.4194;
}
