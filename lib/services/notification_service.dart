import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/constants.dart';
import '../models/alarm_model.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('[NotificationService] Tapped notification id: ${response.id}');
  }

  Future<void> showAlarmNotification(AlarmModel alarm) async {
    const androidDetails = AndroidNotificationDetails(
      AppConstants.alarmChannelId,
      AppConstants.alarmChannelName,
      channelDescription: AppConstants.alarmChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: false,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      // Tags this channel as alarm audio and asks the system to let it
      // through Do Not Disturb. channelBypassDnd only takes effect if the
      // user has granted notification-policy access (see
      // requestDndBypassAccess below) - without it, Android silently
      // treats this as false rather than failing.
      audioAttributesUsage: AudioAttributesUsage.alarm,
      channelBypassDnd: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: alarm.id ?? AppConstants.alarmNotificationId,
      title: '🔔 ${AppConstants.appName}',
      body: 'You have entered the zone: ${alarm.title}',
      notificationDetails: notificationDetails,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  Future<bool> requestPermission() async {
    final android = _android;
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Whether Do Not Disturb access is already granted. Callers should check
  /// this before showing any rationale/request UI, so a user who already
  /// granted access isn't asked again on every app open.
  ///
  /// Swallows platform-channel errors (e.g. an OEM build where the method
  /// channel isn't fully attached yet) and reports "not granted" instead of
  /// throwing, so a flaky check here can't abort the caller's whole startup
  /// permission chain.
  Future<bool> hasDndBypassAccess() async {
    final android = _android;
    if (android == null) return true;
    try {
      final granted = await android.hasNotificationPolicyAccess();
      return granted ?? false;
    } catch (e) {
      debugPrint('[NotificationService] hasDndBypassAccess failed: $e');
      return false;
    }
  }

  /// Opens the system "Do Not Disturb access" settings screen so the user
  /// can whitelist GeoAlarm. There is no runtime permission dialog for this
  /// on Android - it's a manual settings toggle - so this should only be
  /// called after explaining why to the user (see PermissionUtils). Without
  /// it, channelBypassDnd on the alarm channel is silently ignored and the
  /// alarm notification (though not the alarm sound itself, which already
  /// plays on the alarm audio stream regardless) can be suppressed by DND.
  ///
  /// Swallows platform-channel errors and reports failure instead of
  /// throwing, for the same reason as hasDndBypassAccess above.
  Future<bool> requestDndBypassAccess() async {
    final android = _android;
    if (android == null) return true;
    try {
      final granted = await android.requestNotificationPolicyAccess();
      return granted ?? false;
    } catch (e) {
      debugPrint('[NotificationService] requestDndBypassAccess failed: $e');
      return false;
    }
  }
}
