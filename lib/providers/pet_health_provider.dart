// =============================================================================
// pet_health_provider.dart — 宠物健康数据状态管理（核心业务 Provider）
// =============================================================================
// 职责：作为应用的全局状态中心，管理以下所有业务数据：
//   1. 宠物档案（PetProfile）：名称、品种、年龄、健康标签等
//   2. BLE 设备连接状态和实时数据流（MockBleService 模拟）
//   3. 喂食会话（FeedingSession）：开始/停止计时、记录历史
//   4. 焦虑/行为状态（AnxietyLevel、BehaviorState）：来自 BLE 数据
//   5. 健康日志（HealthLog）：用户手动记录的行为观察
//   6. 全局预警（Alert）：焦虑过高时触发横幅提醒
//
// ✅ 数据持久化架构（用户级别隔离）：
//   宠物档案通过 SharedPreferences 按 Firebase userId 隔离持久化。
//   • 用户 A 的宠物数据 key：pet_name_{uid_A}、pet_breed_{uid_A} ...
//   • 用户 B 的宠物数据 key：pet_name_{uid_B}、pet_breed_{uid_B} ...
//   这样不同账号登录后看到各自的宠物信息。
//
//   使用 loadPetForUser(userId) 在登录后加载数据，
//   updatePet() 保存时自动关联当前 userId。
//
//   首次登录（无已保存数据）：显示 Demo 数据（Biscuit），引导用户编辑。
//
// ⚠️ 重要架构说明：
//   喂食历史、健康日志等数据当前仍为内存数据，App 重启会还原。
//   [TODO: API 需求] 接入真实后端后，应在以下位置替换为 API 调用：
//     • 宠物档案：GET /api/pets/{userId} 获取，PUT /api/pets/{id} 保存
//     • 喂食历史：POST /api/feeding-sessions 创建，GET 获取历史
//     • 健康日志：POST /api/health-logs 保存
//     • BLE 数据：替换 MockBleService 为真实蓝牙 SDK（如 flutter_blue_plus）
//
//   [TODO: 异常处理] 当前所有 BLE 数据为模拟值，真实 BLE 接入时需处理：
//     • 连接断开重连逻辑
//     • 数据异常值过滤
//     • 蓝牙权限请求（Android/iOS）
// =============================================================================
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/mock_ble_service.dart';
import '../services/firestore_service.dart';

class PetHealthProvider extends ChangeNotifier {
  // ── 当前已登录用户 ID（用于 SharedPreferences key 隔离）──────────────────
  // 未登录时为 null，loadPetForUser() 会在登录后设置
  String? _currentUserId;
  String? get currentUserId => _currentUserId;

  // ── Firestore 服务层实例 ──────────────────────────────────────────────────
  // 所有云端读写操作都通过此服务层，不直接调用 FirebaseFirestore SDK
  final _firestoreService = FirestoreService();

  // ── 数据加载状态 ──────────────────────────────────────────────────────────
  // UI 可根据此状态显示加载指示器或空状态提示
  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  // ── 宠物档案 ──────────────────────────────────────────────────────────────
  // 默认为 Demo 数据（Biscuit），作为首次登录用户未设置宠物时的占位。
  // 调用 loadPetForUser(userId) 后会替换为该用户保存的宠物数据。
  // Dashboard 和宠物页面顶部显示的是 pet.name（宠物名），不是 Firebase 用户名。
  //
  // [TODO: API 需求] 接入后端后替换为：GET /api/pets/{userId}
  //   返回格式：{ id, name, species, breed, ageMonths, weightKg, healthTags, createdAt }
  PetProfile _pet = PetProfile(
    id: 'pet_001',
    name: 'Biscuit',  // ← 首次登录 Demo 数据，用户可通过宠物页面编辑按钮修改
    species: 'dog',
    breed: 'Golden Retriever',
    ageMonths: 36,
    weightKg: 28.5,
    healthTags: const ['Separation Anxiety', 'Joint Stiffness'],
    createdAt: DateTime(2024, 1, 15),
  );
  PetProfile get pet => _pet;

