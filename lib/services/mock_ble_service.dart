// =============================================================================
// mock_ble_service.dart — BLE 硬件模拟服务
// =============================================================================
// 职责：在真实 BLE 硬件到位之前，模拟宠物项圈的实时数据推送。
// 每秒生成一个 BlePacket，模拟一只有分离焦虑症的金毛寻回犬的一天。
//
// [TODO] 生产环境中，此文件应被替换为真实 BLE SDK 的实现，如：
//   flutter_blue_plus: ^1.31.15
//   替换要点：
//     1. scan() → 扫描 BLE 设备，找到目标 UUID
//     2. connect() → 建立 BLE 连接
//     3. characteristic.setNotifyValue(true) → 订阅通知
//     4. characteristic.onValueReceived → 接收字节数据，用 BlePacket.fromJson() 解析
//     5. 断开/重连逻辑需要特别处理（蓝牙信号不稳定）
//
// 模拟的行为周期（configurable anxietyLevel）：
//   anxietyLevel = 0.0 → 宠物全天平静（用于测试正常状态）
//   anxietyLevel = 0.5 → 中度焦虑（默认）
//   anxietyLevel = 1.0 → 高度焦虑（用于测试预警触发）
// =============================================================================
import 'dart:async';
import 'dart:math';
import '../models/models.dart';

/// Mock BLE 数据生成器，模拟真实硬件数据包
/// 模拟一只有分离焦虑症的狗的真实一天行为周期
class MockBleService {
  static final MockBleService _instance = MockBleService._internal();
  factory MockBleService() => _instance;
  MockBleService._internal();

  final _random = Random();
  Timer? _timer;
  final StreamController<BlePacket> _controller =
      StreamController<BlePacket>.broadcast();

  Stream<BlePacket> get stream => _controller.stream;
  bool get isRunning => _timer?.isActive ?? false;

  // Tunable anxiety slider 0.0 (totally calm) → 1.0 (max anxiety)
  double anxietyLevel = 0.4;

  // Device state
  int _battery = 82;
  int _rssi = -62;
  bool _deviceConnected = false;

  bool get deviceConnected => _deviceConnected;

  /// Start streaming mock packets every 5 seconds
  void start() {
    _deviceConnected = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _controller.add(_generatePacket());
      _simulateBatteryDrain();
    });
  }

  void stop() {
    _timer?.cancel();
    _deviceConnected = false;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  /// Manually trigger a shiver alert for testing
  BlePacket triggerShiverAlert() {
    final packet = BlePacket(
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      strC: 1,
      strD: 5,
      shivC: 4,
      shivD: 45,
      paceD: 0,
      playD: 0,
      rollC: 0,
      battery: _battery,
      rssi: _rssi,
    );
    _controller.add(packet);
    return packet;
  }

  /// Generate a realistic packet based on time-of-day + anxiety level
  BlePacket _generatePacket() {
    final hour = DateTime.now().hour;
    final phase = _getDayPhase(hour);

    int strC = 0, strD = 0, shivC = 0, shivD = 0;
    int paceD = 0, playD = 0, rollC = 0;

    switch (phase) {
      case _DayPhase.morningActive: // 6-9am: active & playful
        playD = _rng(15, 35);
        rollC = _rng(0, 2);
        strC = (anxietyLevel * 2).round();
        strD = (anxietyLevel * 5).round();
        paceD = (anxietyLevel * 8).round();

      case _DayPhase.preFeeding: // 9-10am: waiting, anxious
        paceD = _rng(20, 40) + (anxietyLevel * 20).round();
        strC = _rng(2, 4) + (anxietyLevel * 3).round();
        strD = _rng(10, 25) + (anxietyLevel * 15).round();
        rollC = _rng(0, 1);

      case _DayPhase.postFeedingCalming: // 10-12: calming down post-ZenBelly
        final calmProgress = _getCalmProgress();
        paceD = (20 * (1 - calmProgress)).round();
        strC = ((3 + anxietyLevel * 2) * (1 - calmProgress)).round();
        strD = ((15 * (1 - calmProgress)) + _rng(0, 5)).round();
        playD = (calmProgress * 10).round();

      case _DayPhase.nap: // 12-14: napping
        paceD = _rng(0, 3);
        strC = 0;
        strD = _rng(0, 3);
        playD = 0;
        rollC = _random.nextBool() ? 1 : 0; // occasional roll = healthy sleep

      case _DayPhase.afternoonPlay: // 15-17: active afternoon
        playD = _rng(20, 45);
        rollC = _rng(1, 3);
        strC = (anxietyLevel * 1.5).round();
        paceD = (anxietyLevel * 5).round();

      case _DayPhase.eveningRelax: // 18-21: relaxing
        paceD = (anxietyLevel * 10).round();
        strC = (anxietyLevel * 2).round();
        strD = (anxietyLevel * 8).round();
        playD = _rng(5, 15);

      case _DayPhase.nightSleep: // 22-5: sleeping
        paceD = 0;
        strC = (anxietyLevel > 0.7 ? _rng(0, 1) : 0);
        strD = (anxietyLevel > 0.7 ? _rng(0, 5) : 0);
        rollC = _random.nextDouble() < 0.15 ? 1 : 0;
    }

    // Add noise
    strC = (strC + _noisyInt(1)).clamp(0, 15);
    strD = (strD + _noisyInt(3)).clamp(0, 60);
    paceD = (paceD + _noisyInt(5)).clamp(0, 60);
    playD = (playD + _noisyInt(3)).clamp(0, 60);

    return BlePacket(
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      strC: strC,
      strD: strD,
      shivC: shivC,
      shivD: shivD,
      paceD: paceD,
      playD: playD,
      rollC: rollC,
      battery: _battery,
      rssi: _rssi,
    );
  }

  _DayPhase _getDayPhase(int hour) {
    if (hour >= 6 && hour < 9) return _DayPhase.morningActive;
    if (hour >= 9 && hour < 10) return _DayPhase.preFeeding;
    if (hour >= 10 && hour < 12) return _DayPhase.postFeedingCalming;
    if (hour >= 12 && hour < 15) return _DayPhase.nap;
    if (hour >= 15 && hour < 18) return _DayPhase.afternoonPlay;
    if (hour >= 18 && hour < 22) return _DayPhase.eveningRelax;
    return _DayPhase.nightSleep;
  }

  /// Simulates calm progress based on time since last feeding
  double _getCalmProgress() {
    // 0.0 = just fed, 1.0 = fully calm (typically within 30 min)
    return (_random.nextDouble() * 0.3 + 0.4).clamp(0.0, 1.0);
  }

  void _simulateBatteryDrain() {
    if (_random.nextInt(120) == 0) {
      _battery = (_battery - 1).clamp(0, 100);
    }
    _rssi = -62 + _rng(-5, 5);
  }

  int _rng(int min, int max) => min + _random.nextInt(max - min + 1);
  int _noisyInt(int range) => _random.nextInt(range * 2 + 1) - range;
}

