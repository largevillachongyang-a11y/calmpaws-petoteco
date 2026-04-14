/// BLE packet model - mirrors the exact hardware JSON protocol
/// Hardware pushes one packet every 5 seconds via BLE
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

  /// Derived behavior state from packet
  PetBehaviorState get behaviorState {
    if (shivD > 30) return PetBehaviorState.shivering;
    if (strC >= 3 || strD > 20) return PetBehaviorState.stressed;
    if (paceD > 20) return PetBehaviorState.pacing;
    if (playD > 20) return PetBehaviorState.playing;
    return PetBehaviorState.calm;
  }

  /// Total anxiety score 0-100 for this packet
  int get anxietyScore {
    int score = 0;
    score += (strC * 8).clamp(0, 40);
    score += (paceD * 1.5).round().clamp(0, 30);
    score += (shivD * 2).clamp(0, 20);
    score += strD.clamp(0, 10);
    return score.clamp(0, 100);
  }

  /// Activity score 0-100
  int get activityScore {
    int score = 0;
    score += (playD * 2).clamp(0, 60);
    score += (rollC * 10).clamp(0, 30);
    score += (strC * 3).clamp(0, 10);
    return score.clamp(0, 100);
  }
}

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

/// Pet profile model
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

/// Feeding session — triggered when owner taps "Fed ZenBelly"
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
