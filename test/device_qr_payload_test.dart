import 'package:flutter_test/flutter_test.dart';
import 'package:petoteco/screens/device/bind_device_screen.dart';

void main() {
  test('parses admin JSON QR payload', () {
    final payload = DeviceQrPayload.parse(
      '{"device_id":"collar_001","device_key":"calmpaws_secret"}',
    );

    expect(payload?.deviceId, 'collar_001');
    expect(payload?.deviceKey, 'calmpaws_secret');
  });

  test('parses admin URL QR payload', () {
    final payload = DeviceQrPayload.parse(
      'https://api.myvideotest2026.top/admin/device-bind?device_id=collar_001&device_key=calmpaws_secret',
    );

    expect(payload?.deviceId, 'collar_001');
    expect(payload?.deviceKey, 'calmpaws_secret');
  });

  test('parses query-string and delimited QR payloads', () {
    expect(
      DeviceQrPayload.parse('device_id=collar_001&device_key=calmpaws_secret')
          ?.deviceKey,
      'calmpaws_secret',
    );
    expect(
      DeviceQrPayload.parse('collar_001|calmpaws_secret')?.deviceId,
      'collar_001',
    );
  });

  test('rejects invalid QR payload', () {
    expect(DeviceQrPayload.parse('hello'), isNull);
    expect(DeviceQrPayload.parse('{"device_id":"collar_001"}'), isNull);
  });
}
