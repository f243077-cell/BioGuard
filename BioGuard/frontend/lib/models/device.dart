import 'reading.dart';

/// BioGuard — Device Model
/// Mirrors the backend's DeviceStatus schema: latest temperature + lock reading.
class Device {
  final String deviceId;
  final Reading? temperature;
  final Reading? lock;

  Device({required this.deviceId, this.temperature, this.lock});

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceId: json['device_id'] as String,
      temperature: json['temperature'] != null
          ? Reading.fromJson(json['temperature'] as Map<String, dynamic>)
          : null,
      lock: json['lock'] != null
          ? Reading.fromJson(json['lock'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isLocked => lock?.statusValue == 'locked';
  bool get hasAnomaly => temperature?.anomalous == true;
}
