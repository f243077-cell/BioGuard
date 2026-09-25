import 'reading.dart';

/// BioGuard — Device Model
/// Mirrors the backend's DeviceStatus schema: latest temperature + lock
/// reading, plus an optional friendly name/location (e.g. set via the
/// backend's scripts/seed_devices.py — null for an unnamed device).
class Device {
  final String deviceId;
  final String? name;
  final String? location;
  final Reading? temperature;
  final Reading? lock;

  Device({
    required this.deviceId,
    this.name,
    this.location,
    this.temperature,
    this.lock,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceId: json['device_id'] as String,
      name: json['name'] as String?,
      location: json['location'] as String?,
      temperature: json['temperature'] != null
          ? Reading.fromJson(json['temperature'] as Map<String, dynamic>)
          : null,
      lock: json['lock'] != null
          ? Reading.fromJson(json['lock'] as Map<String, dynamic>)
          : null,
    );
  }

  /// What to show as the card's title: the friendly name if set, else the
  /// raw device id.
  String get displayName =>
      (name != null && name!.isNotEmpty) ? name! : deviceId;

  bool get isLocked => lock?.statusValue == 'locked';
  bool get hasAnomaly => temperature?.anomalous == true;
}
