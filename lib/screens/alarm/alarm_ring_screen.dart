import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/alarm_model.dart';
import '../../services/alarm_service.dart';
import '../../services/geofence_service.dart';
import '../../config/constants.dart';

class AlarmRingScreen extends StatefulWidget {
  final AlarmModel alarm;

  const AlarmRingScreen({super.key, required this.alarm});

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with SingleTickerProviderStateMixin {
  static const Color _backgroundColor = Color(0xFF1A237E);
  static const Color _alertColor = Color(0xFFFF5252);

  late int _remainingSeconds;
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _alertColorAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _alertColorAnimation = ColorTween(
      begin: _alertColor.withAlpha(153),
      end: _alertColor,
    ).animate(_pulseController);

    // Only start the alarm if it is not already playing (e.g., when the ring
    // screen is navigated to manually rather than via the geofence callback).
    if (!AlarmService.instance.isAlarmPlaying) {
      AlarmService.instance.startAlarm(widget.alarm);
    }
    _remainingSeconds = _computeRemainingSeconds();
    _startCountdown();
  }

  /// Derived from AlarmService's own start time rather than a fresh local
  /// timer, so the displayed countdown can never drift out of sync with the
  /// actual alarm state (e.g. when this screen is opened some time after the
  /// alarm already started ringing in the background).
  int _computeRemainingSeconds() {
    final startedAt = AlarmService.instance.alarmStartedAt;
    if (startedAt == null) return 0;
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final remaining = AppConstants.autoStopSeconds - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!AlarmService.instance.isAlarmPlaying) {
        // Stopped externally (e.g. AlarmService's own auto-stop timer fired).
        timer.cancel();
        Navigator.of(context).pop();
        return;
      }
      setState(() => _remainingSeconds = _computeRemainingSeconds());
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _stopAndPop();
      }
    });
  }

  Future<void> _stopAndPop() async {
    _countdownTimer?.cancel();
    // When the alarm was geofence-triggered, the sound plays in the
    // foreground service isolate - stop it there. The local call clears
    // this isolate's mirror state (and any locally-started sound).
    await AppGeofenceService.instance.stopBackgroundAlarm();
    await AlarmService.instance.stopAlarm();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _snooze() async {
    _countdownTimer?.cancel();
    // Prefer snoozing in the service isolate: its timer keeps running even
    // if the app is closed before the snooze elapses. Fall back to a local
    // snooze only when the service isn't running (manually opened screen).
    final handledInBackground =
        await AppGeofenceService.instance.snoozeBackgroundAlarm();
    if (handledInBackground) {
      await AlarmService.instance.stopAlarm();
    } else {
      await AlarmService.instance.snoozeAlarm(widget.alarm);
    }
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Snoozed for ${AppConstants.snoozeDurationMinutes} minutes'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        _PulsingAlarmIcon(
                          scale: _pulseAnimation,
                          ringColor: _alertColorAnimation,
                        ),
                        const SizedBox(height: 40),
                        Text(
                          'GEOFENCE ALARM',
                          semanticsLabel: 'Geofence alarm is ringing',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: _alertColor,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            widget.alarm.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.white54, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.alarm.latitude.toStringAsFixed(4)}, '
                              '${widget.alarm.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Auto-stop in $_remainingSeconds sec',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(flex: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          child: Column(
                            children: [
                              Semantics(
                                label:
                                    'Stop alarm. Stops the alarm sound and closes this screen.',
                                button: true,
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.alarm_off, size: 24),
                                    label: const Text(
                                      'STOP ALARM',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _alertColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: _stopAndPop,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Semantics(
                                label:
                                    'Snooze. Stops the alarm and rings again in '
                                    '${AppConstants.snoozeDurationMinutes} minutes.',
                                button: true,
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.snooze, size: 24),
                                    label: const Text(
                                      'SNOOZE (${AppConstants.snoozeDurationMinutes} min)',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                          color: Colors.white54),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: _snooze,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PulsingAlarmIcon extends StatelessWidget {
  final Animation<double> scale;
  final Animation<Color?> ringColor;

  const _PulsingAlarmIcon({required this.scale, required this.ringColor});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([scale, ringColor]),
      builder: (context, child) {
        return Transform.scale(
          scale: scale.value,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(26),
              border: Border.all(
                color: ringColor.value ?? Colors.white,
                width: 3,
              ),
            ),
            child: Icon(
              Icons.notifications_active,
              size: 80,
              color: ringColor.value ?? Colors.white,
            ),
          ),
        );
      },
    );
  }
}
