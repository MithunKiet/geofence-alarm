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

class _GeoAlarmAppState extends State<GeoAlarmApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    AlarmService.instance.setAlarmTriggerCallback((alarm) {
      _navigatorKey.currentState?.pushNamed(
        AppRoutes.alarmRing,
        arguments: alarm,
      );
    });
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
