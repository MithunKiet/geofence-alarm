import 'package:flutter/foundation.dart';
import '../models/alarm_model.dart';
import '../database/database_helper.dart';

class AlarmProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<AlarmModel> _alarms = [];
  bool _isLoading = false;
  String? _error;

  List<AlarmModel> get alarms => List.unmodifiable(_alarms);
  List<AlarmModel> get activeAlarms =>
      _alarms.where((a) => a.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAlarms() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _alarms = await _db.getAllAlarms();
    } catch (e) {
      _error = 'Failed to load alarms: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AlarmModel?> addAlarm(AlarmModel alarm) async {
    try {
      final id = await _db.insertAlarm(alarm);
      final newAlarm = alarm.copyWith(id: id);
      _alarms.insert(0, newAlarm);
      notifyListeners();
      return newAlarm;
    } catch (e) {
      _error = 'Failed to add alarm: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateAlarm(AlarmModel alarm) async {
    try {
      await _db.updateAlarm(alarm);
      final index = _alarms.indexWhere((a) => a.id == alarm.id);
      if (index != -1) {
        _alarms[index] = alarm;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update alarm: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAlarm(int id) async {
    try {
      await _db.deleteAlarm(id);
      _alarms.removeWhere((a) => a.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete alarm: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleAlarm(int id, bool isActive) async {
    final index = _alarms.indexWhere((a) => a.id == id);
    if (index == -1) return false;

    final updated = _alarms[index].copyWith(isActive: isActive);
    return updateAlarm(updated);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
