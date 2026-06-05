// =============================================================================
// history_models.dart — /api/history 响应模型（P0-3）
// =============================================================================
// 对应 docs/CalmPaws_全景对接文档_给Cursor_v2.md §4.2、§5.2
// =============================================================================

/// 历史查询时间范围
class HistoryRange {
  HistoryRange._();

  static const String h24 = '24h';
  static const String d7 = '7d';
  static const String d30 = '30d';

  static const List<String> all = [h24, d7, d30];
}

class HistoryPoint {
  final int? time;
  final String? date;
  final double anxietyScore;
  final String dominantState;
  final Map<String, int> states;
  final int recordCount;
  final double batteryAvg;
  final int? onlineMinutes;
  final int? peakAnxiety;
  final int? minAnxiety;

  const HistoryPoint({
    this.time,
    this.date,
    required this.anxietyScore,
    required this.dominantState,
    this.states = const {},
    this.recordCount = 0,
    this.batteryAvg = 0,
    this.onlineMinutes,
    this.peakAnxiety,
    this.minAnxiety,
  });

  /// 24h：UTC unix 秒 → APP 本地时区（铁律 1）
  DateTime? get localDateTime => time == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(time! * 1000, isUtc: true).toLocal();

  /// 7d/30d：直接解析 date 字符串
  DateTime? get dateAsDateTime =>
      date == null ? null : DateTime.tryParse(date!);

  factory HistoryPoint.fromJson(Map<String, dynamic> json) {
    final statesRaw = json['states'];
    final states = <String, int>{};
    if (statesRaw is Map) {
      statesRaw.forEach((k, v) {
        if (v is num) states[k.toString()] = v.toInt();
      });
    }

    return HistoryPoint(
      time: _parseInt(json['time']),
      date: json['date'] as String?,
      anxietyScore: (_parseDouble(json['anxiety_score']) ?? 0.0).clamp(0.0, 100.0),
      dominantState: (json['dominant_state'] as String?) ?? 'calm',
      states: states,
      recordCount: _parseInt(json['record_count']) ?? 0,
      batteryAvg: _parseDouble(json['battery_avg']) ?? 0.0,
      onlineMinutes: _parseInt(json['online_minutes']),
      peakAnxiety: _parseInt(json['peak_anxiety']),
      minAnxiety: _parseInt(json['min_anxiety']),
    );
  }
}

class HistorySummary {
  final double avgAnxiety;
  final int peakAnxiety;
  final String dominantState;
  final int? onlineMinutes;
  final int? onlineSeconds;
  final int? heartbeatCount;
  final int? totalRecords;
  final double? onlineHoursTotal;
  final int? onlineMinutesTotal;
  final int? daysWithData;
  final int? daysTotal;

  const HistorySummary({
    required this.avgAnxiety,
    required this.peakAnxiety,
    required this.dominantState,
    this.onlineMinutes,
    this.onlineSeconds,
    this.heartbeatCount,
    this.totalRecords,
    this.onlineHoursTotal,
    this.onlineMinutesTotal,
    this.daysWithData,
    this.daysTotal,
  });

  factory HistorySummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const HistorySummary(
        avgAnxiety: 0,
        peakAnxiety: 0,
        dominantState: 'calm',
      );
    }
    return HistorySummary(
      avgAnxiety: (_parseDouble(json['avg_anxiety']) ?? 0.0).clamp(0.0, 100.0),
      peakAnxiety: _parseInt(json['peak_anxiety']) ?? 0,
      dominantState: (json['dominant_state'] as String?) ?? 'calm',
      onlineMinutes: _parseInt(json['online_minutes']),
      onlineSeconds: _parseInt(json['online_seconds']),
      heartbeatCount: _parseInt(json['heartbeat_count']),
      totalRecords: _parseInt(json['total_records']),
      onlineHoursTotal: _parseDouble(json['online_hours_total']),
      onlineMinutesTotal: _parseInt(json['online_minutes_total']),
      daysWithData: _parseInt(json['days_with_data']),
      daysTotal: _parseInt(json['days_total']),
    );
  }
}

class HistoryResponse {
  final String deviceId;
  final String range;
  final List<HistoryPoint> points;
  final HistorySummary summary;
  final int? from;
  final int? to;
  final int? days;
  final int? intervalSeconds;
  final String? error;

  const HistoryResponse({
    required this.deviceId,
    required this.range,
    required this.points,
    required this.summary,
    this.from,
    this.to,
    this.days,
    this.intervalSeconds,
    this.error,
  });

  bool get isSuccess => error == null;
  bool get hasPoints => points.isNotEmpty;

  factory HistoryResponse.empty(String deviceId, String range) => HistoryResponse(
        deviceId: deviceId,
        range: range,
        points: const [],
        summary: const HistorySummary(
          avgAnxiety: 0,
          peakAnxiety: 0,
          dominantState: 'calm',
        ),
      );

  factory HistoryResponse.error(String deviceId, String range, String message) =>
      HistoryResponse(
        deviceId: deviceId,
        range: range,
        points: const [],
        summary: const HistorySummary(
          avgAnxiety: 0,
          peakAnxiety: 0,
          dominantState: 'calm',
        ),
        error: message,
      );

  factory HistoryResponse.fromJson(
    Map<String, dynamic> json, {
    required String range,
  }) {
    final pointsRaw = json['points'];
    final points = <HistoryPoint>[];
    if (pointsRaw is List) {
      for (final item in pointsRaw) {
        if (item is Map<String, dynamic>) {
          points.add(HistoryPoint.fromJson(item));
        } else if (item is Map) {
          points.add(HistoryPoint.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final summaryRaw = json['summary'];
    final summary = summaryRaw is Map<String, dynamic>
        ? HistorySummary.fromJson(summaryRaw)
        : summaryRaw is Map
            ? HistorySummary.fromJson(Map<String, dynamic>.from(summaryRaw))
            : HistorySummary.fromJson(null);

    return HistoryResponse(
      deviceId: (json['device_id'] as String?) ?? '',
      range: range,
      points: points,
      summary: summary,
      from: _parseInt(json['from']),
      to: _parseInt(json['to']),
      days: _parseInt(json['days']),
      intervalSeconds: _parseInt(json['interval_seconds']),
    );
  }
}

int? _parseInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
