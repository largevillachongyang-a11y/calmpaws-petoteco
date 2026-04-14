import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/mock_ble_service.dart';

class PetHealthProvider extends ChangeNotifier {
  // ── Pet Profile ──────────────────────────────────────────────────────────
  PetProfile _pet = PetProfile(
    id: 'pet_001',
    name: 'Biscuit',
    species: 'dog',
    breed: 'Golden Retriever',
    ageMonths: 36,
    weightKg: 28.5,
    healthTags: const ['Separation Anxiety', 'Joint Stiffness'],
    createdAt: DateTime(2024, 1, 15),
  );
  PetProfile get pet => _pet;

  void updatePet(PetProfile updated) {
    _pet = updated;
    notifyListeners();
  }

  // ── BLE / Device ─────────────────────────────────────────────────────────
  final _ble = MockBleService();
  StreamSubscription<BlePacket>? _bleSub;
  BlePacket? _latestPacket;
  bool _deviceConnected = false;
  int _battery = 82;
  final List<BlePacket> _recentPackets = [];

  BlePacket? get latestPacket => _latestPacket;
  bool get deviceConnected => _deviceConnected;
  int get battery => _battery;
  List<BlePacket> get recentPackets => List.unmodifiable(_recentPackets);

  double get anxietyLevel => _ble.anxietyLevel;
  set anxietyLevel(double v) {
    _ble.anxietyLevel = v;
    notifyListeners();
  }

  void connectDevice() {
    _ble.start();
    _deviceConnected = true;
    _bleSub = _ble.stream.listen(_onPacket);
    notifyListeners();
  }

  void disconnectDevice() {
    _ble.stop();
    _bleSub?.cancel();
    _deviceConnected = false;
    notifyListeners();
  }

  void _onPacket(BlePacket packet) {
    _latestPacket = packet;
    _battery = packet.battery;
    _recentPackets.add(packet);
    if (_recentPackets.length > 120) {
      _recentPackets.removeAt(0); // keep last 10 minutes
    }
    _checkAlerts(packet);
    _updateFeedingSession(packet);
    notifyListeners();
  }

  // ── Feeding Session & Time-to-Calm ────────────────────────────────────────
  FeedingSession? _activeSession;
  final List<FeedingSession> _sessionHistory = [];
  Timer? _sessionTimer;
  int _sessionElapsedSeconds = 0;

  FeedingSession? get activeSession => _activeSession;
  List<FeedingSession> get sessionHistory =>
      List.unmodifiable(_sessionHistory);
  int get sessionElapsedSeconds => _sessionElapsedSeconds;

  /// Owner taps the "Fed ZenBelly" button
  void startFeedingSession() {
    if (_activeSession != null) return;

    // Record stress count right before feeding
    final preStress = _latestPacket?.strC ?? 0;

    _activeSession = FeedingSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      feedTime: DateTime.now(),
      stressCountBefore: preStress,
      timeline: [],
    );
    _sessionElapsedSeconds = 0;

    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _sessionElapsedSeconds++;
      notifyListeners();

      // Auto-complete if pet has been calm for 5 minutes
      if (_activeSession != null && _isCalmState() && _sessionElapsedSeconds > 120) {
        _completeFeedingSession();
      }

