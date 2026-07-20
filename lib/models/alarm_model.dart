import '../config/constants.dart';

class AlarmModel {
  final int? id;
  final String title;
  final double latitude;
  final double longitude;
  final double radius;
  final bool isActive;
  final DateTime createdAt;

  /// If true, this alarm deactivates itself (isActive -> false) the moment
  /// it fires, and monitoring stops entirely once no active alarms remain -
  /// meant for a single trip, so background location isn't held after use.
  /// If false (default), it stays armed and can fire again on re-entry.
  final bool isOneTime;

  const AlarmModel({
    this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.isActive = true,
    required this.createdAt,
    this.isOneTime = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) AppConstants.colId: id,
      AppConstants.colTitle: title,
      AppConstants.colLatitude: latitude,
      AppConstants.colLongitude: longitude,
      AppConstants.colRadius: radius,
      AppConstants.colIsActive: isActive ? 1 : 0,
      AppConstants.colCreatedAt: createdAt.toIso8601String(),
      AppConstants.colIsOneTime: isOneTime ? 1 : 0,
    };
  }

  factory AlarmModel.fromMap(Map<String, dynamic> map) {
    return AlarmModel(
      id: map[AppConstants.colId] as int?,
      title: map[AppConstants.colTitle] as String,
      latitude: map[AppConstants.colLatitude] as double,
      longitude: map[AppConstants.colLongitude] as double,
      radius: map[AppConstants.colRadius] as double,
      isActive: (map[AppConstants.colIsActive] as int) == 1,
      createdAt: DateTime.parse(map[AppConstants.colCreatedAt] as String),
      // Column added in DB v2; rows migrated from v1 have no value for it,
      // so default to false (repeat) to preserve their prior behavior.
      isOneTime: (map[AppConstants.colIsOneTime] as int?) == 1,
    );
  }

  AlarmModel copyWith({
    int? id,
    String? title,
    double? latitude,
    double? longitude,
    double? radius,
    bool? isActive,
    DateTime? createdAt,
    bool? isOneTime,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      title: title ?? this.title,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      isOneTime: isOneTime ?? this.isOneTime,
    );
  }

  @override
  String toString() {
    return 'AlarmModel(id: $id, title: $title, lat: $latitude, lng: $longitude, '
        'radius: $radius, isActive: $isActive, isOneTime: $isOneTime, '
        'createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AlarmModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
