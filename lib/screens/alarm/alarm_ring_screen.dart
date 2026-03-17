import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/alarm_model.dart';
import '../../services/alarm_service.dart';
import '../../config/constants.dart';

class AlarmRingScreen extends StatefulWidget {
  final AlarmModel alarm;

  const AlarmRingScreen({super.key, required this.alarm});

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = AppConstants.autoStopSeconds;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Only start the alarm if it is not already playing (e.g., when the ring
    // screen is navigated to manually rather than via the geofence callback).
    if (!AlarmService.instance.isAlarmPlaying) {
      AlarmService.instance.startAlarm(widget.alarm);
    }
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _stopAndPop();
      }
    });
  }

  Future<void> _stopAndPop() async {
    _countdownTimer?.cancel();
    await AlarmService.instance.stopAlarm();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _snooze() async {
    _countdownTimer?.cancel();
    await AlarmService.instance.snoozeAlarm(widget.alarm);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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

  String get _countdownText {
    if (_remainingSeconds > 60) return '';
    return 'Auto-stop in $_remainingSeconds sec';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A237E),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Pulsing icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(26),
                    border: Border.all(
                      color: Colors.white.withAlpha(77),
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Geofence Alarm',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white70,
                      letterSpacing: 2,
                    ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.alarm.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                  const Icon(Icons.location_on, color: Colors.white54, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.alarm.latitude.toStringAsFixed(4)}, '
                    '${widget.alarm.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_remainingSeconds <= AppConstants.autoStopSeconds)
                Text(
                  _countdownText,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
              const Spacer(flex: 3),
              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.alarm_off, size: 24),
                        label: const Text(
                          'STOP ALARM',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _stopAndPop,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.snooze, size: 24),
                        label: Text(
                          'SNOOZE (${AppConstants.snoozeDurationMinutes} min)',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _snooze,
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
  }
}