      // Auto-timeout after 90 minutes
      if (_sessionElapsedSeconds >= 5400) {
        _completeFeedingSession();
      }
    });

    notifyListeners();
  }

  void _completeFeedingSession() {
    if (_activeSession == null) return;
    _sessionTimer?.cancel();

    final postStress = _latestPacket?.strC ?? 0;
    final completed = _activeSession!.copyWith(
      timeToCalm: _sessionElapsedSeconds,
      stressCountAfter: postStress,
    );
    _sessionHistory.insert(0, completed);
    _activeSession = null;
    notifyListeners();
  }

  void cancelFeedingSession() {
    _sessionTimer?.cancel();
    _activeSession = null;
    _sessionElapsedSeconds = 0;
    notifyListeners();
  }

  bool _isCalmState() {
    final p = _latestPacket;
    if (p == null) return false;
    return p.strC == 0 && p.paceD < 5 && p.shivC == 0;
  }

  void _updateFeedingSession(BlePacket packet) {
    if (_activeSession == null) return;
    // Record snapshot every 5 minutes
    final minutes = _sessionElapsedSeconds ~/ 60;
    if (minutes > 0 && _sessionElapsedSeconds % 300 == 0) {
      final snapshot = BehaviorSnapshot(
        minutesAfterFeed: minutes,
        state: packet.behaviorState,
        anxietyScore: packet.anxietyScore,
      );
      final updated = _activeSession!.copyWith(
        timeline: [..._activeSession!.timeline, snapshot],
      );
      _activeSession = updated;
    }
  }

  String get sessionElapsedLabel {
    final m = _sessionElapsedSeconds ~/ 60;
    final s = _sessionElapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Alerts ────────────────────────────────────────────────────────────────
  bool _hasAlert = false;
  String _alertMessage = '';
  String _alertType = ''; // 'shiver' | 'activity'

  bool get hasAlert => _hasAlert;
  String get alertMessage => _alertMessage;
  String get alertType => _alertType;

  void dismissAlert() {
    _hasAlert = false;
    notifyListeners();
  }

  void _checkAlerts(BlePacket packet) {
    if (packet.shivD > 30) {
      _hasAlert = true;
      _alertType = 'shiver';
      _alertMessage =
          '⚠️ ${_pet.name} has been shivering for over ${packet.shivD}s. Check for pain, cold, or fear.';
      notifyListeners();
    }
    if (packet.activityScore < 10 && DateTime.now().hour >= 10 &&
        DateTime.now().hour < 20) {
      _hasAlert = true;
      _alertType = 'activity';
      _alertMessage =
          "⚠️ ${_pet.name}'s activity is 30% below normal. Consider a vet check.";
      notifyListeners();
    }
  }

  // ── Daily Summary & Charts ────────────────────────────────────────────────
  late List<DailyStressDataPoint> _stressChartData;
  int _baselineDaysRemaining = 0; // 0 = baseline complete

  List<DailyStressDataPoint> get stressChartData => _stressChartData;
  int get baselineDaysRemaining => _baselineDaysRemaining;
  bool get isBaselineLearning => _baselineDaysRemaining > 0;

  // Pre-computed session history (for last feeding display)
  int? get lastTimeToCalmSeconds {
    if (_sessionHistory.isEmpty) return null;
    return _sessionHistory.first.timeToCalm;
  }

  String get lastTimeToCalmLabel {
    final s = lastTimeToCalmSeconds;
    if (s == null) return '--';
    if (s < 60) return '${s}s';
    return '${s ~/ 60}m ${s % 60}s';
  }

  // ── Journal ───────────────────────────────────────────────────────────────
  final List<JournalEntry> _journalEntries = [];
  List<JournalEntry> get journalEntries =>
      List.unmodifiable(_journalEntries);

  void addJournalEntry(JournalEntry entry) {
    _journalEntries.insert(0, entry);
    notifyListeners();
  }

  // ── 健康日历：生成最近 N 天的 DailyRecord 列表 ────────────────────────────
  // 规则：
  //   - sensorSummary 来自 stressChartData（14 天历史）+ 今日实时数据
  //   - journalEntry  来自 _journalEntries，按日期匹配
  //   - 两层完全独立，不做合并计算
  List<DailyRecord> getDailyRecords({int days = 14}) {
    final today = DateTime.now();
    final records = <DailyRecord>[];

    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));

      // ── 传感器层：从历史 stressChartData 取（14天内）──
      SensorDaySummary? sensor;
      final chartIdx = (days - 1) - i; // 0 = 最早, days-1 = 今天
      if (chartIdx < _stressChartData.length) {
        final pt = _stressChartData[chartIdx];
        // 今天用实时数据补充
        final isToday = i == 0;
        final stressScore = isToday
            ? currentAnxietyScore.toDouble()
            : pt.stressScore;
        final activity = isToday
            ? currentActivityScore
            : (pt.stressScore < 40 ? 65 : 35); // 历史近似值

        // 匹配当天的喂食记录
        final feeding = _sessionHistory.where((s) {
          final d = s.feedTime;
          return d.year == date.year &&
              d.month == date.month &&
              d.day == date.day;
        }).toList();

        sensor = SensorDaySummary(
          avgStressScore: stressScore,
          stressEventCount: (stressScore / 12).round(),
          pacingMinutes: (stressScore / 3).round(),
          playMinutes: activity ~/ 2,
          activityScore: activity,
          hasFeeding: feeding.isNotEmpty,
          timeToCalmSecs: feeding.isNotEmpty ? feeding.first.timeToCalm : null,
        );
      }

      // ── 主人记录层：按日期精确匹配 ──
      JournalEntry? journal;
      for (final e in _journalEntries) {
        if (e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day) {
          journal = e;
          break;
        }
      }

      records.add(DailyRecord(
        date: date,
        sensorSummary: sensor,
        journalEntry: journal,
      ));
    }

    return records;
  }

  // ── Current behavior computed values ─────────────────────────────────────
  PetBehaviorState get currentBehavior =>
      _latestPacket?.behaviorState ?? PetBehaviorState.calm;

  int get currentAnxietyScore => _latestPacket?.anxietyScore ?? 0;
  int get currentActivityScore => _latestPacket?.activityScore ?? 0;

  /// Computed sleep quality from last night (mock: 72-88)
  int get lastNightSleepQuality => 78;

  /// Computed calm trend for today: positive = improving
  double get todayCalmTrend => -18.5; // % change vs yesterday

  // ── Initialization ────────────────────────────────────────────────────────
  PetHealthProvider() {
    _stressChartData = generateDailyStressChart();
    _seedHistoricalSessions();
    // Auto-start BLE mock
    connectDevice();
  }

  void _seedHistoricalSessions() {
    // Pre-populate 3 historical feeding sessions for demo purposes
    final now = DateTime.now();
    _sessionHistory.addAll([
      FeedingSession(
        id: 'session_hist_1',
        feedTime: now.subtract(const Duration(days: 1, hours: 2)),
        timeToCalm: 1680,
        stressCountBefore: 5,
        stressCountAfter: 1,
        timeline: [],
      ),
      FeedingSession(
        id: 'session_hist_2',
        feedTime: now.subtract(const Duration(days: 2, hours: 3)),
        timeToCalm: 1920,
        stressCountBefore: 7,
        stressCountAfter: 2,
        timeline: [],
      ),
      FeedingSession(
        id: 'session_hist_3',
        feedTime: now.subtract(const Duration(days: 3, hours: 2, minutes: 30)),
        timeToCalm: 2100,
        stressCountBefore: 8,
        stressCountAfter: 1,
        timeline: [],
      ),
    ]);

    // Seed journal entries
    _journalEntries.addAll([
      JournalEntry(
        id: 'j1',
        date: now.subtract(const Duration(days: 0)),
        stoolEmoji: '🟤',
        moodEmoji: '😌',
        appetiteEmoji: '🍖',
        energyEmoji: '⚡',
        notes: '晨间散步后状态不错，比较放松',
        negativeFlags: [],
      ),
      JournalEntry(
        id: 'j2',
        date: now.subtract(const Duration(days: 1)),
        stoolEmoji: '🟡',
        moodEmoji: '😰',
        appetiteEmoji: '😐',
        energyEmoji: '😴',
        notes: '雷雨天气有些不安，活动量偏少',
        negativeFlags: ['anxiety', 'low_appetite'],
      ),
    ]);
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _sessionTimer?.cancel();
    _ble.stop();
    super.dispose();
  }
}
