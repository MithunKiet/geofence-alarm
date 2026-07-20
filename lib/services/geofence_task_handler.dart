import 'dart:async';
import 'dart:convert';
import 'dart:math';

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

/// How aggressively we sample location, based on distance to the nearest
/// geofence edge. Far from every fence, GPS stays off entirely and we only
/// take an occasional low-power fix - the main battery saver.
enum _MonitorTier { close, near, far }

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

  _MonitorTier? _tier;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _farCheckTimer;
  DateTime? _lastPositionAt;
  DateTime? _lastNotificationUpdateAt;
  Timer? _snoozeTimer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await NotificationService.instance.initialize();
    AlarmService.instance.setOnAlarmStoppedCallback(_onAlarmStopped);
    await _reloadAlarms();
    await _checkNow();
  }

  /// Runs whenever AlarmService.stopAlarm() completes in this isolate, for
  /// any reason (Stop pressed, 60s auto-stop timeout, or the stop() half of
  /// a snooze cycle). Centralizing this here - rather than duplicating it at
  /// every call site that can end an alarm - is what makes the auto-stop
  /// timeout path also notify the UI and consider self-stopping the service,
  /// which a naive per-call-site version would silently miss.
  void _onAlarmStopped() {
    _sendStatusToMain();
    _stopServiceIfIdle();
  }

  /// Watchdog only: normal operation is driven by the position stream or
  /// the far-tier timer. If neither has produced/scheduled anything for a
  /// while (provider hiccup, doze), take a fresh fix and re-plan.
  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_activeAlarms.isEmpty) return;
    if (_tier == _MonitorTier.far && _farCheckTimer != null) return;
    final last = _lastPositionAt;
    if (last == null ||
        DateTime.now().difference(last) > AppConstants.positionStaleAfter) {
      _checkNow();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _farCheckTimer?.cancel();
    _farCheckTimer = null;
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
        _reloadAlarmsAndReplan();
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

  Future<void> _reloadAlarmsAndReplan() async {
    await _reloadAlarms();
    // Fence set changed, so the sampling tier may no longer be right
    // (e.g. a new alarm was added right next to the user).
    await _checkNow();
  }

  /// Takes a single low-power fix, runs the geofence checks with it, and
  /// re-plans the sampling tier from scratch. Used at startup, on far-tier
  /// timer ticks, after alarm-list changes, and by the watchdog. Clearing
  /// _tier forces _applyTierFor to rebuild the stream, so a silently-dead
  /// stream can't survive a watchdog pass.
  Future<void> _checkNow() async {
    _cancelAllSampling();
    _tier = null;
    // Force the next position fix to refresh the notification immediately
    // rather than waiting out the throttle window with possibly-stale text
    // (e.g. after the alarm list changed).
    _lastNotificationUpdateAt = null;
    if (_activeAlarms.isEmpty) return;

    try {
      // High accuracy even for the occasional far-tier fix: a coarse
      // (~100m error) fix taken near a fence edge could false-trigger an
      // ENTER, and one precise fix every few minutes is still cheap.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: AppConstants.positionTimeout,
        ),
      );
      _onPosition(position);
    } catch (e) {
      debugPrint('[GeofenceTask] One-shot fix failed: $e');
      // Don't stall monitoring on a failed fix - try again shortly.
      _farCheckTimer = Timer(AppConstants.farCheckMinInterval, _checkNow);
    }
  }

  void _onPosition(Position position) {
    _lastPositionAt = DateTime.now();
    if (_activeAlarms.isEmpty) {
      _cancelAllSampling();
      return;
    }

    double nearestEdgeMeters = double.infinity;
    AlarmModel? nearestAlarm;

    for (final alarm in _activeAlarms) {
      final id = alarm.id;
      if (id == null) continue;

      final distance = DistanceUtils.calculateDistance(
        alarm.latitude,
        alarm.longitude,
        position.latitude,
        position.longitude,
      );
      final edge = distance - alarm.radius;
      if (edge < nearestEdgeMeters) {
        nearestEdgeMeters = edge;
        nearestAlarm = alarm;
      }

      final inside = distance <= alarm.radius;
      if (inside && !_insideAlarmIds.contains(id)) {
        _insideAlarmIds.add(id);
        _triggerAlarm(alarm);
      } else if (!inside) {
        _insideAlarmIds.remove(id);
      }
    }

    _applyTierFor(nearestEdgeMeters);
    _updateLiveDistanceNotification(nearestAlarm, nearestEdgeMeters);
  }

  /// Keeps the persistent foreground notification showing live distance to
  /// the nearest active zone (e.g. "Home - 3.2 km away") instead of a
  /// static "Watching N zones", so the user can glance at it while
  /// traveling without opening the app. Throttled since the close tier's
  /// position stream can fire much faster than this needs to update, and
  /// skipped while an alarm is actively ringing so it doesn't compete with
  /// that notification's own message.
  void _updateLiveDistanceNotification(AlarmModel? alarm, double edgeMeters) {
    if (alarm == null || AlarmService.instance.isAlarmPlaying) return;

    final now = DateTime.now();
    final last = _lastNotificationUpdateAt;
    if (last != null &&
        now.difference(last) < AppConstants.liveNotificationUpdateInterval) {
      return;
    }
    _lastNotificationUpdateAt = now;

    final text = edgeMeters <= 0
        ? '${alarm.title} - you are in the zone'
        : '${alarm.title} - ${DistanceUtils.formatDistance(edgeMeters)} away';

    FlutterForegroundTask.updateService(notificationText: text);
  }

  /// Picks the sampling strategy for the current distance to the nearest
  /// fence edge and switches to it if it differs from the active one. The
  /// far tier is re-armed on every position because its interval depends
  /// on the (changing) distance.
  void _applyTierFor(double nearestEdgeMeters) {
    final _MonitorTier tier;
    if (nearestEdgeMeters <= AppConstants.closeTierEdgeMeters) {
      tier = _MonitorTier.close;
    } else if (nearestEdgeMeters <= AppConstants.farTierEdgeMeters) {
      tier = _MonitorTier.near;
    } else {
      tier = _MonitorTier.far;
    }

    if (tier == _MonitorTier.far) {
      _cancelAllSampling();
      _tier = tier;
      // Even at ~100 km/h the user cannot reach the fence before the next
      // check; when they are hundreds of km away this sleeps for the full
      // 15-minute cap with the GPS completely off.
      final seconds =
          (nearestEdgeMeters / AppConstants.assumedMaxSpeedMps).round();
      final interval = Duration(
        seconds: seconds
            .clamp(
              AppConstants.farCheckMinInterval.inSeconds,
              AppConstants.farCheckMaxInterval.inSeconds,
            )
            .toInt(),
      );
      _farCheckTimer = Timer(interval, _checkNow);
      return;
    }

    if (tier == _tier) return;
    _cancelAllSampling();
    _tier = tier;

    final close = tier == _MonitorTier.close;
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: close ? LocationAccuracy.high : LocationAccuracy.medium,
        distanceFilter: close
            ? AppConstants.closeDistanceFilterMeters
            : AppConstants.nearDistanceFilterMeters,
      ),
    ).listen(_onPosition, onError: (Object e) {
      debugPrint('[GeofenceTask] Position stream error: $e');
    });
  }

  void _cancelAllSampling() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _farCheckTimer?.cancel();
    _farCheckTimer = null;
  }

  Future<void> _triggerAlarm(AlarmModel alarm) async {
    await AlarmService.instance.startAlarm(alarm);
    _sendStatusToMain();

    if (alarm.isOneTime) {
      await _deactivateOneTimeAlarm(alarm);
    }
  }

  /// A one-time alarm has done its job the moment it rings: turn it off in
  /// the database and drop it from the in-memory monitoring set so it can't
  /// fire again on a later ENTER. This does NOT stop the service itself -
  /// the alarm may still be ringing or about to be snoozed, both of which
  /// need this isolate alive; _stopServiceIfIdle() (called once the alarm
  /// actually stops) is what decides whether the service can shut down.
  Future<void> _deactivateOneTimeAlarm(AlarmModel alarm) async {
    final id = alarm.id;
    try {
      await DatabaseHelper.instance
          .updateAlarm(alarm.copyWith(isActive: false));
    } catch (e) {
      debugPrint('[GeofenceTask] Failed to deactivate one-time alarm: $e');
    }
    if (id != null) {
      _activeAlarms = _activeAlarms.where((a) => a.id != id).toList();
      _insideAlarmIds.remove(id);
    }
    FlutterForegroundTask.sendDataToMain(
      jsonEncode({'event': 'alarmDeactivated', 'alarmId': id}),
    );
  }

  Future<void> _stopAndNotifyMain() async {
    // AlarmService's onAlarmStopped callback (_onAlarmStopped) handles both
    // notifying the UI and the self-stop check once this completes.
    await AlarmService.instance.stopAlarm();
  }

  Future<void> _snoozeCurrentAlarm() async {
    final alarm = AlarmService.instance.currentAlarm;
    if (alarm == null) return;

    // Arm the snooze timer *before* stopping. stopAlarm() synchronously
    // triggers _onAlarmStopped -> _stopServiceIfIdle(), which checks for a
    // pending snooze timer; arming it first means that check sees it and
    // doesn't tear the service down out from under the pending snooze.
    _snoozeTimer?.cancel();
    _snoozeTimer = Timer(
      const Duration(minutes: AppConstants.snoozeDurationMinutes),
      () => _triggerAlarm(alarm),
    );

    // The snooze timer lives in this isolate, so unlike the pre-refactor
    // implementation it keeps counting down after the app is closed.
    await AlarmService.instance.stopAlarm();
  }

  /// Stops the foreground service once there is nothing left for it to do:
  /// no active alarms to monitor and no snooze timer waiting to re-ring one.
  /// Safe to call redundantly (e.g. also reachable from onDestroy's own
  /// teardown path) - it no-ops if the service isn't running.
  Future<void> _stopServiceIfIdle() async {
    final snoozePending = _snoozeTimer?.isActive ?? false;
    if (_activeAlarms.isNotEmpty || snoozePending) return;
    if (!await FlutterForegroundTask.isRunningService) return;

    _cancelAllSampling();
    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('[GeofenceTask] Failed to self-stop idle service: $e');
    }
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