enum _DayPhase {
  morningActive,
  preFeeding,
  postFeedingCalming,
  nap,
  afternoonPlay,
  eveningRelax,
  nightSleep,
}

/// Pre-computed historical stress data for the 14-day chart
/// Represents before-treatment baseline and improving trend post-treatment
List<List<HourlyStressPoint>> generateHistoricalDailyData(int days) {
  final random = Random(42); // fixed seed for consistent demo data
  return List.generate(days, (dayIndex) {
    final isTreatmentDay = dayIndex >= 7; // first 7 days = baseline
    final improvementFactor =
        isTreatmentDay ? (dayIndex - 7) / 7.0 * 0.6 : 0.0;

    return List.generate(24, (hour) {
      double baseScore;
      if (hour >= 9 && hour < 11) {
        baseScore = 70 + random.nextDouble() * 20;
      } else if (hour >= 12 && hour < 15) {
        baseScore = 10 + random.nextDouble() * 15;
      } else if (hour >= 22 || hour < 6) {
        baseScore = 5 + random.nextDouble() * 10;
      } else {
        baseScore = 30 + random.nextDouble() * 30;
      }
      final finalScore = (baseScore * (1 - improvementFactor))
          .clamp(0.0, 100.0);
      return HourlyStressPoint(
        hour: hour,
        stressScore: finalScore,
        isAfterFeeding: isTreatmentDay,
      );
    });
  });
}

/// Generate a 14-day daily stress summary list
List<DailyStressDataPoint> generateDailyStressChart() {
  final random = Random(42);
  return List.generate(14, (i) {
    final isAfter = i >= 7;
    double base = isAfter ? 65 - (i - 7) * 7.0 : 60 + random.nextDouble() * 20;
    base += random.nextDouble() * 10 - 5;
    return DailyStressDataPoint(
      dayIndex: i,
      stressScore: base.clamp(5.0, 95.0),
      isAfterTreatment: isAfter,
      label: 'D${i + 1}',
    );
  });
}

class DailyStressDataPoint {
  final int dayIndex;
  final double stressScore;
  final bool isAfterTreatment;
  final String label;

  const DailyStressDataPoint({
    required this.dayIndex,
    required this.stressScore,
    required this.isAfterTreatment,
    required this.label,
  });
}