  // ── 加载指定用户的宠物数据（登录后调用）────────────────────────────────────
  // 从 SharedPreferences 读取以 userId 为 key 前缀的宠物档案。
  // 首次登录（无已保存数据）：保持 Demo 数据 Biscuit，引导用户编辑。
  //
  // 调用时机：MainNavScreen 的 initState 中，Firebase 登录成功后立即调用。
  //
  // 业务逻辑：
  //   1. 保存 userId 供后续 updatePet / Firestore 写入使用
  //   2. 读取 SharedPreferences 中该用户的宠物档案
  //   3. 同时从 Firestore 加载历史喂食记录、日志、压力数据（云端数据）
  //   4. 本地 + 云端数据均加载完毕后触发 UI 刷新
  Future<void> loadPetForUser(String userId) async {
    _currentUserId = userId;
    try {
      final prefs = await SharedPreferences.getInstance();
      // SharedPreferences key 以 userId 为前缀，实现不同账号数据隔离
      final name = prefs.getString('pet_name_$userId');
      if (name != null && name.isNotEmpty) {
        // 该用户有已保存的宠物数据 → 从 SharedPreferences 恢复
        _pet = PetProfile(
          id: prefs.getString('pet_id_$userId') ?? 'pet_$userId',
          name: name,
          species: prefs.getString('pet_species_$userId') ?? 'dog',
          breed: prefs.getString('pet_breed_$userId') ?? '',
          ageMonths: prefs.getInt('pet_age_$userId') ?? 0,
          weightKg: prefs.getDouble('pet_weight_$userId') ?? 0.0,
          healthTags: prefs.getStringList('pet_tags_$userId') ?? [],
          createdAt: DateTime.tryParse(
                prefs.getString('pet_created_$userId') ?? '') ??
              DateTime.now(),
        );
        notifyListeners(); // 先刷新宠物档案（快速响应）
      }
      // 如果没有已保存数据（首次登录），保持默认 Demo 数据 Biscuit
    } catch (e) {
      // [TODO: 异常处理] SharedPreferences 读取失败（极少见，通常是系统级问题）
      debugPrint('loadPetForUser error: $e');
    }

    // 无论宠物档案是否加载成功，都并行加载云端历史数据
    // 这样喂食记录、日志、压力图表都能从 Firestore 恢复
    await _loadCloudHistory(userId);
  }

  // ── 清除用户数据（退出登录时调用）───────────────────────────────────────────
  // 重置宠物数据、喂食历史、日志为 Demo/空状态，清除 currentUserId。
  // 防止退出后下一个用户登录时短暂看到上一个用户的数据。
  void clearUserData() {
    _currentUserId = null;
    _pet = PetProfile(
      id: 'pet_001',
      name: 'Biscuit',
      species: 'dog',
      breed: 'Golden Retriever',
      ageMonths: 36,
      weightKg: 28.5,
      healthTags: const ['Separation Anxiety', 'Joint Stiffness'],
      createdAt: DateTime(2024, 1, 15),
    );
    // 清空云端数据的内存缓存，下次登录后重新从 Firestore 加载
    _sessionHistory.clear();
    _journalEntries.clear();
    // 重置压力图为 Demo 数据，下次登录后用真实数据覆盖
    _stressChartData = generateDailyStressChart();
    notifyListeners();
  }

