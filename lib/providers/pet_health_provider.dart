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
// ✅ P1 通知系统架构（六大硬件状态驱动通知）：
//   状态 D（发抖）→ 持续 3 分钟触发紧急预警（原30秒改为180秒）
//   状态 C（应激）→ 1 小时内 >10 次触发应激频繁通知
//   状态 F（昏睡）→ 白天连续静止 >3 小时触发药物昏睡检测通知
//   活力低于均值 → 连续 2 天才触发（避免误报）
//   喂食完成     → 记录 Time-to-Calm，写入通知中心
//   每日总结     → 每晚 20:00 汇总当日六大状态时长
//
//   通知回调（避免循环依赖）：
//   PetHealthProvider 不持有 NotificationProvider
//   而是通过回调（onAlert / onDailySummaryReady）转发事件
//   MainNavScreen 作中间层负责写入 NotificationProvider
//
// ⚠️ 重要架构说明：
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
  // P0-1三层加载策略：
  //   第1层：SharedPreferences（本地，毫秒级，最快）
  //   第2层：Firestore fallback（云端，换机恢复场景）
  //   第3层：Firestore 历史数据（喂食/日志/压力图）
  Future<void> loadPetForUser(String userId) async {
    _currentUserId = userId;
    bool loadedFromLocal = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('pet_name_$userId');
      if (name != null && name.isNotEmpty) {
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
        loadedFromLocal = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('loadPetForUser SharedPreferences error: $e');
    }

    // P0-1：未从本地读到时，尝试从 Firestore 拉取（换机恢复场景）
    if (!loadedFromLocal) {
      try {
        final cloudPet = await _firestoreService.loadPetProfile(userId);
        if (cloudPet != null && cloudPet.name.isNotEmpty) {
          _pet = cloudPet;
          // 回写到 SharedPreferences，后续本地读取加快
          await _savePetToLocal(userId, cloudPet);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('loadPetForUser Firestore fallback error: $e');
      }
    }

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
  // P0-1：同时写入 SharedPreferences（本地快速读取）和 Firestore（云端备份）
  // 返回 true = 云端写入成功；false = 云端写入失败（本地仍保存）
  Future<bool> updatePet(PetProfile updated) async {
    _pet = updated;
    notifyListeners();

    bool cloudSaved = false;
    if (_currentUserId != null) {
      final uid = _currentUserId!;
      try {
        await _savePetToLocal(uid, updated);
      } catch (e) {
        debugPrint('updatePet local save error: $e');
      }
      final err = await _firestoreService.savePetProfile(uid, updated);
      cloudSaved = (err == null);
      if (!cloudSaved) {
        debugPrint('⚠️ updatePet: Firestore write failed — $err');
      }
    }
    return cloudSaved;
  }

  /// 步骤1：立即更新内存 + 本地缓存（同步操作，不涉及网络）
  /// UI 层调用此方法后可立刻关闭对话框，用户体验流畅
  void updatePetLocal(PetProfile updated) {
    _pet = updated;
    notifyListeners();
    // 本地 SharedPreferences 写入（异步 fire-and-forget，不阻塞 UI）
    if (_currentUserId != null) {
      _savePetToLocal(_currentUserId!, updated).catchError((e) {
        debugPrint('updatePetLocal: local save error: $e');
      });
    }
  }

  /// 步骤2：后台同步到 Firestore（可在对话框关闭后调用）
  /// 返回 null = 成功；非 null 字符串 = 失败原因（permission-denied / network-error 等）
  Future<String?> syncPetToCloud() async {
    if (_currentUserId == null) return 'not-logged-in';
    try {
      final err = await _firestoreService
          .savePetProfile(_currentUserId!, _pet)
          .timeout(const Duration(seconds: 8));
      if (err != null) debugPrint('⚠️ syncPetToCloud failed: $err');
      return err; // null = 成功
    } catch (e) {
      final msg = e.toString();
      debugPrint('⚠️ syncPetToCloud error: $msg');
      return msg.contains('TimeoutException') ? 'timeout' : 'unknown: $msg';
    }
  }

  // 将宠物档案写入 SharedPreferences（内部辅助方法）
  Future<void> _savePetToLocal(String uid, PetProfile pet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pet_name_$uid', pet.name);
    await prefs.setString('pet_id_$uid', pet.id);
    await prefs.setString('pet_species_$uid', pet.species);
    await prefs.setString('pet_breed_$uid', pet.breed);
    await prefs.setInt('pet_age_$uid', pet.ageMonths);
    await prefs.setDouble('pet_weight_$uid', pet.weightKg);
    await prefs.setStringList('pet_tags_$uid', pet.healthTags);
    await prefs.setString('pet_created_$uid', pet.createdAt.toIso8601String());
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
  BlePacket? _latestPacket;   // 原始累计包（最新）
  BlePacket? _prevPacket;     // 原始累计包（上一包，用于差值计算）
  BlePacket? _deltaPacket;    // 差值包（本5秒内的行为增量，供UI/算法使用）
  bool _deviceConnected = false;
  int _battery = 82;
  final List<BlePacket> _recentPackets = [];

  // UI 层统一使用 deltaPacket（每5秒内增量），不使用原始累计包
  BlePacket? get latestPacket => _deltaPacket;
  // 如需原始累计值（例如图表趋势），可使用此 getter
  BlePacket? get rawCumulativePacket => _latestPacket;
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

  // 每收到一个 BLE 数据包就调用一次（每5秒一次）
  // 硬件传来的是【累计值】，需要计算差值后再做行为判断
  // 负责：更新电量、计算差值包、保存历史包、检查预警、更新喂食会话
  void _onPacket(BlePacket rawPacket) {
    _battery = rawPacket.battery;

    // ── 计算差值包（本5秒内的行为增量）──────────────────────────────────
    // 如果是第一包，差值包就是原始包本身（开机后第一个5秒）
    final delta = _latestPacket != null
        ? BlePacket.deltaFrom(rawPacket, _latestPacket!)
        : rawPacket;

    // 更新累计包记录
    _prevPacket = _latestPacket;
    _latestPacket = rawPacket;
    _deltaPacket = delta;

    // 历史缓冲：存差值包（每包代表5秒内实际行为，便于回放分析）
    _recentPackets.add(delta);
    if (_recentPackets.length > 120) {
      _recentPackets.removeAt(0); // keep last 10 minutes
    }

    // 预警检测和喂食更新都用差值包
    _checkAlerts(delta);
    _updateFeedingSession(delta);
    notifyListeners();
  }

  // ── 喂食会话（FeedingSession）────────────────────────────────────────────
  // 已接入 Firestore：会话结束后自动保存云端，登录时自动加载历史。
  //
  // [API 需求] Firestore 路径：users/{uid}/feeding_sessions/{sessionId}
  //   文档字段：feed_time, time_to_calm, stress_before, stress_after, created_at
  //
  // ── 通知回调机制（避免循环依赖）──────────────────────────────────────────
  // PetHealthProvider 不直接持有 NotificationProvider
  // 而是通过回调将事件转发给外部（MainNavScreen），由外部写入通知

  // 喂食完成回调：参数为已完成的 FeedingSession 对象
  void Function(FeedingSession)? onFeedingCompleted;

  // P1 通知回调：参数为 (type, title, body)
  // type：'shiver_alert' | 'stress_frequent' | 'lethargy' | 'activity_low'
  void Function(String type, String title, String body)? onAlertNotification;

  // 每日总结回调：参数为总结数据 Map
  void Function(DailyHealthSummaryData)? onDailySummaryReady;

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

    // 记录喂食前的压力计数（用最近一包的差值包，代表最新5秒内的应激次数）
    final preStress = _deltaPacket?.strC ?? 0;

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

    final postStress = _deltaPacket?.strC ?? 0;
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
    // 使用差值包判断：本5秒内无应激、无踱步、无发抖
    final p = _deltaPacket;
    if (p == null) return false;
    return p.strC == 0 && p.paceD < 3 && p.shivC == 0;
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
  //
  // P1 完整预警规则（对齐硬件需求文档）：
  //   'shiver'        → 状态D：宠物连续发抖 >3分钟（180秒）触发紧急预警
  //   'stress_frequent'→ 状态C：1小时内应激动作 >10次触发
  //   'lethargy'      → 状态F：白天（10:00-18:00）连续静止 >3小时触发昏睡检测
  //   'activity'      → A+B+C 总活动量低于7日均值30%（连续2天）
  //
  // 用户点击关闭按钮 → dismissAlert() 清除，直到下次 BLE 数据再次触发
  bool _hasAlert = false;
  String _alertMessage = '';
  String _alertType = ''; // 'shiver' | 'stress_frequent' | 'lethargy' | 'activity'

  bool get hasAlert => _hasAlert;
  String get alertMessage => _alertMessage;
  String get alertType => _alertType;
  // Bug1修复：暴露给 MainNavScreen 用于本地化横幅文案
  int get continuousShiverSeconds => _continuousShiverSeconds;

  // ── P1：发抖持续时长追踪 ───────────────────────────────────────────────────
  // 文档定义：状态D = 近1g + 高频小幅颤抖，单次持续 >3分钟 → 触发紧急预警
  int _continuousShiverSeconds = 0;    // 当前连续发抖秒数（BlePacket 每5秒一包，累计计算）
  bool _shiverAlertFired = false;      // 本次连续发抖是否已触发通知（避免重复）
  // ── P1 测试阈值（开发期降低便于快速验证）────────────────────────────────
  // 发抖：改为 30 秒（原 180 秒），anxietyLevel=1.0 约 2-3 分钟自然触发
  static const int kShiverThreshold = 30;   // 正式上线改回 180
  // 应激频繁：改为 3 次（原 10 次），焦虑滑块拉满约 1 分钟触发
  static const int kStressFreqThreshold = 3; // 正式上线改回 10
  // 昏睡：改为 60 秒（原 10800 秒），便于测试
  static const int kLethargyThreshold = 60;  // 正式上线改回 10800

  // ── P1：应激动作频次追踪（状态C）──────────────────────────────────────────
  // 文档定义：状态C = 高频短促爆发（1.5-2.0g），1小时内 >10次 → 触发通知
  final List<DateTime> _stressEventTimestamps = []; // 近1小时内的应激事件时间戳列表
  bool _stressFreqAlertFired = false;              // 本小时是否已触发（避免重复，每小时重置）

  // ── P1：昏睡检测（状态F）──────────────────────────────────────────────────
  // 文档定义：状态F = 扁平1g线 + Z轴静止数小时，白天 >3小时 → 触发药物/异常昏睡通知
  int _continuousLethargySecs = 0;       // 当前连续静止（类F状态）秒数
  bool _lethargyAlertFired = false;      // 今日是否已触发昏睡通知（每天只触发一次）
  DateTime? _lethargyAlertDate;          // 记录触发日期，次日清零

  // ── P1：每日健康总结定时器 ─────────────────────────────────────────────────
  // 每天 20:00 检查一次，若未推送则生成当日健康总结通知
  Timer? _dailySummaryTimer;
  DateTime? _lastDailySummaryDate; // 记录上次推送日期，避免同一天重复推送

  // ── P1：今日各状态时长累计（供每日总结使用）──────────────────────────────
  // 每次 BLE 包时累加（每包=5秒的采样）
  int _todayPacingSeconds    = 0; // 状态A：踱步
  int _todayPlaySeconds      = 0; // 状态B：健康玩耍
  int _todayStressSeconds    = 0; // 状态C：应激动作
  int _todayShiverSeconds    = 0; // 状态D：发抖
  int _todaySleepSeconds     = 0; // 状态E：健康睡眠
  int _todayLethargySeconds  = 0; // 状态F：昏睡/静止
  DateTime _todayStatsDate   = DateTime.now(); // 当前统计日期，跨天时重置

  // 供 UI 和每日总结读取
  int get todayPacingSeconds   => _todayPacingSeconds;
  int get todayPlaySeconds     => _todayPlaySeconds;
  int get todayStressSeconds   => _todayStressSeconds;
  int get todayShiverSeconds   => _todayShiverSeconds;
  int get todaySleepSeconds    => _todaySleepSeconds;
  int get todayLethargySeconds => _todayLethargySeconds;

  void dismissAlert() {
    _hasAlert = false;
    notifyListeners();
  }

  // 每收到一个 BLE 包时：
  //   1. 累加今日各状态时长（每包约5秒）
  //   2. 追踪连续发抖（D状态）/ 昏睡（F状态）
  //   3. 统计应激（C状态）频次
  //   4. 超阈值时触发预警并通过回调通知中心
  void _checkAlerts(BlePacket packet) {
    final now = DateTime.now();
    // 跨天重置今日统计
    _resetTodayStatsIfNewDay(now);

    // ── 今日状态时长累计（每包约5秒）──────────────────────────────────────
    const int samplingInterval = 5;
    final state = packet.behaviorState;
    switch (state) {
      case PetBehaviorState.pacing:
        _todayPacingSeconds   += samplingInterval;
      case PetBehaviorState.playing:
        _todayPlaySeconds     += samplingInterval;
      case PetBehaviorState.stressed:
        _todayStressSeconds   += samplingInterval;
      case PetBehaviorState.shivering:
        _todayShiverSeconds   += samplingInterval;
      case PetBehaviorState.sleeping:
        _todaySleepSeconds    += samplingInterval;
      default:
        // calm → 如果是白天且近乎静止（activityScore极低），计入昏睡候选
        if (packet.activityScore < 3) {
          _todayLethargySeconds += samplingInterval;
        }
    }

    // ── P1-1：发抖预警（状态D，阈值3分钟 = 180秒）─────────────────────────
    if (packet.shivD > 0) {
      // BLE 包含发抖时长字段，直接累加
      _continuousShiverSeconds += samplingInterval;
    } else {
      // 无发抖则重置连续计时（可接受短暂中断 ≤10秒）
      _continuousShiverSeconds = 0;
      _shiverAlertFired = false; // 连续中断后允许下次重新触发
    }

    if (_continuousShiverSeconds >= kShiverThreshold && !_shiverAlertFired) {
      _shiverAlertFired = true;
      _hasAlert = true;
      _alertType = 'shiver';
      final minutesDuration = _continuousShiverSeconds ~/ 60;
      _alertMessage = '🆘 ${_pet.name} 已连续发抖 $minutesDuration 分钟，请立即检查是否疼痛、受寒或极度恐惧。';
      notifyListeners();
      // 回调通知中心
      onAlertNotification?.call(
        'shiver_alert',
        '🆘 紧急：${_pet.name} 持续发抖超过3分钟',
        '已连续发抖 $minutesDuration 分钟。可能原因：疼痛、低体温或极度恐惧。建议立即检查或联系兽医。',
      );
    }

    // ── P1-2：应激动作频繁（状态C，1小时内 >10次）────────────────────────
    if (packet.strC > 0) {
      // 每个 BLE 包的 strC 字段记录本周期应激次数，加入时间戳队列
      for (int i = 0; i < packet.strC; i++) {
        _stressEventTimestamps.add(now);
      }
    }
    // 清除超过1小时的旧记录
    _stressEventTimestamps.removeWhere(
        (t) => now.difference(t).inHours >= 1);

    final recentStressCount = _stressEventTimestamps.length;
    if (recentStressCount > kStressFreqThreshold && !_stressFreqAlertFired) {
      _stressFreqAlertFired = true;
      // Bug4修复：同时设置顶部横幅
      _hasAlert = true;
      _alertType = 'stress_frequent';
      _alertMessage = '⚠️ ${_pet.name} stress actions >10x in past hour';
      notifyListeners();
      onAlertNotification?.call(
        'stress_frequent',
        '⚠️ ${_pet.name} 今日应激反应频繁',
        '过去1小时内检测到 $recentStressCount 次应激动作（状态C）。'
        '建议查看是否有焦虑源，考虑增加益生素用量或减少环境刺激。',
      );
    }
    // 每整点重置，允许下一小时再次触发
    if (now.minute == 0 && now.second < 10) {
      _stressFreqAlertFired = false;
    }

    // ── P1-4：昏睡检测（状态F，白天连续静止 >3小时）─────────────────────
    // 白天时段：10:00–18:00；状态判断：activityScore < 3 + 无发抖 + 无应激
    final isDaytime = now.hour >= 10 && now.hour < 18;
    final isLethargyLike = packet.activityScore < 3 &&
        packet.shivD == 0 &&
        packet.strC == 0 &&
        packet.paceD == 0;

    if (isDaytime && isLethargyLike) {
      _continuousLethargySecs += samplingInterval;
    } else {
      // 有活动则重置
      _continuousLethargySecs = 0;
    }

    // 检查是否今天已触发（每天只触发一次）
    final todayDate = DateTime(now.year, now.month, now.day);
    if (_lethargyAlertDate != null) {
      final alertDay = DateTime(
          _lethargyAlertDate!.year, _lethargyAlertDate!.month, _lethargyAlertDate!.day);
      if (alertDay != todayDate) {
        _lethargyAlertFired = false; // 新的一天，允许再次触发
      }
    }

    if (_continuousLethargySecs >= kLethargyThreshold &&
        isDaytime &&
        !_lethargyAlertFired) {
      _lethargyAlertFired = true;
      _lethargyAlertDate = now;
      final hours = _continuousLethargySecs ~/ 3600;
      // Bug4修复：同时设置顶部横幅
      _hasAlert = true;
      _alertType = 'lethargy';
      _alertMessage = '⚠️ ${_pet.name} unusually still all day — possible lethargy';
      notifyListeners();
      onAlertNotification?.call(
        'lethargy',
        '⚠️ ${_pet.name} 白天异常静止（疑似昏睡）',
        '白天已连续静止超过 $hours 小时（状态F）。'
        '请注意区分健康睡眠与药物引起的昏睡，如异常请停药并联系兽医。',
      );
    }

    // ── 传统活动量预警（保留，仅白天时段）────────────────────────────────
    // 优先级最低：只有当前没有更高优先级预警时才设置 activity 横幅
    // 高优先级顺序：shiver > stress_frequent > lethargy > activity
    final highPriorityAlerts = ['shiver', 'stress_frequent', 'lethargy'];
    if (packet.activityScore < 10 && isDaytime) {
      if (!_hasAlert || _alertType == 'activity') {
        // 不覆盖更高优先级的预警横幅
        if (!highPriorityAlerts.contains(_alertType)) {
          _hasAlert = true;
          _alertType = 'activity';
          // UI层(main_nav_screen)会根据语言重新生成文案，此处仅作fallback
          _alertMessage = '⚠️ ${_pet.name} 今日活动量偏低';
          notifyListeners();
        }
      }
    }
  }

  // 跨天时重置今日统计数据
  void _resetTodayStatsIfNewDay(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final statDay = DateTime(
        _todayStatsDate.year, _todayStatsDate.month, _todayStatsDate.day);
    if (today != statDay) {
      _todayPacingSeconds   = 0;
      _todayPlaySeconds     = 0;
      _todayStressSeconds   = 0;
      _todayShiverSeconds   = 0;
      _todaySleepSeconds    = 0;
      _todayLethargySeconds = 0;
      _todayStatsDate       = now;
      _stressFreqAlertFired = false;
      _shiverAlertFired     = false;
      _continuousShiverSeconds  = 0;
      _continuousLethargySecs   = 0;
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
  // ⚠️ 全部使用差值包（_deltaPacket），而非原始累计包（_latestPacket）
  // behaviorState / anxietyScore / activityScore 都定义在 BlePacket 上，
  // 它们的计算阈值已针对"5秒内增量"调整，不能用累计值调用。
  PetBehaviorState get currentBehavior =>
      _deltaPacket?.behaviorState ?? PetBehaviorState.calm;

  int get currentAnxietyScore => _deltaPacket?.anxietyScore ?? 0;
  int get currentActivityScore => _deltaPacket?.activityScore ?? 0;

  /// 昨夜睡眠质量：根据夜间（22:00-06:00）的行为数据推算
  /// 逻辑：睡眠秒数越多、应激秒数越少 → 质量越高
  /// 目前为近似算法，正式版应改为夜间专项分析
  int get lastNightSleepQuality {
    // 今日睡眠时长得分（满分70）：累计到6小时以上得满分
    const maxSleepSecs = 6 * 3600;
    final sleepScore = (_todaySleepSeconds / maxSleepSecs * 70).clamp(0, 70).round();
    // 应激扣分（每分钟应激扣2分，最多扣30）
    final stressPenalty = (_todayStressSeconds / 60 * 2).clamp(0, 30).round();
    // 基础分30（确保即使无数据也有合理显示）
    final raw = 30 + sleepScore - stressPenalty;
    return raw.clamp(20, 100);
  }

  /// 今日焦虑变化趋势（与昨日均值比较）
  /// 正值=恶化，负值=改善
  double get todayCalmTrend {
    // 今日实时焦虑分
    final todayScore = currentAnxietyScore.toDouble();
    // 历史均值（取最近7天 stressChartData 的均值作为参考基准）
    if (_stressChartData.isEmpty) return 0.0;
    final recentDays = _stressChartData.take(7).map((p) => p.stressScore);
    final historyAvg = recentDays.reduce((a, b) => a + b) / recentDays.length;
    if (historyAvg == 0) return 0.0;
    // 返回变化百分比（负值代表今日比历史均值更好）
    return ((todayScore - historyAvg) / historyAvg * 100).clamp(-99.0, 99.0);
  }

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
    _startDailySummaryTimer();                      // 启动每日健康总结定时器
  }

  // ── P1-3：每日健康总结定时器 ─────────────────────────────────────────────
  // 每分钟检查一次当前时间，20:00–20:05 期间触发当日总结推送
  // （用分钟轮询代替精确定时，避免 App 后台被杀时漏推）
  void _startDailySummaryTimer() {
    _dailySummaryTimer?.cancel();
    _dailySummaryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();
      // 测试模式：每5分钟触发一次（正式上线改为 now.hour == 20 && now.minute < 5）
      final shouldTrigger = now.minute % 5 == 0; // 测试用：每5分钟触发
      // final shouldTrigger = now.hour == 20 && now.minute < 5; // 正式生产用

      if (shouldTrigger) {
        // 用当前分钟时间点作为去重key，同一个5分钟窗口只触发一次
        final triggerKey = DateTime(now.year, now.month, now.day, now.hour, (now.minute ~/ 5) * 5);
        if (_lastDailySummaryDate == null || _lastDailySummaryDate != triggerKey) {
          _lastDailySummaryDate = triggerKey;
          _triggerDailySummary();
        }
      }
    });
  }

  // 生成并触发每日健康总结
  void _triggerDailySummary() {
    if (onDailySummaryReady == null) return;

    final todaySessionCount = _sessionHistory.where((s) {
      final d = s.feedTime;
      final now = DateTime.now();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;

    final avgTtc = _sessionHistory
        .where((s) =>
            s.timeToCalm != null &&
            s.feedTime.day == DateTime.now().day)
        .map((s) => s.timeToCalm!)
        .fold<int>(0, (a, b) => a + b);

    final summary = DailyHealthSummaryData(
      date: DateTime.now(),
      petName: _pet.name,
      pacingSeconds:    _todayPacingSeconds,
      playSeconds:      _todayPlaySeconds,
      stressSeconds:    _todayStressSeconds,
      shiverSeconds:    _todayShiverSeconds,
      sleepSeconds:     _todaySleepSeconds,
      lethargySeconds:  _todayLethargySeconds,
      feedingCount:     todaySessionCount,
      stressEventCount: _stressEventTimestamps.length, // 今日应激事件次数（与通知中心对齐）
      avgTimeToCalmSecs: todaySessionCount > 0
          ? avgTtc ~/ todaySessionCount
          : null,
      avgAnxietyScore:  currentAnxietyScore.toDouble(),
    );
    onDailySummaryReady?.call(summary);
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
    _dailySummaryTimer?.cancel();
    _ble.stop();
    super.dispose();
  }
}

// ── P1-3：每日健康总结数据模型 ──────────────────────────────────────────────
// 由 PetHealthProvider._triggerDailySummary() 生成
// 由 MainNavScreen 订阅，转化为 NotificationProvider 的通知条目
class DailyHealthSummaryData {
  final DateTime date;
  final String petName;
  final int pacingSeconds;     // 状态A：踱步时长（秒）
  final int playSeconds;       // 状态B：玩耍时长（秒）
  final int stressSeconds;     // 状态C：应激时长（秒）
  final int shiverSeconds;     // 状态D：发抖时长（秒）
  final int sleepSeconds;      // 状态E：睡眠时长（秒）
  final int lethargySeconds;   // 状态F：昏睡时长（秒）
  final int feedingCount;      // 当日喂食次数
  final int stressEventCount;  // 当日应激次数（与通知中心对齐）
  final int? avgTimeToCalmSecs; // 平均平静用时（秒），null = 今日未喂食
  final double avgAnxietyScore; // 当日平均焦虑分

  const DailyHealthSummaryData({
    required this.date,
    required this.petName,
    required this.pacingSeconds,
    required this.playSeconds,
    required this.stressSeconds,
    required this.shiverSeconds,
    required this.sleepSeconds,
    required this.lethargySeconds,
    required this.feedingCount,
    required this.stressEventCount,
    this.avgTimeToCalmSecs,
    required this.avgAnxietyScore,
  });

  // 生成简洁的中文总结文字（用于通知正文）
  String toSummaryText(bool isZh) {
    // 应激显示次数（与通知中心"过去1小时N次"对齐，让用户看得懂）
    final stressCount = stressEventCount;
    final pacingMin   = pacingSeconds  ~/ 60;
    final playMin     = playSeconds    ~/ 60;
    final sleepHours  = sleepSeconds   ~/ 3600;
    final score       = avgAnxietyScore.round();

    if (isZh) {
      final ttcStr = avgTimeToCalmSecs != null
          ? '，平静用时 ${avgTimeToCalmSecs! ~/ 60} 分钟'
          : '';
      return '焦虑分 $score｜踱步 $pacingMin 分｜应激 $stressCount 次｜'
             '玩耍 $playMin 分｜睡眠 $sleepHours 小时'
             '${feedingCount > 0 ? "｜今日喂食 $feedingCount 次$ttcStr" : "｜今日未喂食"}';
    } else {
      final ttcStr = avgTimeToCalmSecs != null
          ? ', calmed in ${avgTimeToCalmSecs! ~/ 60}m'
          : '';
      return 'Anxiety $score | Pacing ${pacingMin}m | Stress $stressCount times | '
             'Play ${playMin}m | Sleep ${sleepHours}h'
             '${feedingCount > 0 ? " | Fed $feedingCount time(s)$ttcStr" : " | No feeding today"}';
    }
  }
}
