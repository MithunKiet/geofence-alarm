import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/constants.dart';
import '../models/alarm_model.dart';
import 'geofence_task_handler.dart';

/// UI-isolate facade for the geofence foreground service.
///
/// The actual monitoring runs in [GeofenceTaskHandler] inside the service's
/// own isolate, so it keeps working when the app UI is backgrounded or
/// removed from recents. This class only starts/stops that service and
/// relays commands to it.
class AppGeofenceService {
  AppGeofenceService._();
  static final AppGeofenceService instance = AppGeofenceService._();

  /// One-time configuration of the foreground service. Safe to call before
  /// runApp; it registers no platform channels beyond the plugin's own.
  void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: AppConstants.geofenceChannelId,
        channelName: AppConstants.geofenceChannelName,
        channelDescription: AppConstants.geofenceChannelDescription,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // The position stream drives monitoring; this repeat event is only
        // a watchdog that revives the stream if it stalls.
        eventAction: ForegroundTaskEventAction.repeat(
          AppConstants.monitorWatchdogIntervalMs,
        ),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// Starts monitoring (or refreshes the alarm list of an already-running
  /// service) for the given active alarms; stops the service when there is
  /// nothing left to monitor.
  Future<void> refreshMonitoring(List<AlarmModel> activeAlarms) async {
    try {
      if (activeAlarms.isEmpty) {
        if (await isRunning) {
          await FlutterForegroundTask.stopService();
        }
        return;
      }

      if (await isRunning) {
        await sendCommand({'command': 'reloadAlarms'});
        return;
      }

      // Starting a location-type foreground service without the location
      // permission throws on Android 14+; skip and let the permission flow
      // on the Home screen bring us back here.
      if (!await Permission.location.isGranted) {
        debugPrint(
            '[AppGeofenceService] Location permission missing; not starting');
        return;
      }

      await FlutterForegroundTask.startService(
        serviceTypes: [ForegroundServiceTypes.location],
        serviceId: AppConstants.geofenceServiceId,
        notificationTitle: AppConstants.appName,
        notificationText:
            'Watching ${activeAlarms.length} zone${activeAlarms.length == 1 ? '' : 's'}',
        callback: startGeofenceTask,
      );
    } catch (e) {
      debugPrint('[AppGeofenceService] Failed to (re)start monitoring: $e');
    }
  }

  Future<void> stopMonitoring() async {
    try {
      if (await isRunning) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('[AppGeofenceService] Stop error: $e');
    }
  }

  /// Sends a JSON command to the service isolate. Returns false when the
  /// service isn't running (caller may then handle the action locally).
  Future<bool> sendCommand(Map<String, dynamic> command) async {
    if (!await isRunning) return false;
    FlutterForegroundTask.sendDataToTask(jsonEncode(command));
    return true;
  }

  Future<bool> stopBackgroundAlarm() =>
      sendCommand({'command': 'stopAlarm'});

  Future<bool> snoozeBackgroundAlarm() =>
      sendCommand({'command': 'snoozeAlarm'});

  /// Asks the service for its current alarm state; the reply arrives via
  /// FlutterForegroundTask.addTaskDataCallback in the UI isolate.
  Future<void> queryStatus() => sendCommand({'command': 'queryStatus'});
}
