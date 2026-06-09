// =============================================================================
// bound_device.dart — GET /api/user/devices 绑定设备模型
// =============================================================================

class BoundDevice {
  final String deviceId;
  final String species;
  final DateTime? boundAt;

  const BoundDevice({
    required this.deviceId,
    this.species = 'dog',
    this.boundAt,
  });

  factory BoundDevice.fromJson(Map<String, dynamic> json) {
    DateTime? boundAt;
    final raw = json['bound_at'] as String?;
    if (raw != null) {
      boundAt = DateTime.tryParse(raw);
    }
    return BoundDevice(
      deviceId: (json['device_id'] as String?) ?? '',
      species: (json['species'] as String?) ?? 'dog',
      boundAt: boundAt,
    );
  }

  String get speciesEmoji => species == 'cat' ? '🐱' : '🐕';
}
