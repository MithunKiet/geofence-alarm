import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../config/constants.dart';
import '../database/database_helper.dart';
import '../models/alarm_model.dart';
import '../utils/distance_utils.dart';
import 'alarm_service.dart';
import 'notification_service.dart';

/// Entry point for the foreground service isolate. Must be a top-level
/// function annotated with vm:entry-point so it survives tree-shaking and
/// can be invoked by the Android service after the UI is gone.
@pragma('vm:entry-point')
void startGeofenceTask() {
  FlutterForegroundTask.setTaskHandler(GeofenceTaskHandler());
}

/// Runs geofence monitoring inside the foreground service's own isolate.
///
/// This is what makes alarms work after the app is backgrounded or removed
/// from recents: the service isolate is owned by the Android Service (not
/// the Activity), so it keeps running when the UI engine is destroyed. All
/// triggering (sound + notification) happens here; the UI isolate, when
/// alive, is only informed so it can show the ring screen.
class GeofenceTaskHandler extends TaskHandler {
  List<AlarmModel> _activeAlarms = [];

  /// Alarms whose geofence we are currently inside. An alarm only fires on
  /// the outside -> inside transition (ENTER), and re-arms once we exit.
  final Set<int> _insideAlarmIds = {};

  StreamSubscription<Position>? _positionSubscription;
  DateTime? _lastPositionAt;
  Timer? _snoozeTimer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await NotificationService.instance.initialize();
    await _reloadAlarms();
    _subscribeToPosition();
  }

  /// Watchdog only: real work is driven by the position stream. If the
  /// stream has gone quiet (provider hiccup, doze), resubscribe.
  @override
  void onRepeatEvent(DateTime timestamp) {
    final last = _lastPositionAt;
    if (last == null ||
        DateTime.now().difference(last) > AppConstants.positionStaleAfter) {
      _subscribeToPosition();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _snoozeTimer?.cancel();
    _snoozeTimer = null;
    await AlarmService.instance.dispose();
  }

  @override
  void onReceiveData(Object data) {
    if (data is! String) return;
    Map<String, dynamic> message;
    try {
      message = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (message['command']) {
      case 'reloadAlarms':
        _reloadAlarms();
      case 'stopAlarm':
        _snoozeTimer?.cancel();
        _stopAndNotifyMain();
      case 'snoozeAlarm':
        _snoozeCurrentAlarm();
      case 'queryStatus':
        _sendStatusToMain();
    }
  }

  Future<void> _reloadAlarms() async {
    try {
      final alarms = await DatabaseHelper.instance.getAllAlarms();
      _activeAlarms = alarms.where((a) => a.isActive).toList();
      _insideAlarmIds
          .removeWhere((id) => !_activeAlarms.any((a) => a.id == id));
    } catch (e) {
      debugPrint('[GeofenceTask] Failed to load alarms: $e');
    }
  }

  void _subscribeToPosition() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: AppConstants.monitorDistanceFilterMeters,
      ),
    ).listen(_onPosition, onError: (Object e) {
      debugPrint('[GeofenceTask] Position stream error: $e');
    });
  }

  void _onPosition(Position position) {
    _lastPositionAt = DateTime.now();

    for (final alarm in _activeAlarms) {
      final id = alarm.id;
      if (id == null) continue;

      final inside = DistanceUtils.isWithinRadius(
        alarm.latitude,
        alarm.longitude,
        position.latitude,
        position.longitude,
        alarm.radius,
      );

      if (inside && !_insideAlarmIds.contains(id)) {
        _insideAlarmIds.add(id);
        _triggerAlarm(alarm);
      } else if (!inside) {
        _insideAlarmIds.remove(id);
      }
    }
  }

  Future<void> _triggerAlarm(AlarmModel alarm) async {
    await AlarmService.instance.startAlarm(alarm);
    _sendStatusToMain();
  }

  Future<void> _stopAndNotifyMain() async {
    await AlarmService.instance.stopAlarm();
    _sendStatusToMain();
  }

  Future<void> _snoozeCurrentAlarm() async {
    final alarm = AlarmService.instance.currentAlarm;
    if (alarm == null) return;

    await AlarmService.instance.stopAlarm();
    _sendStatusToMain();

    // The snooze timer lives in this isolate, so unlike the pre-refactor
    // implementation it keeps counting down after the app is closed.
    _snoozeTimer?.cancel();
    _snoozeTimer = Timer(
      const Duration(minutes: AppConstants.snoozeDurationMinutes),
      () => _triggerAlarm(alarm),
    );
  }

  /// Pushes the current playing state to the UI isolate (a no-op if the UI
  /// isn't running). The UI also requests this on startup/resume, which
  /// covers the case where the alarm fired while the app had no UI at all.
  void _sendStatusToMain() {
    final alarm = AlarmService.instance.currentAlarm;
    final startedAt = AlarmService.instance.alarmStartedAt;
    FlutterForegroundTask.sendDataToMain(jsonEncode({
      'event': 'status',
      'playing': AlarmService.instance.isAlarmPlaying,
      'alarmId': alarm?.id,
      'startedAt': startedAt?.toIso8601String(),
    }));
  }
}
