/// BioGuard — Reading Model
/// Mirrors the backend's ReadingOut schema.
class Reading {
  final int id;
  final String deviceId;
  final String readingType; // "temperature" or "lock"
  final double? numericValue;
  final String? statusValue;
  final bool anomalous;
  final DateTime timestamp;

  Reading({
    required this.id,
    required this.deviceId,
    required this.readingType,
    this.numericValue,
    this.statusValue,
    required this.anomalous,
    required this.timestamp,
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      id: json['id'] as int,
      deviceId: json['device_id'] as String,
      readingType: json['reading_type'] as String,
      numericValue: (json['numeric_value'] as num?)?.toDouble(),
      statusValue: json['status_value'] as String?,
      anomalous: json['anomalous'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
