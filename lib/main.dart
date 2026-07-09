import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_routes.dart';
import 'providers/alarm_provider.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'theme/app_theme.dart';
import 'config/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    AlarmService.instance.setAlarmTriggerCallback((alarm) {
      _lastShownAlarmStart = AlarmService.instance.alarmStartedAt;
      _navigatorKey.currentState?.pushNamed(
        AppRoutes.alarmRing,
        arguments: alarm,
      );
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _showRingScreenIfAlarmActive());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _showRingScreenIfAlarmActive();
    }
  }

  /// If an alarm is already ringing (e.g. it was triggered by the geofence
  /// service while the app had no UI on screen) and this screen hasn't been
  /// shown for it yet, surface the ring screen now.
  void _showRingScreenIfAlarmActive() {
    final alarm = AlarmService.instance.currentAlarm;
    final startedAt = AlarmService.instance.alarmStartedAt;
    if (alarm == null || startedAt == null) return;
    if (_lastShownAlarmStart == startedAt) return;
    _lastShownAlarmStart = startedAt;
    _navigatorKey.currentState?.pushNamed(AppRoutes.alarmRing, arguments: alarm);
  }

  @override
  void dispose() {
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
        navigatorKey: _navigatorKey,
        initialRoute: AppRoutes.home,
        onGenerateRoute: AppRoutes.generateRoute,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
