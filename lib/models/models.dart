// =============================================================================
// models.dart — 应用核心数据模型定义
// =============================================================================
// 包含的模型：
//   • BlePacket            — BLE 硬件设备实时推送的一个数据包（每 5 秒一次）
//   • PetBehaviorState     — 宠物当前行为状态枚举（平静/踱步/应激等）
//   • PetProfile           — 宠物基本档案（名字/品种/年龄/健康标签）
//   • FeedingSession       — 一次喂食会话记录（包含喂食前后压力对比）
//   • BehaviorSnapshot     — 喂食后每 5 分钟的行为快照
//   • JournalEntry         — 主人手动记录的健康日志
//   • DailyStressDataPoint — 压力趋势图的单个数据点（Firestore 持久化）
//   • DailyRecord          — 健康日历的单日完整记录（传感层 + 主人层）
//   • SensorDaySummary     — 一天的传感器汇总数据
//
// Firestore 数据结构（集合路径）：
//   users/{uid}/feeding_sessions/{sessionId}   — 喂食记录
//   users/{uid}/journal_entries/{entryId}      — 健康日志
//   users/{uid}/daily_stress/{dateStr}         — 每日压力数据点（dateStr = 'yyyy-MM-dd'）
//
// [API 需求] 接入后端时，以下模型需要提供对应的 fromJson/toJson 方法：
//   • PetProfile, FeedingSession, JournalEntry 需要与后端 API 交互
//   • BlePacket 需要与硬件协议对齐（fromJson 已实现）
// =============================================================================

/// BLE 硬件设备实时推送的数据包——严格对应硬件 JSON 协议
/// 硬件每 5 秒通过 BLE 推送一个包，字段定义与硬件团队确认过。
/// [API 需求] 硬件 JSON 格式：
///   { "timestamp":1700000000, "str_c":2, "str_d":15, "shiv_c":0, "shiv_d":0,
///     "pace_d":10, "play_d":5, "roll_c":1, "battery":82, "rssi":-65 }
class BlePacket {
  final int timestamp;
  final int strC;    // stress count (应激次数)
  final int strD;    // stress duration seconds (应激持续秒)
  final int shivC;   // shiver count (发抖次数)
  final int shivD;   // shiver duration seconds (发抖持续秒)
  final int paceD;   // pacing duration seconds (踱步持续秒)
  final int playD;   // play duration seconds (玩耍持续秒)
  final int rollC;   // roll count (打滚次数)
  final int battery; // battery percentage
  final int rssi;    // BLE signal strength

  const BlePacket({
    required this.timestamp,
    required this.strC,
    required this.strD,
    required this.shivC,
    required this.shivD,
    required this.paceD,
    required this.playD,
    required this.rollC,
    required this.battery,
    required this.rssi,
  });