  // ── 更新并持久化宠物档案 ─────────────────────────────────────────────────
  // 用户在宠物编辑弹窗保存后调用，更新内存并写入 SharedPreferences。
  // notifyListeners() 触发所有使用 context.watch<PetHealthProvider>() 的 Widget 重建，
  // Dashboard 和宠物页面的名字会立即更新。
  //
  // [TODO: API 需求] 接入后端后，额外调用：PUT /api/pets/{id}  body: updated.toJson()
  Future<void> updatePet(PetProfile updated) async {
    _pet = updated;
    notifyListeners(); // 先立即更新 UI，再异步保存（避免保存延迟导致 UI 卡顿）

    if (_currentUserId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final uid = _currentUserId!;
        // 以 userId 为 key 前缀保存，实现用户数据隔离
        await prefs.setString('pet_name_$uid', updated.name);
        await prefs.setString('pet_id_$uid', updated.id);
        await prefs.setString('pet_species_$uid', updated.species);
        await prefs.setString('pet_breed_$uid', updated.breed);
        await prefs.setInt('pet_age_$uid', updated.ageMonths);
        await prefs.setDouble('pet_weight_$uid', updated.weightKg);
        await prefs.setStringList('pet_tags_$uid', updated.healthTags);
        await prefs.setString(
            'pet_created_$uid', updated.createdAt.toIso8601String());
      } catch (e) {
        // [TODO: 异常处理] SharedPreferences 写入失败（极少见）
        // 内存已更新，UI 正常，但下次重启 App 数据会丢失
        debugPrint('updatePet save error: $e');
      }
    }
  }

  // ── BLE 设备连接与实时数据流 ───────────────────────────────────────────────
  // 当前使用 MockBleService 模拟蓝牙数据，每秒推送一次 BlePacket。
  // [TODO] 正式接入真实硬件时，替换 MockBleService 为实际 BLE SDK（如 flutter_blue_plus）。
  // 替换要点：
  //   1. connectDevice() 中改为扫描并连接指定 UUID 的 BLE 外设
  //   2. _onPacket() 中解析真实设备的字节数据为 BlePacket 对象
  //   3. 需在 AndroidManifest.xml / Info.plist 添加蓝牙权限声明
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
    // 启动 BLE 数据流，订阅 stream → 每个数据包触发 _onPacket
    // 构造函数中自动调用，模拟设备上线
    _ble.start();
    _deviceConnected = true;
    _bleSub = _ble.stream.listen(_onPacket);
    notifyListeners();
  }

  void disconnectDevice() {
    // 停止 BLE 数据流，取消订阅，UI 显示设备离线状态
    _ble.stop();
    _bleSub?.cancel();
    _deviceConnected = false;
    notifyListeners();
  }

  // 每收到一个 BLE 数据包就调用一次（约每秒一次）
  // 负责：更新电量、保存历史包、检查预警、更新喂食会话
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

  // ── 喂食会话（FeedingSession）────────────────────────────────────────────
  // 已接入 Firestore：会话结束后自动保存云端，登录时自动加载历史。
  //
  // [API 需求] Firestore 路径：users/{uid}/feeding_sessions/{sessionId}
  //   文档字段：feed_time, time_to_calm, stress_before, stress_after, created_at
  //
  // 喂食完成回调（供 MainNavScreen 监听以写入通知中心）
  // 设计原则：PetHealthProvider 不直接持有 NotificationProvider（避免循环依赖）
  //   而是通过回调将事件转发给外部（MainNavScreen），由外部写入通知
  // 回调参数：已完成的 FeedingSession 对象
  void Function(FeedingSession)? onFeedingCompleted;

  FeedingSession? _activeSession;
  final List<FeedingSession> _sessionHistory = [];
  Timer? _sessionTimer;
  int _sessionElapsedSeconds = 0;

  FeedingSession? get activeSession => _activeSession;
  List<FeedingSession> get sessionHistory =>
      List.unmodifiable(_sessionHistory);
  int get sessionElapsedSeconds => _sessionElapsedSeconds;

  // 用户点击「已喂食」按钮时调用
  // 业务逻辑：记录喂食前的压力值，开始计时，每秒更新 UI，
  //           检测到连续平静状态后自动结束（Time-to-Calm 指标核心逻辑）
  // [TODO: API 需求] 喂食事件应实时同步到后端：
  //   POST /api/feeding-sessions { petId, feedTime, stressCountBefore }
  //   会话结束后 PATCH /api/feeding-sessions/{id} { timeToCalm, stressCountAfter }
  void startFeedingSession() {
    if (_activeSession != null) return; // 防止重复开始

    // 记录喂食前的压力计数，用于事后对比改善效果
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

      // 自动完成：宠物持续平静 且 已喂食超过 2 分钟 → 记录 Time-to-Calm
      // _isCalmState() 判断条件：无压力事件 + 徘徊次数低 + 无颤抖
      if (_activeSession != null && _isCalmState() && _sessionElapsedSeconds > 120) {
        _completeFeedingSession();
      }

      // 安全超时：90 分钟后强制结束，防止用户忘记停止导致计时无限增长
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

    // 1. 先更新内存，UI 立即刷新
    _sessionHistory.insert(0, completed);
    _activeSession = null;
    notifyListeners();

    // 2. 异步保存到 Firestore（不阻塞 UI）
    // 业务意义：喂食记录持久化后，用户换手机登录仍能看到完整的 Time-to-Calm 趋势
    if (_currentUserId != null) {
      _firestoreService.saveFeedingSession(_currentUserId!, completed);
      // 同时更新今天的压力数据点，让趋势图反映最新喂食效果
      _saveTodayStressPoint();
    }

    // 3. 触发喂食完成回调（通知 MainNavScreen 写入通知中心）
    // 回调由 MainNavScreen.initState 注册，PetHealthProvider 不感知 NotificationProvider
    onFeedingCompleted?.call(completed);
  }

  // 将今天的实时压力数据保存为一个 DailyStressDataPoint 写入 Firestore
  // 调用时机：喂食会话结束后，确保当天数据有最新的喂食后压力状态
  void _saveTodayStressPoint() {
    if (_currentUserId == null) return;
    final today = DateTime.now();
    final dayOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        [today.weekday - 1];
    final point = DailyStressDataPoint(
      dayIndex: 0, // 0 = 今天
      stressScore: currentAnxietyScore.toDouble(),
      isAfterTreatment: _sessionHistory.isNotEmpty,
      label: dayOfWeek,
    );
    _firestoreService.saveDailyStressPoint(_currentUserId!, point, today);
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

  // ── 全局预警系统 ────────────────────────────────────────────────────────────
  // 当 BLE 数据超过阈值时，设置 _hasAlert=true，MainNavScreen 顶部显示 AlertBanner。
  // 预警类型：
  //   'shiver'   → 宠物连续颤抖超过 30 秒（可能痛苦/寒冷/恐惧）
  //   'activity' → 白天活动量过低（可能生病）
  // 用户点击关闭按钮 → dismissAlert() 清除，直到下次 BLE 数据再次触发
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
    // 颤抖预警：持续颤抖超过 30 秒触发
    // [TODO: 异常处理] 当前每个数据包都可能重复触发，建议加入冷却时间（如 5 分钟内只触发一次）
    if (packet.shivD > 30) {
      _hasAlert = true;
      _alertType = 'shiver';
      _alertMessage =
          '⚠️ ${_pet.name} has been shivering for over ${packet.shivD}s. Check for pain, cold, or fear.';
      notifyListeners();
    }
    // 活动量预警：仅在白天（10:00-20:00）检查，避免夜间睡眠误报
    // [TODO: 异常处理] activityScore < 10 的阈值是经验值，应根据宠物品种/年龄动态调整
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

  // ── 健康日志（主人手动记录）────────────────────────────────────────────────
  // 用户在 Dashboard 的「快速记录」卡片填写后调用 addJournalEntry。
  // 已接入 Firestore：新增立即写入云端，登录时从云端加载历史。
  //
  // [API 需求] Firestore 路径：users/{uid}/journal_entries/{entryId}
  //   文档字段：date, stool_emoji, mood_emoji, appetite_emoji, energy_emoji,
  //             notes, negative_flags, created_at
  final List<JournalEntry> _journalEntries = [];
  List<JournalEntry> get journalEntries =>
      List.unmodifiable(_journalEntries);

  // 用户提交健康日志时调用
  // 业务逻辑：
  //   1. 先更新内存（UI 立即响应，不等网络）
  //   2. 异步写入 Firestore（失败静默处理，下次登录时数据可能丢失）
  // [TODO: 异常处理] 写入失败时可加本地队列，离线时缓存，联网后重试
  Future<void> addJournalEntry(JournalEntry entry) async {
    // 最新记录插入列表头部，UI 显示时自然按时间倒序
    _journalEntries.insert(0, entry);
    notifyListeners(); // 先刷新 UI，让用户感知立即保存成功

    // 异步持久化到 Firestore（不 await，不阻塞 UI）
    if (_currentUserId != null) {
      _firestoreService.saveJournalEntry(_currentUserId!, entry);
    }
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

  // ── 构造函数 ──────────────────────────────────────────────────────────────
  // 初始化时只启动 BLE 模拟数据流和生成 Demo 压力图。
  // 历史数据（喂食/日志）不在构造函数加载，而是在 loadPetForUser() 中按用户加载，
  // 避免未登录时请求 Firestore 触发权限错误。
  //
  // [TODO] 生产版本 connectDevice() 应改为：
  //   1. 检查蓝牙权限（permission_handler）
  //   2. 扫描指定 UUID 的 BLE 设备
  //   3. 连接成功后开始数据流
  PetHealthProvider() {
    _stressChartData = generateDailyStressChart(); // 生成 14 天 Demo 压力曲线（登录后会被云端数据覆盖）
    _seedHistoricalSessions();                      // 注入 Demo 历史数据（未登录时的占位，登录后清空）
    connectDevice();                                // 启动 BLE 模拟数据流
  }

  // 注入 Demo 历史数据（喂食记录 + 健康日志），让未登录 / 首次登录时图表有内容展示
  // 登录成功后 loadPetForUser() 会调用 _loadCloudHistory()，用真实数据覆盖这些 Demo 数据
  // [TODO] 正式上线后可考虑移除 Demo 数据，改为空状态 + 引导提示
  void _seedHistoricalSessions() {
    // 3 条历史喂食记录，用于 Time-to-Calm 图表和喂食历史页面展示
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

  // ── 从 Firestore 加载该用户的历史云端数据 ────────────────────────────────
  // 调用时机：loadPetForUser() 确认用户登录后调用
  //
  // 加载策略（顺序执行，独立容错）：
  //   1. 加载喂食历史（最近 30 条）
  //   2. 加载健康日志（最近 60 条）
  //   3. 加载压力趋势数据（最近 14 天）
  //   4. 任何一步失败都不影响其他步骤，失败时保留 Demo 数据
  //
  // [TODO: 异常处理] 当前网络失败时静默降级到 Demo 数据。
  //   可在此处设置 _isLoadingHistory = false 并通知 UI 显示离线提示。
  Future<void> _loadCloudHistory(String uid) async {
    _isLoadingHistory = true;
    notifyListeners(); // 触发 UI 显示加载状态（如有加载指示器）

    try {
      // ── 并发加载三类数据，减少总等待时间 ──
      final results = await Future.wait([
        _firestoreService.loadFeedingSessions(uid, limit: 30),
        _firestoreService.loadJournalEntries(uid, limit: 60),
        _firestoreService.loadDailyStressPoints(uid, days: 14),
      ]);

      final sessions = results[0] as List<FeedingSession>;
      final journals = results[1] as List<JournalEntry>;
      final stressPoints = results[2] as List<DailyStressDataPoint>;

      // 有云端数据时：用云端数据替换 Demo 数据
      // 没有云端数据时（新用户）：保留 Demo 数据让界面不空白
      if (sessions.isNotEmpty) {
        _sessionHistory
          ..clear()
          ..addAll(sessions);
      }
      if (journals.isNotEmpty) {
        _journalEntries
          ..clear()
          ..addAll(journals);
      }
      if (stressPoints.isNotEmpty) {
        _stressChartData = stressPoints;
      }
    } catch (e) {
      // [TODO: 异常处理] 加载失败时保留 Demo 数据，可在 UI 显示「数据加载失败，显示演示数据」
      debugPrint('_loadCloudHistory error: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners(); // 数据加载完成，触发 UI 刷新
    }
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _sessionTimer?.cancel();
    _ble.stop();
    super.dispose();
  }
}
