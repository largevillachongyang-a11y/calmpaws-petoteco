// =============================================================================
// server_alert.dart — /api/alerts 响应模型
// =============================================================================

class ServerAlert {
  final String type;
  final String message;
  final String? severity;
  final int? battery;

  const ServerAlert({
    required this.type,
    required this.message,
    this.severity,
    this.battery,
  });

  factory ServerAlert.fromJson(dynamic json) {
    if (json is String) {
      return ServerAlert(type: 'info', message: json);
    }
    if (json is Map<String, dynamic>) {
      final battery = json['battery'];
      return ServerAlert(
        type: (json['type'] as String?) ??
            (json['alert_type'] as String?) ??
            'alert',
        message: (json['message'] as String?) ??
            (json['text'] as String?) ??
            (json['body'] as String?) ??
            (json['title'] as String?) ??
            '',
        severity: (json['severity'] as String?) ?? (json['level'] as String?),
        battery: battery is num ? battery.toInt() : null,
      );
    }
    return ServerAlert(type: 'alert', message: json.toString());
  }

  bool get isEmpty => message.trim().isEmpty && battery == null;
}