  factory BlePacket.fromJson(Map<String, dynamic> json) {
    return BlePacket(
      timestamp: (json['timestamp'] as num).toInt(),
      strC: (json['str_c'] as num).toInt(),
      strD: (json['str_d'] as num).toInt(),
      shivC: (json['shiv_c'] as num).toInt(),
      shivD: (json['shiv_d'] as num).toInt(),
      paceD: (json['pace_d'] as num).toInt(),
      playD: (json['play_d'] as num).toInt(),
      rollC: (json['roll_c'] as num).toInt(),
      battery: (json['battery'] as num).toInt(),
      rssi: (json['rssi'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'str_c': strC,
    'str_d': strD,
    'shiv_c': shivC,
    'shiv_d': shivD,
    'pace_d': paceD,
    'play_d': playD,
    'roll_c': rollC,
    'battery': battery,
    'rssi': rssi,
  };

  /// 根据 BLE 数据包计算行为状态——优先级：颤抖 > 应激 > 踱步 > 玩耗 > 平静
  /// 注：此为实时状态判断，不考虑历史趋势
  PetBehaviorState get behaviorState {
    if (shivD > 30) return PetBehaviorState.shivering;
    if (strC >= 3 || strD > 20) return PetBehaviorState.stressed;
    if (paceD > 20) return PetBehaviorState.pacing;
    if (playD > 20) return PetBehaviorState.playing;
    return PetBehaviorState.calm;
  }

  /// 当前数据包的综合焦虑分 0-100
  /// 分值算法：应激次数×8 + 踱步时长×1.5 + 颤抖时长×2 + 应激将5秒
  /// [TODO] 实际项目中应由数据科学家验证权重参数，目前为经验值
  int get anxietyScore {
    int score = 0;
    score += (strC * 8).clamp(0, 40);
    score += (paceD * 1.5).round().clamp(0, 30);
    score += (shivD * 2).clamp(0, 20);
    score += strD.clamp(0, 10);
    return score.clamp(0, 100);
  }

  /// 活动尽兴分 0-100（玩耗时长 + 打滚次数为主要贡献）
  int get activityScore {
    int score = 0;
    score += (playD * 2).clamp(0, 60);
    score += (rollC * 10).clamp(0, 30);
    score += (strC * 3).clamp(0, 10);
    return score.clamp(0, 100);
  }
}

/// 宠物行为状态枚举——由 BlePacket.behaviorState 计算得出
/// 也用于 UI 展示（emoji + 文字标签）
enum PetBehaviorState {
  calm,
  pacing,
  stressed,
  playing,
  shivering,
  sleeping;

  String get label {
    switch (this) {
      case calm: return 'Calm';
      case pacing: return 'Pacing';
      case stressed: return 'Stressed';
      case playing: return 'Playing';
      case shivering: return 'Shivering';
      case sleeping: return 'Sleeping';
    }
  }

  String get emoji {
    switch (this) {
      case calm: return '😌';
      case pacing: return '😰';
      case stressed: return '😣';
      case playing: return '🎾';
      case shivering: return '🥶';
      case sleeping: return '😴';
    }
  }
}

/// 宠物档案——每个用户有一个宠物档案
/// 用户可在宠物页面编辑，修改内存中的实例。
/// [API 需求] 持久化时：
///   GET  /api/pets/{userId}   返回: { id, name, species, breed, ageMonths, weightKg, healthTags[] }
///   PUT  /api/pets/{id}       body: 同上
///   POST /api/pets            创建新宠物
class PetProfile {
  final String id;
  final String name;
  final String species; // dog / cat
  final String breed;
  final int ageMonths;
  final double weightKg;
  final String? photoPath;
  final List<String> healthTags;
  final DateTime createdAt;

  const PetProfile({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.ageMonths,
    required this.weightKg,
    this.photoPath,
    required this.healthTags,
    required this.createdAt,
  });

  String get ageLabel {
    if (ageMonths < 12) return '${ageMonths}mo';
    final years = ageMonths ~/ 12;
    final months = ageMonths % 12;
    return months == 0 ? '${years}y' : '${years}y ${months}mo';
  }

  PetProfile copyWith({
    String? name,
    String? species,
    String? breed,
    int? ageMonths,
    double? weightKg,
    String? photoPath,
    List<String>? healthTags,
  }) {
    return PetProfile(
      id: id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      ageMonths: ageMonths ?? this.ageMonths,
      weightKg: weightKg ?? this.weightKg,
      photoPath: photoPath ?? this.photoPath,
      healthTags: healthTags ?? this.healthTags,
      createdAt: createdAt,
    );
  }
}

/// 一次喂食会话——主人点击「已喂食」开始，到宠物平静自动结束
/// Time-to-Calm = 坂食到平静的秒数（产品核心指标）
/// [API 需求]
///   POST  /api/feeding-sessions  body: { petId, feedTime, stressCountBefore }
///   PATCH /api/feeding-sessions/{id}  body: { timeToCalm, stressCountAfter, timeline[] }
///   GET   /api/feeding-sessions?petId={id}&limit=20  返回历史列表
class FeedingSession {
  final String id;
  final DateTime feedTime;
  final int? timeToCalm; // seconds until calm state; null if still counting
  final int? stressCountBefore;
  final int? stressCountAfter;
  final List<BehaviorSnapshot> timeline; // behavior snapshots post-feeding

  const FeedingSession({
    required this.id,
    required this.feedTime,
    this.timeToCalm,
    this.stressCountBefore,
    this.stressCountAfter,
    this.timeline = const [],
  });

  bool get isActive => timeToCalm == null;

  Duration get elapsed => DateTime.now().difference(feedTime);

  FeedingSession copyWith({
    int? timeToCalm,
    int? stressCountBefore,
    int? stressCountAfter,
    List<BehaviorSnapshot>? timeline,
  }) {
    return FeedingSession(
      id: id,
      feedTime: feedTime,
      timeToCalm: timeToCalm ?? this.timeToCalm,
      stressCountBefore: stressCountBefore ?? this.stressCountBefore,
      stressCountAfter: stressCountAfter ?? this.stressCountAfter,
      timeline: timeline ?? this.timeline,
    );
  }
}

/// Snapshot of behavior state at a specific time post-feeding
class BehaviorSnapshot {
  final int minutesAfterFeed;
  final PetBehaviorState state;
  final int anxietyScore;

  const BehaviorSnapshot({
    required this.minutesAfterFeed,
    required this.state,
    required this.anxietyScore,
  });
}

/// Aggregated daily health summary
class DailyHealthSummary {
  final DateTime date;
  final int totalPacingSeconds;
  final int totalStressCount;
  final int totalShiverSeconds;
  final int totalPlaySeconds;
  final int deepSleepMinutes;
  final int anxiousDurationMinutes;
  final double avgAnxietyScore;
  final double activityScore;
  final bool hasAlert;
  final String? alertMessage;

  const DailyHealthSummary({
    required this.date,
    required this.totalPacingSeconds,
    required this.totalStressCount,
    required this.totalShiverSeconds,
    required this.totalPlaySeconds,
    required this.deepSleepMinutes,
    required this.anxiousDurationMinutes,
    required this.avgAnxietyScore,
    required this.activityScore,
    this.hasAlert = false,
    this.alertMessage,
  });
}

/// Hourly stress data point for chart
class HourlyStressPoint {
  final int hour;
  final double stressScore;
  final bool isAfterFeeding;

  const HourlyStressPoint({
    required this.hour,
    required this.stressScore,
    required this.isAfterFeeding,
  });
}

/// Journal entry
class JournalEntry {
  final String id;
  final DateTime date;
  final String stoolEmoji;    // 💩 color/consistency
  final String moodEmoji;     // 😊😰😣
  final String appetiteEmoji; // 🍖😐🚫
  final String energyEmoji;   // ⚡😴
  final String? notes;
  final List<String> negativeFlags; // triggers smart shop recommendation

  const JournalEntry({
    required this.id,
    required this.date,
    required this.stoolEmoji,
    required this.moodEmoji,
    required this.appetiteEmoji,
    required this.energyEmoji,
    this.notes,
    this.negativeFlags = const [],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
/// DailyRecord — 日历融合视图的每日聚合模型
/// 规则：
///   1. sensorSummary 来自传感器，可能为 null（设备离线日）
///   2. journalEntry  来自主人记录，可能为 null（未填写日）
///   3. 两层完全独立，不做合并计算，只用于展示
/// ─────────────────────────────────────────────────────────────────────────────
class DailyRecord {
  final DateTime date;
  final SensorDaySummary? sensorSummary; // 传感器层（可为 null = 设备离线）
  final JournalEntry?     journalEntry;  // 主人记录层（可为 null = 未填写）

  const DailyRecord({
    required this.date,
    this.sensorSummary,
    this.journalEntry,
  });

  /// 是否有任何数据（至少一层有内容）
  bool get hasAnyData => sensorSummary != null || journalEntry != null;

  /// 传感器应激等级：0=无数据 1=低 2=中 3=高
  int get stressLevel {
    final s = sensorSummary?.avgStressScore ?? 0;
    if (s == 0) return 0;
    if (s < 35) return 1;
    if (s < 65) return 2;
    return 3;
  }
}

/// 传感器每日汇总 — 只存展示所需字段，不与主人记录混合
class SensorDaySummary {
  final double avgStressScore;   // 0–100，当天平均应激分
  final int    stressEventCount; // 应激事件次数
  final int    pacingMinutes;    // 踱步分钟数
  final int    playMinutes;      // 玩耍分钟数
  final int    activityScore;    // 0–100 活动评分
  final bool   hasFeeding;       // 当天是否有喂食记录
  final int?   timeToCalmSecs;   // 喂食后平静用时（秒），null=无喂食

  const SensorDaySummary({
    required this.avgStressScore,
    required this.stressEventCount,
    required this.pacingMinutes,
    required this.playMinutes,
    required this.activityScore,
    this.hasFeeding = false,
    this.timeToCalmSecs,
  });
}

/// All available health tags for pet profile
const List<String> kHealthTags = [
  'Separation Anxiety',
  'Joint Stiffness',
  'Digestive Issues',
  'Skin Allergies',
  'Food Sensitivity',
  'Noise Phobia',
  'Hyperactivity',
  'Weight Management',
  'Senior Care',
  'Post-Surgery',
  'Dental Issues',
  'Heart Condition',
];
