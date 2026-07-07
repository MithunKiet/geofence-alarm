import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  PermissionUtils._();

  static Future<bool> requestLocationPermission(BuildContext context) async {
    final status = await Permission.location.request();
    if (status.isPermanentlyDenied && context.mounted) {
      await showPermissionDeniedDialog(
        context,
        title: 'Location Permission Required',
        message:
            'GeoAlarm needs location access to trigger alarms when you enter an area. '
            'Please enable it in Settings.',
      );
      return false;
    }
    return status.isGranted;
  }

  static Future<bool> requestBackgroundLocationPermission(
      BuildContext context) async {
    final status = await Permission.locationAlways.request();
    if (!status.isGranted && context.mounted) {
      await showPermissionDeniedDialog(
        context,
        title: 'Background Location Required',
        message:
            'GeoAlarm needs "Allow all the time" location access to monitor geofences '
            'when the app is in the background. Please update this in Settings.',
      );
      return false;
    }
    return status.isGranted;
  }

  static Future<bool> requestNotificationPermission(
      BuildContext context) async {
    final status = await Permission.notification.request();
    if (!status.isGranted && context.mounted) {
      await showPermissionDeniedDialog(
        context,
        title: 'Notification Permission Required',
        message:
            'GeoAlarm needs notification access to alert you when you enter a zone.',
      );
      return false;
    }
    return status.isGranted;
  }

  /// Asks the OS to stop battery-optimizing this app. Without this, many
  /// Android OEMs (Xiaomi, Samsung, OnePlus, Oppo, ...) kill the geofence
  /// monitoring service soon after the app is backgrounded or closed, so the
  /// alarm never fires.
  static Future<bool> requestIgnoreBatteryOptimizations(
      BuildContext context) async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (!status.isGranted && context.mounted) {
      await showPermissionDeniedDialog(
        context,
        title: 'Disable Battery Optimization',
        message:
            'To keep monitoring geofences after GeoAlarm is closed, please disable '
            'battery optimization for this app in Settings.',
      );
      return false;
    }
    return status.isGranted;
  }

  static Future<void> showPermissionDeniedDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
