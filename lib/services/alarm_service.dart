import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../config/constants.dart';
import '../models/alarm_model.dart';
import 'notification_service.dart';

typedef AlarmTriggerCallback = void Function(AlarmModel alarm);

class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  Timer? _autoStopTimer;
  Timer? _snoozeTimer;
  bool _isAlarmPlaying = false;
  AlarmModel? _currentAlarm;
  DateTime? _alarmStartedAt;
  AlarmTriggerCallback? _onAlarmTriggered;
  VoidCallback? _onAlarmStopped;

  bool get isAlarmPlaying => _isAlarmPlaying;
  AlarmModel? get currentAlarm => _currentAlarm;

  /// When the currently-playing alarm actually started ringing. UI (the ring
  /// screen) derives its countdown from this instead of running its own
  /// independent timer, so the two can never drift out of sync.
  DateTime? get alarmStartedAt => _alarmStartedAt;

  void setAlarmTriggerCallback(AlarmTriggerCallback callback) {
    _onAlarmTriggered = callback;
  }

  /// Fired at the end of every stopAlarm() - manual stop, auto-stop timeout,
  /// or the stop() half of a snooze cycle - regardless of what triggered it.
  /// The foreground-service isolate uses this single hook to both notify the
  /// UI isolate and decide whether it can shut itself down, instead of
  /// duplicating that logic at every call site that can end an alarm.
  void setOnAlarmStoppedCallback(VoidCallback? callback) {
    _onAlarmStopped = callback;
  }

  Future<void> startAlarm(AlarmModel alarm) async {
    if (_isAlarmPlaying) {
      if (_currentAlarm?.id == alarm.id) return;
      // A different geofence fired while an alarm was already ringing -
      // switch over instead of silently dropping the new trigger.
      await stopAlarm();
    }

    _isAlarmPlaying = true;
    _currentAlarm = alarm;
    _alarmStartedAt = DateTime.now();

    try {
      // Play the system's default alarm sound
      await FlutterRingtonePlayer().playAlarm(
        looping: true,
        asAlarm: true,
        volume: 1.0,
      );
    } catch (e) {
      debugPrint('[AlarmService] Ringtone playback error: $e');
    }

    await NotificationService.instance.showAlarmNotification(alarm);

    _autoStopTimer = Timer(
      const Duration(seconds: AppConstants.autoStopSeconds),
      stopAlarm,
    );

    _onAlarmTriggered?.call(alarm);
  }

  Future<void> stopAlarm() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    try {
      await FlutterRingtonePlayer().stop();
    } catch (e) {
      debugPrint('[AlarmService] Error stopping ringtone: $e');
    }

    if (_currentAlarm != null) {
      await NotificationService.instance.cancelNotification(
        _currentAlarm!.id ?? AppConstants.alarmNotificationId,
      );
    }

    _isAlarmPlaying = false;
    _currentAlarm = null;
    _alarmStartedAt = null;
    _onAlarmStopped?.call();
  }

  Future<void> snoozeAlarm(AlarmModel alarm) async {
    await stopAlarm();
    _snoozeTimer = Timer(
      const Duration(minutes: AppConstants.snoozeDurationMinutes),
      () => startAlarm(alarm),
    );
  }

  /// Mirrors, into this (UI) isolate, an alarm that is actually playing in
  /// the foreground-service isolate. No sound is started here - this only
  /// updates state so the ring screen can show and count down correctly,
  /// and fires the navigation callback.
  void syncTriggeredFromBackground(AlarmModel alarm, DateTime startedAt) {
    if (_alarmStartedAt == startedAt) return;
    _isAlarmPlaying = true;
    _currentAlarm = alarm;
    _alarmStartedAt = startedAt;
    _onAlarmTriggered?.call(alarm);
  }

  /// Clears the mirrored state when the foreground-service isolate reports
  /// the alarm has stopped (user action there, auto-stop, or snooze).
  void syncStoppedFromBackground() {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _isAlarmPlaying = false;
    _currentAlarm = null;
    _alarmStartedAt = null;
  }

  Future<void> dispose() async {
    _snoozeTimer?.cancel();
    _snoozeTimer = null;
    await stopAlarm();
  }
}
