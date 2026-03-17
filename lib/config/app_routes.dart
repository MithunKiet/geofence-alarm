import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../screens/map/map_picker_screen.dart';
import '../screens/alarm/alarm_settings_screen.dart';
import '../screens/alarm/alarm_ring_screen.dart';
import '../models/alarm_model.dart';

class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String mapPicker = '/map-picker';
  static const String alarmSettings = '/alarm-settings';
  static const String alarmRing = '/alarm-ring';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );

      case mapPicker:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => MapPickerScreen(
            initialLatitude: args?['latitude'] as double?,
            initialLongitude: args?['longitude'] as double?,
            initialRadius: args?['radius'] as double?,
          ),
          settings: settings,
        );

      case alarmSettings:
        final alarm = settings.arguments as AlarmModel?;
        return MaterialPageRoute(
          builder: (_) => AlarmSettingsScreen(existingAlarm: alarm),
          settings: settings,
          fullscreenDialog: true,
        );

      case alarmRing:
        final alarm = settings.arguments as AlarmModel;
        return MaterialPageRoute(
          builder: (_) => AlarmRingScreen(alarm: alarm),
          settings: settings,
          fullscreenDialog: true,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
