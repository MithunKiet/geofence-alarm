import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/alarm_provider.dart';
import '../../widgets/alarm_card.dart';
import '../../config/app_routes.dart';
import '../../services/geofence_service.dart' as app_geo;
import '../../utils/permission_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await _requestPermissions();
    if (!mounted) return;
    await context.read<AlarmProvider>().loadAlarms();
    await _refreshGeofences();
  }

  Future<void> _requestPermissions() async {
    if (!mounted) return;
    await PermissionUtils.requestLocationPermission(context);
    if (!mounted) return;
    await PermissionUtils.requestBackgroundLocationPermission(context);
    if (!mounted) return;
    await PermissionUtils.requestNotificationPermission(context);
    if (!mounted) return;
    await PermissionUtils.requestIgnoreBatteryOptimizations(context);
  }

  Future<void> _refreshGeofences() async {
    if (!mounted) return;
    final activeAlarms = context.read<AlarmProvider>().activeAlarms;
    await app_geo.AppGeofenceService.instance.refreshMonitoring(activeAlarms);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshGeofences();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoAlarm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              await context.read<AlarmProvider>().loadAlarms();
              await _refreshGeofences();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alarms refreshed')),
                );
              }
            },
          ),
        ],
      ),
      body: Consumer<AlarmProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      provider.clearError();
                      provider.loadAlarms();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.alarms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Alarms Yet',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to create a geofence alarm',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadAlarms();
              await _refreshGeofences();
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.alarms.length,
              itemBuilder: (context, index) {
                return AlarmCard(alarm: provider.alarms[index]);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).pushNamed(AppRoutes.alarmSettings);
          await _refreshGeofences();
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('New Alarm'),
      ),
    );
  }
}
