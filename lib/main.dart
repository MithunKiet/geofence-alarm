import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import 'config/app_routes.dart';
import 'config/constants.dart';
import 'database/database_helper.dart';
import 'providers/alarm_provider.dart';
import 'services/alarm_service.dart';
import 'services/geofence_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Receive-port for messages coming from the foreground service isolate.
  FlutterForegroundTask.initCommunicationPort();
  AppGeofenceService.instance.init();
  await NotificationService.instance.initialize();
  runApp(const GeoAlarmApp());
}

class GeoAlarmApp extends StatefulWidget {
  const GeoAlarmApp({super.key});

  @override
  State<GeoAlarmApp> createState() => _GeoAlarmAppState();
}

class _GeoAlarmAppState extends State<GeoAlarmApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // Tracks which ringing alarm (by its start time) the ring screen has
  // already been shown for, so a background-triggered alarm still gets
  // surfaced when the app is reopened/resumed, without pushing duplicates.
  DateTime? _lastShownAlarmStart;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlutterForegroundTask.addTaskDataCallback(_onServiceData);
    AlarmService.instance.setAlarmTriggerCallback((alarm) {
      final startedAt = AlarmService.instance.alarmStartedAt;
      if (_lastShownAlarmStart == startedAt) return;
      _lastShownAlarmStart = startedAt;
      _navigatorKey.currentState?.pushNamed(
        AppRoutes.alarmRing,
        arguments: alarm,
      );
    });
    // If an alarm fired while the app had no UI, the service still knows
    // about it - ask for its state so the ring screen can be shown now.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AppGeofenceService.instance.queryStatus(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppGeofenceService.instance.queryStatus();
    }
  }

  /// Handles status messages from the foreground service isolate, keeping
  /// this isolate's AlarmService mirror (and therefore the ring screen) in
  /// sync with what is actually playing.
  Future<void> _onServiceData(Object data) async {
    if (data is! String) return;
    Map<String, dynamic> message;
    try {
      message = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (message['event'] != 'status') return;

    final playing = message['playing'] == true;
    final alarmId = message['alarmId'] as int?;
    final startedAtRaw = message['startedAt'] as String?;

    if (!playing || alarmId == null || startedAtRaw == null) {
      AlarmService.instance.syncStoppedFromBackground();
      return;
    }

    final alarm = await DatabaseHelper.instance.getAlarmById(alarmId);
    if (alarm == null) return;
    AlarmService.instance
        .syncTriggeredFromBackground(alarm, DateTime.parse(startedAtRaw));
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onServiceData);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AlarmProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        navigatorKey: _navigatorKey,
        initialRoute: AppRoutes.home,
        onGenerateRoute: AppRoutes.generateRoute,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
