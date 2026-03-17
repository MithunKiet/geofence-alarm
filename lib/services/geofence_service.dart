import 'package:flutter/material.dart';
import 'package:geofence_service/geofence_service.dart' as gf;
import '../models/alarm_model.dart';
import 'alarm_service.dart';

class AppGeofenceService {
  AppGeofenceService._();
  static final AppGeofenceService instance = AppGeofenceService._();

  final gf.GeofenceService _geofenceService = gf.GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    loiteringDelayMs: 60000,
    statusChangeDelayMs: 10000,
    useActivityRecognition: false,
    allowMockLocations: false,
    printDevLog: false,
    geofenceRadiusSortType: gf.GeofenceRadiusSortType.DESC,
  );

  bool _isRunning = false;

  bool get isRunning => _isRunning;

  void _onGeofenceStatusChanged(
    gf.Geofence geofence,
    gf.GeofenceRadius geofenceRadius,
    gf.GeofenceStatus geofenceStatus,
    gf.Location location,
  ) {
    if (geofenceStatus == gf.GeofenceStatus.ENTER) {
      final alarmId = int.tryParse(geofence.id);
      if (alarmId != null) {
        AlarmService.instance.triggerFromGeofence(alarmId);
      }
    }
  }

  void _onError(dynamic error) {
    debugPrint('[GeofenceService] Error: $error');
  }

  Future<void> startMonitoring(List<AlarmModel> activeAlarms) async {
    if (_isRunning) await stopMonitoring();

    final geofences = activeAlarms
        .map(
          (alarm) => gf.Geofence(
            id: alarm.id.toString(),
            latitude: alarm.latitude,
            longitude: alarm.longitude,
            radius: [
              gf.GeofenceRadius(
                id: 'radius_${alarm.id}',
                length: alarm.radius,
              ),
            ],
          ),
        )
        .toList();

    if (geofences.isEmpty) return;

    _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);

    try {
      await _geofenceService.start(geofences);
      _isRunning = true;
    } catch (e) {
      _onError(e);
      _geofenceService.removeGeofenceStatusChangeListener(
          _onGeofenceStatusChanged);
    }
  }

  Future<void> stopMonitoring() async {
    if (!_isRunning) return;
    _geofenceService
        .removeGeofenceStatusChangeListener(_onGeofenceStatusChanged);
    try {
      await _geofenceService.stop();
    } catch (e) {
      debugPrint('[GeofenceService] Stop error: $e');
    }
    _isRunning = false;
  }

  Future<void> refreshMonitoring(List<AlarmModel> activeAlarms) async {
    await stopMonitoring();
    if (activeAlarms.isNotEmpty) {
      await startMonitoring(activeAlarms);
    }
  }
}
