/// BioGuard — Alert Model
/// Mirrors the backend's alert broadcast/API shape.
class Alert {
  final int id;
  final String deviceId;
  final String alertType;
  final String message;
  final String severity;
  final bool resolved;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  Alert({
    required this.id,
    required this.deviceId,
    required this.alertType,
    required this.message,
    required this.severity,
    required this.resolved,
    required this.createdAt,
    this.resolvedAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as int,
      deviceId: json['device_id'] as String,
      alertType: json['alert_type'] as String,
      message: json['message'] as String,
      severity: json['severity'] as String,
      resolved: json['resolved'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
    );
  }
}
