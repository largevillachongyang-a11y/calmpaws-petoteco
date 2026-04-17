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
///
/// ⚠️ 重要：真实硬件传出的是【累计值】（自开机后只增不减）
/// 本 Mock 同样维护累计计数器，与真实硬件行为完全一致。
/// App 层通过 差值（delta = 当前包 - 上一包）来判断本5秒内的行为。
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

  // ── 累计计数器（模拟真实硬件，自启动后单调递增）──────────────────────────
  // 真实硬件：Arduino 中 shivering_count / stress_count 等从不清零
  int _cumStrC  = 0;  // 累计应激次数
  int _cumStrD  = 0;  // 累计应激持续秒
  int _cumShivC = 0;  // 累计发抖次数
  int _cumShivD = 0;  // 累计发抖持续秒
  int _cumPaceD = 0;  // 累计踱步持续秒
  int _cumPlayD = 0;  // 累计玩耍持续秒
  int _cumRollC = 0;  // 累计打滚次数

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

  /// 重置累计计数器（模拟设备重启/重连场景）
  void resetCumulativeCounters() {
    _cumStrC = _cumStrD = _cumShivC = _cumShivD = 0;
    _cumPaceD = _cumPlayD = _cumRollC = 0;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  /// 手动触发发抖预警测试（直接向累计值加大量发抖数据）
  BlePacket triggerShiverAlert() {
    // 本次5秒：4次发抖，持续45秒（超出5秒，模拟连续发抖）
    _cumShivC += 4;
    _cumShivD += 45;
    _cumStrC  += 1;
    _cumStrD  += 5;
    final packet = BlePacket(
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      strC: _cumStrC,
      strD: _cumStrD,
      shivC: _cumShivC,
      shivD: _cumShivD,
      paceD: _cumPaceD,
      playD: _cumPlayD,
      rollC: _cumRollC,
      battery: _battery,
      rssi: _rssi,
    );
    _controller.add(packet);
    return packet;
  }

  /// 每5秒生成一包累计值数据包
  /// 先计算"本5秒内增量"，加到累计器上，再返回累计值包
  BlePacket _generatePacket() {
    final hour = DateTime.now().hour;
    final phase = _getDayPhase(hour);

    // 本5秒内的增量（delta）
    int dStrC = 0, dStrD = 0, dShivC = 0, dShivD = 0;
    int dPaceD = 0, dPlayD = 0, dRollC = 0;

    switch (phase) {
      case _DayPhase.morningActive: // 6-9am: active & playful
        dPlayD = _rng(15, 35);
        dRollC = _rng(0, 2);
        dStrC  = (anxietyLevel * 2).round();
        dStrD  = (anxietyLevel * 5).round();
        dPaceD = (anxietyLevel * 8).round();

      case _DayPhase.preFeeding: // 9-10am: waiting, anxious
        dPaceD = _rng(20, 40) + (anxietyLevel * 20).round();
        dStrC  = _rng(2, 4) + (anxietyLevel * 3).round();
        dStrD  = _rng(10, 25) + (anxietyLevel * 15).round();
        dRollC = _rng(0, 1);

      case _DayPhase.postFeedingCalming: // 10-12: calming down post-ZenBelly
        final calmProgress = _getCalmProgress();
        dPaceD = (20 * (1 - calmProgress)).round();
        dStrC  = ((3 + anxietyLevel * 2) * (1 - calmProgress)).round();
        dStrD  = ((15 * (1 - calmProgress)) + _rng(0, 5)).round();
        dPlayD = (calmProgress * 10).round();

      case _DayPhase.nap: // 12-14: napping
        dPaceD = _rng(0, 3);
        dStrC  = 0;
        dStrD  = _rng(0, 3);
        dPlayD = 0;
        dRollC = _random.nextBool() ? 1 : 0;

      case _DayPhase.afternoonPlay: // 15-17: active afternoon
        dPlayD = _rng(20, 45);
        dRollC = _rng(1, 3);
        dStrC  = (anxietyLevel * 1.5).round();
        dPaceD = (anxietyLevel * 5).round();

      case _DayPhase.eveningRelax: // 18-21: relaxing
        dPaceD = (anxietyLevel * 10).round();
        dStrC  = (anxietyLevel * 2).round();
        dStrD  = (anxietyLevel * 8).round();
        dPlayD = _rng(5, 15);

      case _DayPhase.nightSleep: // 22-5: sleeping
        dPaceD = 0;
        dStrC  = (anxietyLevel > 0.7 ? _rng(0, 1) : 0);
        dStrD  = (anxietyLevel > 0.7 ? _rng(0, 5) : 0);
        dRollC = _random.nextDouble() < 0.15 ? 1 : 0;
    }

    // Add noise to deltas（噪声只加在增量上）
    dStrC  = (dStrC  + _noisyInt(1)).clamp(0, 15);
    dStrD  = (dStrD  + _noisyInt(3)).clamp(0, 60);
    dPaceD = (dPaceD + _noisyInt(5)).clamp(0, 60);
    dPlayD = (dPlayD + _noisyInt(3)).clamp(0, 60);

    // 高焦虑时生成发抖增量
    if (anxietyLevel >= 0.8) {
      final shiverProb = (anxietyLevel - 0.8) / 0.2; // 0.0 ~ 1.0
      if (_random.nextDouble() < shiverProb * 0.7 + 0.3) {
        dShivC = _rng(1, 3);
        // 本5秒内发抖时长（最多5秒 = 采样间隔）
        dShivD = (5 * (0.5 + shiverProb * 0.5)).round().clamp(2, 5);
      }
    }

    // 将增量累加到全局累计计数器
    _cumStrC  += dStrC;
    _cumStrD  += dStrD;
    _cumShivC += dShivC;
    _cumShivD += dShivD;
    _cumPaceD += dPaceD;
    _cumPlayD += dPlayD;
    _cumRollC += dRollC;

    // 返回累计值数据包（与真实硬件格式一致）
    return BlePacket(
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      strC:  _cumStrC,
      strD:  _cumStrD,
      shivC: _cumShivC,
      shivD: _cumShivD,
      paceD: _cumPaceD,
      playD: _cumPlayD,
      rollC: _cumRollC,
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
