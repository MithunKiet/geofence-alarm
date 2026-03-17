import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/alarm_model.dart';
import '../database/database_helper.dart';
import 'notification_service.dart';

typedef AlarmTriggerCallback = void Function(AlarmModel alarm);

class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _autoStopTimer;
  Timer? _snoozeTimer;
  bool _isAlarmPlaying = false;
  AlarmModel? _currentAlarm;
  AlarmTriggerCallback? _onAlarmTriggered;

  bool get isAlarmPlaying => _isAlarmPlaying;
  AlarmModel? get currentAlarm => _currentAlarm;

  void setAlarmTriggerCallback(AlarmTriggerCallback callback) {
    _onAlarmTriggered = callback;
  }

  /// Called by the geofence service when a geofence boundary is crossed.
  /// Looks up the alarm from the database and starts it.
  Future<void> triggerFromGeofence(int alarmId) async {
    // Avoid duplicate trigger if alarm is already playing for same alarm
    if (_isAlarmPlaying && _currentAlarm?.id == alarmId) return;

    try {
      final alarm = await DatabaseHelper.instance.getAlarmById(alarmId);
      if (alarm != null && alarm.isActive) {
        await startAlarm(alarm);
      }
    } catch (e) {
      debugPrint('[AlarmService] Error fetching alarm $alarmId: $e');
    }
  }

  Future<void> startAlarm(AlarmModel alarm) async {
    if (_isAlarmPlaying) return;

    _isAlarmPlaying = true;
    _currentAlarm = alarm;

    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource(AppConstants.alarmSoundAsset));
    } catch (e) {
      // Audio file may not exist in development; log and continue so the
      // notification and screen navigation still work.
      debugPrint('[AlarmService] Audio playback error (asset missing?): $e');
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
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('[AlarmService] Error stopping audio: $e');
    }

    if (_currentAlarm != null) {
      await NotificationService.instance.cancelNotification(
        _currentAlarm!.id ?? AppConstants.alarmNotificationId,
      );
    }

    _isAlarmPlaying = false;
    _currentAlarm = null;
  }

  Future<void> snoozeAlarm(AlarmModel alarm) async {
    await stopAlarm();
    _snoozeTimer = Timer(
      const Duration(minutes: AppConstants.snoozeDurationMinutes),
      () => startAlarm(alarm),
    );
  }

  Future<void> dispose() async {
    _snoozeTimer?.cancel();
    _snoozeTimer = null;
    await stopAlarm();
    await _audioPlayer.dispose();
  }
}
