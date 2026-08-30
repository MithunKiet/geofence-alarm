import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/notification_service.dart';

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

  /// Do Not Disturb access has no runtime permission dialog on Android -
  /// it's a manual toggle in system Settings - so this shows a rationale
  /// dialog first, then opens that settings screen if the user agrees.
  /// The alarm sound itself already plays on the alarm audio stream
  /// (bypassing Silent/Vibrate mode regardless), so declining this only
  /// means the notification/UI can still be suppressed by DND, not silence
  /// the alarm sound.
  ///
  /// Checks whether access is already granted first - without this check,
  /// the rationale dialog would reappear on every single app launch even
  /// after the user already granted it, since (unlike the other permissions
  /// above) there's no OS-level "already granted" short-circuit for a
  /// manual Settings toggle. That check never throws - NotificationService
  /// swallows its own platform-channel errors and reports "not granted" -
  /// so a flaky check here can't abort the caller's startup permission chain.
  static Future<void> requestDndBypassAccess(BuildContext context) async {
    if (await NotificationService.instance.hasDndBypassAccess()) return;
    if (!context.mounted) return;

    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ring Through Do Not Disturb'),
        content: const Text(
          'Grant Do Not Disturb access so your alarm notification and '
          'full-screen alert still show up even when your phone is in DND '
          'mode. The alarm sound already plays regardless - this only '
          'covers the visual alert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Grant Access'),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      await NotificationService.instance.requestDndBypassAccess();
    }
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
