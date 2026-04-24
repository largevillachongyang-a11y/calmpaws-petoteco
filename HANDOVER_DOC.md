# Calm Paws — 完整交接文档
## 面向接收程序员，无需询问即可上手

**版本：** 1.0.0+1  
**日期：** 2025-04-24（最后更新）  
**代码仓库：** https://github.com/largevillachongyang-a11y/calmpaws-petoteco  
**预览地址：** https://largevillachongyang-a11y.github.io/calmpaws-petoteco/  
**产品官网：** https://petotecolife.com/  
**产品购买链接：** https://petotecolife.com/product/zenbelly-calming-probiotic-chews  

---

## 目录
1. [产品定位](#1-产品定位)
2. [技术架构](#2-技术架构)
3. [项目文件结构](#3-项目文件结构)
4. [数据模型](#4-数据模型)
5. [状态管理](#5-状态管理)
6. [各页面功能详解](#6-各页面功能详解)
7. [核心业务逻辑](#7-核心业务逻辑)
8. [硬件通信协议](#8-硬件通信协议)
9. [Firebase 配置](#9-firebase-配置)
10. [本地化（中英双语）](#10-本地化中英双语)
11. [当前测试值 vs 生产值](#11-当前测试值-vs-生产值)
12. [已完成 / 未完成 / 待做清单](#12-已完成--未完成--待做清单)
13. [上线前检查清单](#13-上线前检查清单)
14. [接收程序员操作步骤](#14-接收程序员操作步骤)

---

## 1. 产品定位

**Calm Paws** 是配合 **ZenBelly 犬用益生菌焦虑咀嚼片** 的宠物健康监测 APP。

**核心价值主张：**
- 用户给狗喂 ZenBelly 后，APP 通过 BLE 项圈传感器实时监测焦虑变化
- 量化显示「平静用时」（Time-to-Calm），证明产品有效
- 用数据说话，提高 ZenBelly 复购率和用户信任

**目标用户：** 有分离焦虑犬只的宠物主人（主要市场：美国）

**硬件：** ZenBelly Collar（ESP32-S3 + ISM330DHCX 传感器 + BLE）

---

## 2. 技术架构

```
Flutter 3.35.4 / Dart 3.9.2
├── 状态管理:    Provider 6.1.5+1
├── 后端:        Firebase (Auth + Firestore + Storage)
├── 本地存储:    SharedPreferences 2.5.3 + Hive 2.2.3
├── 图表:        fl_chart 0.69.0
├── 链接跳转:    url_launcher 6.3.0
├── 图片上传:    image_picker 1.0.7
├── 认证:        Firebase Auth (Email/Password + Google Sign-In)
└── BLE:         当前为 Mock（mock_ble_service.dart），生产替换为 flutter_blue_plus
```

**Firebase 项目：** Calm Paws（Firebase Console）
- Android Package: `com.calmpaws.monitor`
- Firestore 数据库已创建
- Storage Bucket 已创建

---

## 3. 项目文件结构

```
lib/
├── main.dart                          # 入口，Firebase 初始化，Provider 注入
├── firebase_options.dart              # Firebase 多平台配置（自动生成）
├── models/
│   └── models.dart                    # 所有数据模型（BlePacket / PetProfile / FeedingSession / JournalEntry）
├── providers/
│   ├── pet_health_provider.dart       # 核心业务逻辑（BLE数据处理 / 状态机 / 报警）
│   ├── locale_provider.dart           # 语言切换（中/英）
│   └── notification_provider.dart    # 通知中心（本地通知列表管理）
├── services/
│   ├── auth_service.dart              # Firebase Auth 封装
│   ├── firestore_service.dart         # Firestore 读写封装
│   └── mock_ble_service.dart          # BLE 模拟器（生产替换）
├── screens/
│   ├── auth/auth_screen.dart          # 登录/注册/忘记密码
│   ├── dashboard/dashboard_screen.dart # 首页 Tab
│   ├── pet/pet_screen.dart            # 宠物档案 Tab
│   ├── shop/shop_screen.dart          # 商城 Tab
│   ├── profile/profile_screen.dart    # 我的 Tab
│   ├── notifications/notification_center_screen.dart # 通知中心
│   ├── main_nav_screen.dart           # 底部导航栏（4 Tabs）
│   └── dev/
│       ├── edge_impulse_screen.dart   # AI数据采集工具（E1/E2）
│       └── ota_screen.dart            # OTA固件升级（E3）
├── widgets/
│   ├── dashboard/
│   │   ├── behavior_state_card.dart   # 行为状态卡片（核心）
│   │   ├── feeding_timer_card.dart    # 喂食计时卡片（核心CTA）
│   │   ├── time_to_calm_card.dart     # 平静用时卡片
│   │   ├── stress_chart_card.dart     # 应激趋势图卡片
│   │   ├── status_cards_row.dart      # 三联状态卡行（睡眠/焦虑/活动）
│   │   ├── device_status_bar.dart     # 设备连接状态栏 + SYNC 按钮
│   │   └── journal_quick_entry.dart   # 快速日记录入
│   ├── pet/
│   │   └── health_calendar_card.dart  # 健康日历（传感器层 + 日记层）
│   └── common/
│       └── alert_banner.dart          # 顶部报警横幅
├── theme/
│   └── app_theme.dart                 # 颜色 / 字体 / 圆角常量
└── utils/
    └── app_strings.dart               # 中英双语文案（所有 UI 字符串）
```

---

## 4. 数据模型

### 4.1 BlePacket（BLE 数据包）
```dart
class BlePacket {
  final int strC;   // 应激计数（5秒窗口内）
  final int strD;   // 应激时长（秒）
  final int paceD;  // 踱步时长（秒）
  final int playD;  // 玩耍时长（秒）
  final int shivC;  // 颤抖计数
  final int shivD;  // 颤抖时长（秒）
  final int rollC;  // 翻滚计数
  final int battery; // 电量 0-100
  final double rssi; // 信号强度 dBm
  // 注意：硬件发出的是「累计值」，APP 通过 BlePacket.deltaFrom() 计算差值包
}
```

**行为状态优先级（getter: behaviorState）：**
```
shivD > 2  → shivering（最高优先）
strC >= 2 OR strD > 3 → stressed
paceD > 3 → pacing
playD > 3 → playing
else → calm（再由 Provider 判断 E1/E2 睡眠子状态）
```

**焦虑分计算（anxietyScore，0-100）：**
```
strC × 20（上限40）+ paceD × 3（上限30）+ shivD × 6（上限24）+ strD × 2（上限10）
```

**活动分计算（activityScore，0-100）：**
```
playD × 10（上限60）+ rollC × 10（上限30）+ strC × 3（上限10）
```

**JSON 字段名（硬件 V6.1 标准）：**
```json
{ "ts": 1700000000, "bat": 85, "str_c": 1, "str_d": 2,
  "pace_d": 5, "play_d": 0, "shiv_c": 0, "shiv_d": 0, "roll_c": 1 }
```
> ⚠️ 硬件发送「累计值」，APP 必须用 `BlePacket.deltaFrom(current, previous)` 计算差值

---

### 4.2 PetProfile（宠物档案）
```dart
class PetProfile {
  final String id;         // "pet_{uid}"
  final String name;       // 宠物名（如 "Biscuit"）
  final String species;    // "dog" | "cat"
  final String breed;      // 品种
  final int ageMonths;     // 月龄
  final double weightKg;   // 体重（千克）
  final String? photoPath; // Firebase Storage URL（可选）
  final List<String> healthTags; // ["Separation Anxiety", ...]
  final DateTime createdAt;
}
```

**Firestore 路径：** `users/{uid}/pet_profile/main`
**字段名映射：** name, species, breed, age_months, weight_kg, health_tags, photo_url, created_at, updated_at, owner_uid

---

### 4.3 FeedingSession（喂食记录）
```dart
class FeedingSession {
  final String id;              // 唯一ID
  final DateTime feedTime;      // 喂食时间
  final int? timeToCalm;        // 从喂食到持续平静的秒数（核心指标）
  final int stressCountBefore;  // 喂食前 strC 值
  final int stressCountAfter;   // 平静后 strC 值
  final List<TimelineEvent> timeline; // 喂食过程中的行为事件序列
}
```

**Firestore 路径：** `users/{uid}/feeding_sessions/{sessionId}`
**平静判定：** 连续 60 秒焦虑分 < 30 即判定为「已平静」，session 自动结束

---

### 4.4 JournalEntry（健康日记）
```dart
class JournalEntry {
  final String id;         // "journal_{timestamp}"
  final DateTime date;
  final String? stoolEmoji;    // 大便状态 emoji
  final String? moodEmoji;     // 情绪 emoji
  final String? appetiteEmoji; // 食欲 emoji
  final String? energyEmoji;   // 活力 emoji
  final String? notes;         // 文字备注
  final String? weightKg;      // 今日称重（字符串，可选）
}
```

**Firestore 路径：** `users/{uid}/journal_entries/{entryId}`

---

### 4.5 DailyStressDataPoint（图表数据）
```dart
class DailyStressDataPoint {
  final DateTime date;
  final double beforeScore;  // ZenBelly 使用前焦虑分
  final double afterScore;   // ZenBelly 使用后焦虑分
}
```
> 注：前 7 天为使用前（橙色），后 7 天为使用后（绿色），目前为 Demo 数据

---

### 4.6 PetBehaviorState 枚举（7 种状态）
```dart
enum PetBehaviorState {
  calm,           // 平静（白色）
  pacing,         // 踱步（橙色）
  stressed,       // 应激（红色）
  playing,        // 玩耍（紫色）
  shivering,      // 颤抖（深红）
  sleepNormal,    // 正常睡眠 E1（蓝色）
  sleepAbnormal,  // 异常昏睡 E2（橙色）
}
```

---

## 5. 状态管理

### 5.1 PetHealthProvider（核心）
`lib/providers/pet_health_provider.dart` — ~1200 行

**关键属性：**
```dart
PetProfile get pet                      // 当前宠物档案
PetBehaviorState get currentBehavior    // 当前行为状态（含E1/E2判断）
int get currentAnxietyScore             // 当前焦虑分（0-100）
BlePacket? get latestPacket             // 最新差值数据包
FeedingSession? get activeSession       // 进行中的喂食记录
List<FeedingSession> get sessionHistory // 历史喂食记录
int get sessionElapsedSeconds           // 当前喂食计时秒数
List<JournalEntry> get journalEntries   // 健康日记列表
bool get hasAlert                       // 是否有活跃报警
String get alertMessage                 // 报警消息文本
String get alertType                    // 报警类型
bool get isDeviceConnected              // 设备是否在线
```

**初始化流程：**
```
main.dart → PetHealthProvider() → init() →
  1. loadPetForUser(uid)       # 从 Firestore 加载宠物档案
  2. _seedHistoricalSessions() # 注入 Demo 历史数据（登录后被真实数据覆盖）
  3. MockBleService.start()    # 开始接收 BLE 数据（每5秒一包）
  4. _startDailySummaryTimer() # 启动每日20:00总结定时器
```

**BLE 数据处理流程（每5秒）：**
```
_onPacket(rawPacket) →
  1. 计算差值包 delta = BlePacket.deltaFrom(raw, previous)
  2. _confirmedState 状态机（需连续 kStateConfirmPackets=2 包相同才切换）
  3. _checkAlerts(delta) → 触发报警（发抖/应激/昏睡等）
  4. 更新 activeSession（喂食中）
  5. notifyListeners() → UI 更新
```

---

### 5.2 LocaleProvider
- 持久化存储语言偏好（SharedPreferences key: `"locale"`）
- `isZh` getter：true = 中文，false = 英文
- 通过 `context.watch<LocaleProvider>().strings` 获取所有 UI 字符串
- 便捷扩展：`context.s` = `context.watch<LocaleProvider>().strings`

---

### 5.3 NotificationProvider
- 维护应用内通知列表（`List<AppNotification>`）
- 未读角标数量（`unreadCount`）
- 通知类型：`shiver_alert | stress_frequent | lethargy | activity_low | sleep_abnormal | feeding_complete | daily_summary`
- 通知来源：由 `PetHealthProvider` 通过回调触发，避免循环依赖

---

## 6. 各页面功能详解

### 6.1 登录页（auth_screen.dart）

**三种模式：**
1. **login**：邮箱 + 密码登录 + Google 登录（Web 用 `signInWithPopup`，移动用 `signInWithCredential`）
2. **register**：昵称 + 邮箱 + 密码注册，注册后自动创建空白宠物档案
3. **forgotPassword**：输入邮箱发送重置链接

**Google 登录 Web 兼容处理：**
```dart
// Web: 先尝试 Popup，失败则 fallback 到 Redirect
try { signInWithPopup } catch { signInWithRedirect }
```

**登录后流程：**
- `AuthGate` StreamBuilder 监听 `FirebaseAuth.instance.authStateChanges()`
- 登录 → `PetHealthProvider.loadPetForUser(uid)` → 加载宠物数据 → 进入主界面
- 退出 → 清空 pet 数据和通知数据 → 返回登录页

---

### 6.2 首页（dashboard_screen.dart）

**页面结构（从上到下）：**
```
SafeArea
└── CustomScrollView
    ├── SliverToBoxAdapter: DeviceStatusBar      # 设备状态栏
    ├── SliverToBoxAdapter: AlertBanner          # 报警横幅（有报警时显示）
    ├── SliverToBoxAdapter: BehaviorStateCard    # 行为状态卡片
    ├── SliverToBoxAdapter: FeedingTimerCard     # 喂食计时卡片
    ├── SliverToBoxAdapter: StatusCardsRow       # 三联状态卡
    ├── SliverToBoxAdapter: TimeToCalmCard       # 平静用时历史
    ├── SliverToBoxAdapter: StressChartCard      # 应激趋势图
    └── SliverToBoxAdapter: JournalQuickEntry    # 快速日记
```

---

#### 6.2.1 DeviceStatusBar（设备状态栏）
- 左侧：项圈图标 + 设备状态文字（「ZenBelly Collar · Live」或「No Device Connected」）
- 中间：电量指示器
- 右侧：**SYNC 按钮**（手动触发离线数据同步）

**SYNC 按钮逻辑：**
```
点击 SYNC →
  1. APP 发送 "SYNC" 字符串到设备 BLE
  2. 设备返回：
     - "SYNC_EMPTY"：无离线数据，显示「已是最新」
     - CSV 数据流：逐行解析 BLE CSV
     - "SYNC_DONE"：传输完成，APP 回复 "SYNC_ACK" 确认
  3. 解析 CSV → 写入 Firestore（feeding_sessions 或 daily_logs）
```

---

#### 6.2.2 AlertBanner（报警横幅）
- 仅在 `provider.hasAlert == true` 时显示
- 根据 `provider.alertType` 显示不同颜色和图标
- 右上角 X 按钮：调用 `provider.dismissAlert()`

---

#### 6.2.3 BehaviorStateCard（行为状态卡片）

**三层信息：**
1. **结论层（上）：** 自然语言描述当前状态（如「Biscuit 出现应激反应 ⚠️」）
2. **焦虑分（中）：** 环形进度条，0-100 分，颜色随分值变化
3. **可展开区（下）：** 当前数据包驱动因素 + 今日累计时长统计

**背景颜色与状态对应：**
```
calm          → 米白色（AppColors.cream）
playing       → 浅紫色
pacing        → 浅橙色
stressed      → 浅红色
shivering     → 深红色
sleepNormal   → 浅蓝紫色
sleepAbnormal → 浅橙色（橙色警告）
```

---

#### 6.2.4 FeedingTimerCard（喂食计时卡片 - 核心 CTA）

**三种状态：**

**状态1：未喂食（橙色渐变）**
- 显示 💊 图标 + 「已喂食 ZenBelly」标题 + 描述
- 白色大按钮：「已喂食 ZenBelly」
- 如有历史记录，底部显示上次平静用时
- 点击按钮 → `provider.startFeedingSession()` → 切换到状态2

**状态2：计时中（绿色渐变）**
- 顶部：「计时中」+ 取消按钮
- 大时间数字：已过去秒数（自动更新）
- 双弧进度条：时间进度弧（白色）+ 平静进度弧（根据焦虑分）
- 行为标签：当前状态 emoji + 文字（实时更新）
- 里程碑进度条：已给药 → 吸收中 → 沉淀中 → 平静
- 取消按钮：弹确认弹窗后 `provider.cancelFeedingSession()`

**自动完成逻辑：**
```dart
// 在 _checkAlerts 中
// 连续 60s 焦虑分 < 30 且当前状态为 calm/sleepNormal
// → provider._completeSession() → 状态切到已完成
```

**状态3：已完成**
- 显示本次 Time-to-Calm（分钟）
- 与上次对比（↑↓ 趋势 + 差值）
- 应激次数 before/after 对比 chips

---

#### 6.2.5 StatusCardsRow（三联状态卡）
三张小卡片横向排列：
1. **睡眠质量**：今日正常/异常睡眠时长比，绿色/橙色 progress bar
2. **焦虑分**：当前实时分值，颜色编码（绿/黄/橙/红）
3. **活动水平**：今日活动分，绿色 progress bar

---

#### 6.2.6 TimeToCalmCard（平静用时卡片）

**内容：**
- 最近一次平静用时（分钟）
- 周平均对比
- 最近 4 次小圆点（按时间排列）
- 「查看全部」按钮 → 弹出 `_FeedingHistorySheet`

**_FeedingHistorySheet（历史 BottomSheet）：**
- 摘要区：总次数 + 平均平静用时 + 应激改善幅度
- 列表：每条记录显示时间 + 平静用时分钟 + before/after 应激数

---

#### 6.2.7 StressChartCard（应激趋势图）

**折线图（fl_chart）：**
- 橙色线：使用前 7 天焦虑分（Demo 数据）
- 绿色线：使用后 7 天焦虑分（Demo 数据）
- 虚线：上周平均参考线
- X 轴：日期标签
- 点击折线节点：显示当日数值 tooltip

> ⚠️ 当前为 Demo 数据，需接入 14 天真实 Firestore 数据

---

#### 6.2.8 JournalQuickEntry（快速日记录入）
- 4 个 emoji 选择器（大便 / 情绪 / 食欲 / 活力）
- 文字备注输入框
- 「保存」→ `provider.addJournalEntry()` → 写入 Firestore

---

### 6.3 宠物档案页（pet_screen.dart）

**页面结构：**
```
SliverAppBar + 宠物头像（可点击上传照片）
├── 基础信息区：名字 / 品种 / 年龄月龄 / 体重 / 物种 emoji
├── 编辑按钮 → _showEditDialog（弹窗修改全部字段）
├── 健康标签：TagChip 列表（如「分离焦虑」「过度吠叫」）
├── 焦虑等级调节器（仅 debug 模式）：Slider 0-100% 控制 MockBleService.anxietyLevel
└── HealthCalendarCard（健康日历）
```

**宠物照片上传（C4）：**
```
点击头像 →
  image_picker 从相册选图（512×512，质量85）→
  读取 bytes →
  provider.uploadPetPhoto(bytes) →
    Firebase Storage: users/{uid}/pet_photos/avatar.jpg →
    获得 downloadURL →
    更新 pet.photoPath →
    saveJournalEntry / savePetProfile 写入 Firestore →
    UI 显示新照片（NetworkImage）
```

**编辑弹窗（_showEditDialog）：**
- 名字 / 品种 / 月龄 / 体重 / 物种 / 健康标签
- 点击保存 → `provider.updatePetLocal()` → `provider.syncPetToCloud()`
- SnackBar 显示成功/失败（含错误类型：permission-denied / network-error / timeout）

---

#### 6.3.1 HealthCalendarCard（健康日历）

**双层设计：**
1. **传感器层（自动）：** 从 `provider.getDailyRecords(days:14)` 获取，显示当日焦虑分、走动时长、应激次数、睡眠质量
2. **主人层（手动）：** `JournalEntry` 对应的 emoji 记录，显示在日历格子右上角小圆点

**交互：**
- 点击日历格子 → 右侧面板显示当日详细数据
- 点击当天「+」按钮 → 弹出 `_showWriteJournalDialog` → 写入日记

---

### 6.4 商城页（shop_screen.dart）— 方案 C（混合）

**设计思路：** APP 内展示产品信息 + 点击跳转独立站，不在 APP 内处理支付

**页面结构：**
```
Header：「商城」标题 + 「我的订单」按钮（→ 跳转订单页）
├── _HeroProductCard：ZenBelly 主打产品卡
│   ├── 产品图片（网络图）+ 名称 + 简介 + 评分
│   ├── 「了解更多」→ 跳转产品页
│   └── 「立即购买」→ 跳转产品页
├── _SubscriptionSection（D1）：3 种订阅套餐卡
│   ├── 月订阅 / 季订阅（最优惠标签）/ 年订阅
│   └── 「订阅」按钮 → 跳转独立站订阅锚点
├── _IngredientHighlights：6 大关键成分展示
├── _DosageGuide：用量指南表格（按体重分档）
├── _ReviewsSection：3 条用户评价（静态）
├── _FaqSection：可展开 FAQ（5 条）
├── _BottomActions：「查看我的订单」跳转按钮（D3）
└── _BuyBar（底部固定）：「立即购买 $29.90」→ 跳转产品页
```

**URL 常量：**
```dart
const _kProductUrl   = 'https://petotecolife.com/product/zenbelly-calming-probiotic-chews';
const _kStoreUrl     = 'https://petotecolife.com/';
const _kOrdersUrl    = 'https://petotecolife.com/my-account/orders/';
const _kSubscribeUrl = 'https://petotecolife.com/product/.../#subscribe';
```

---

### 6.5 我的页面（profile_screen.dart）

**页面结构：**
```
用户头像区：Firebase displayName + email
订阅卡片（Demo 数据）：套餐名称 / 下次扣费日 / 剩余天数
菜单列表：
├── 订单历史    → 弹窗显示最近5条 FeedingSession
├── 客服支持    → 弹窗显示联系方式
├── 设备使用指南 → 弹窗 10步操作说明
├── 固件升级 (OTA) → 跳转 OtaScreen（E3）
├── AI 数据工具  → 跳转 EdgeImpulseScreen（E1/E2）
├── 健康报告    → 弹窗显示历史喂食摘要
├── 消息通知    → 弹窗通知开关设置
├── 隐私与数据  → 弹窗隐私政策说明
├── 退出登录    → 确认弹窗 → AuthService.signOut()
└── 🛠 触发每日总结（仅 Debug 模式）
```

**语言切换：** 在页面顶部「Language / 语言」切换器（中英），调用 `LocaleProvider.setLocale()`

---

### 6.6 通知中心（notification_center_screen.dart）

**入口：** 首页右上角 🔔 图标（有未读时显示红色角标）

**通知类型与图标：**
```
shiver_alert    → 🆘 红色 — 「持续发抖 X 分钟」
stress_frequent → ⚠️ 橙色 — 「X 分钟内应激 N 次」
lethargy        → 😴 灰色 — 「昏睡超 X 小时」
activity_low    → 🐢 黄色 — 「全天活动不足」
sleep_abnormal  → 🌙 蓝色 — 「异常睡眠超 X 分钟」
feeding_complete→ ✅ 绿色 — 「平静用时 X 分钟」
daily_summary   → 📊 绿色 — 每日健康总结
```

**操作：** 单条可右滑删除 / 顶部「全部标为已读」

---

### 6.7 Edge Impulse 数据工具（edge_impulse_screen.dart）— E1/E2

**Tab 1 - 采集：**
- 实时显示当前 BLE 数据包 7 个字段（带颜色高亮）
- 5 种行为标签选择器（emoji + 名称 chip）
- 「标注此数据窗口」按钮 → 记录一个 `_LabeledSample`
- 采集指南提示卡

**Tab 2 - 样本库：**
- 各标签采集数量统计 + 进度条（分布图）
- 所有样本的时间顺序列表（含关键字段预览）
- 「导出 CSV」→ 复制到剪贴板（Edge Impulse 兼容 CSV 格式）
- 「预览」/ 「清空」操作

**Tab 3 - 模型训练（E2）：**
- 7步训练流程说明（采集→导出→上传EI→设计特征→训练→导出.tflite→嵌入固件）
- 输入特征说明（7维）
- 输出标签（5类）
- 目标指标（≥85% 准确率，< 5ms 推理，< 50KB 大小）
- Edge Impulse 快捷链接

**CSV 格式（Edge Impulse 兼容）：**
```
timestamp,label,str_c,str_d,pace_d,play_d,roll_c,shiv_c,shiv_d,anxiety_score
1700000000000,calm,0.00,0.00,0.00,5.00,1.00,0.00,0.00,15
```

---

### 6.8 OTA 固件升级（ota_screen.dart）— E3

**状态机（7 种状态）：**
```
idle → checking → available/upToDate → downloading → flashing → success/failed
```

**关键 UI 元素：**
- 设备状态卡：设备名 + 当前版本 + 连接状态
- 更新日志：可折叠，显示本次更新的所有改动
- 进度条：下载进度（KB 显示）/ 写入进度（数据包序号显示）
- 写入警告：BLE 写入中不可断开
- 右上角 ℹ：显示 BLE OTA 协议详情（SERVICE_UUID / CHAR_UUID / 命令格式）

**BLE OTA 协议（预留框架，当前为 Mock）：**
```
SERVICE_UUID = 4fafc201-1fb5-459e-8fcc-c5c9c331914b
CHAR_UUID(Write) = beb5483e-36e1-4688-b7f5-ea07361b26a8
CHAR_UUID(Notify) = cba1d466-344c-4be3-ab3f-189f80dd7518

命令格式：
OTA_START  = 0x01 + 4字节文件大小
DATA       = 0x02 + 2字节序号 + 128字节数据
OTA_DONE   = 0x03 + 4字节CRC32
OTA_ABORT  = 0x04
ACK        = 0x10 + 2字节序号（设备回复）
OTA_STATUS = 0x11 + 1字节状态码（设备回复）
```

> ⚠️ 实际 BLE DFU 写入需完成 B10（flutter_blue_plus 集成）后才能真正工作

---

## 7. 核心业务逻辑

### 7.1 行为状态状态机（双确认机制）

```dart
// 每收到一个 BLE 包（5秒）
void _onPacket(BlePacket rawPacket) {
  final delta = BlePacket.deltaFrom(rawPacket, _latestPacket!);
  final rawState = delta.behaviorState; // 根据阈值判断原始状态

  // 双确认：连续 2 包相同才切换（防止噪声抖动）
  if (rawState == _pendingState) {
    _pendingStateCount++;
    if (_pendingStateCount >= kStateConfirmPackets) { // kStateConfirmPackets = 2
      _confirmedState = rawState;
    }
  } else {
    _pendingState = rawState;
    _pendingStateCount = 1;
  }
}

// currentBehavior 优先返回 E1/E2 睡眠状态
PetBehaviorState get currentBehavior {
  if (_confirmedState == PetBehaviorState.calm && _sleepState != null) {
    return _sleepState!;
  }
  return _confirmedState;
}
```

---

### 7.2 睡眠状态判断（E1/E2）

```dart
// 在 _checkAlerts 中，每5秒执行
if (_confirmedState == PetBehaviorState.calm) {
  if (packet.rollC > 0 || packet.strC > 0) {
    // 有翻身/应激 → 正常睡眠 / 重置计时器
    _continuousSleepNoRollSeconds = 0;
    _lastRollDetectedAt = now;
    _sleepState = PetBehaviorState.sleepNormal;
  } else {
    _continuousSleepNoRollSeconds += 5;
    if (_continuousSleepNoRollSeconds >= kSleepAbnormalThreshold) {
      // 超过阈值（测试:600s=10min，生产:7200s=2h）→ 异常睡眠
      _sleepState = PetBehaviorState.sleepAbnormal;
      // 触发一次性报警
    } else if (_lastRollDetectedAt != null && 
               now.difference(_lastRollDetectedAt!).inSeconds < kSleepWindowSeconds) {
      _sleepState = PetBehaviorState.sleepNormal;
    }
  }
} else {
  // 非 calm 状态 → 清除睡眠状态
  _sleepState = null;
  _continuousSleepNoRollSeconds = 0;
}
```

---

### 7.3 七种报警规则

| 编号 | 类型 | 触发条件 | 冷却 |
|---|---|---|---|
| 1 | `shiver_alert` | 连续颤抖 ≥ `kShiverThreshold` 秒（测试值30s） | 当天仅触发一次 |
| 2 | `stress_frequent` | 60分钟内应激次数 ≥ `kStressFreqThreshold`（=3） | 每 `kStressFreqCooldownMinutes` 分钟（=2min测试，生产60min） |
| 3 | `lethargy` | 连续静止（pace/play/stress均=0）≥ 2小时 | 当天仅触发一次 |
| 4 | `activity_low` | 全天活动分总计 < 阈值（由每日总结检查） | 每天一次（20:00） |
| 5 | `sleep_abnormal` | E2 异常睡眠触发（`kSleepAbnormalThreshold`） | 当天仅触发一次 |
| 6 | `feeding_complete` | 喂食 session 结束，timeToCalm 已记录 | 每次喂食结束一次 |
| 7 | `daily_summary` | 每天 20:00–20:04 | 每天一次 |

---

### 7.4 喂食 Session 完整流程

```
用户点击「已喂食 ZenBelly」
→ provider.startFeedingSession()
   ├── 记录 feedTime = now
   ├── 记录 stressCountBefore = _deltaPacket.strC
   ├── 启动 _sessionTimer (每秒 tick)
   └── 开始向 Firestore POST 记录

每5秒收到 BLE 包：
→ _updateFeedingSession(delta)
   ├── 记录 TimelineEvent（行为 + 时间戳）
   ├── 检查是否已平静（连续60s焦虑分<30）
   └── 如已平静 → _completeSession()
       ├── timeToCalm = elapsed seconds
       ├── stressCountAfter = _deltaPacket.strC
       ├── 保存到 Firestore（PATCH feeding_sessions/{id}）
       ├── 触发 feeding_complete 通知
       └── onFeedingCompleted 回调

用户主动取消：
→ provider.cancelFeedingSession()
   ├── timeToCalm = null（未完成）
   └── 保存不完整记录
```

---

### 7.5 SYNC 离线数据同步

```
用户点击 SYNC 按钮
→ BLE Write: "SYNC"
→ 设备响应（三种情况）：

情况1: "SYNC_EMPTY"
   → UI 显示「已是最新，无离线数据」

情况2: CSV 数据流
   → 逐行解析 CSV（OfflineDataParser）
   → 识别数据类型（feeding_session / daily_log）
   → 写入 Firestore 对应集合
   → 接收 "SYNC_DONE"

情况3: "SYNC_DONE"（数据传输结束）
   → APP 发送 "SYNC_ACK"（B9）
   → 设备收到 ACK 后才删除 LittleFS 文件（B6）
   → UI 显示「同步完成」

CSV 格式（硬件产出）：
"ts,str_c,str_d,pace_d,play_d,shiv_c,shiv_d,roll_c,bat\n"
"1700000000,0,0,5,0,0,0,1,85\n"
```

---

### 7.6 每日总结（20:00）

```dart
// _startDailySummaryTimer() 每分钟检查一次
// 条件：now.hour == 20 && now.minute < 5 && 今天未触发
_triggerDailySummary() →
  汇总：
  ├── 今日走动时长（_todayPacingSeconds）
  ├── 今日应激时长（_todayStressSeconds）
  ├── 今日颤抖时长（_todayShiverSeconds）
  ├── 今日正常睡眠（_todaySleepNormalSeconds）
  ├── 今日异常睡眠（_todaySleepAbnormalSeconds）
  ├── 今日喂食次数（今日 sessionHistory 数量）
  └── 今日平均平静用时
  → 生成总结通知 → NotificationProvider.addNotification()
  → onDailySummaryReady 回调（外部可处理）
```

---

## 8. 硬件通信协议

### 8.1 硬件规格
- **主控：** ESP32-S3
- **传感器：** ISM330DHCX（6轴 IMU，加速度 + 陀螺仪）
- **存储：** LittleFS（离线数据持久化）
- **通信：** BLE（Nordic UART Service / Custom Service）
- **固件版本：** V6.1（当前），V6.2（OTA 更新目标版本）

### 8.2 BLE 服务 UUID
```
SERVICE_UUID:         4fafc201-1fb5-459e-8fcc-c5c9c331914b
CHAR_UUID (Write):    beb5483e-36e1-4688-b7f5-ea07361b26a8
CHAR_UUID (Notify):   cba1d466-344c-4be3-ab3f-189f80dd7518
```

### 8.3 实时数据包（每5秒，JSON）
```json
{
  "ts": 1700000000,
  "bat": 85,
  "str_c": 1,
  "str_d": 2,
  "pace_d": 0,
  "play_d": 5,
  "shiv_c": 0,
  "shiv_d": 0,
  "roll_c": 1
}
```
> 注意：ts 为 UNIX 时间戳（秒），bat 为电量百分比，其余均为 5s 窗口的「累计值」

### 8.4 SYNC 协议（离线数据同步）
```
APP → 设备：  "SYNC"
设备 → APP：  "SYNC_EMPTY"（无数据）
              或 CSV 行（有数据时逐行发送）
              或 "SYNC_DONE"（CSV 发完）
APP → 设备：  "SYNC_ACK"（收到 SYNC_DONE 后回复，设备才删文件）
```

---

## 9. Firebase 配置

### 9.1 Firestore 数据结构
```
users/{uid}/
├── pet_profile/main               # 宠物档案
├── feeding_sessions/{sessionId}   # 喂食记录
└── journal_entries/{entryId}      # 健康日记
```

### 9.2 Storage 结构
```
users/{uid}/pet_photos/avatar.jpg  # 宠物头像
```

### 9.3 Security Rules（开发模式，上线前需收紧）
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

### 9.4 firebase_options.dart
- 已配置 Web + Android 双平台
- Web 平台使用 `DefaultFirebaseOptions.currentPlatform`
- **上线前需在 Firebase Console 授权生产域名**

---

## 10. 本地化（中英双语）

所有 UI 文案在 `lib/utils/app_strings.dart` 中定义：

```dart
class AppStrings {
  final String locale; // 'en' 或 'zh'
  String _t(String en, String zh) => locale == 'zh' ? zh : en;

  // 使用示例
  String get timerStart => _t('Fed ZenBelly', '已喂食 ZenBelly');
}

// 使用方式
final s = context.s; // = context.watch<LocaleProvider>().strings
Text(s.timerStart)
```

**语言持久化：** SharedPreferences key `"locale"`，值为 `"en"` 或 `"zh"`

---

## 11. 当前测试值 vs 生产值

> ⚠️ 上线前必须将所有测试值改回生产值（F1）

| 常量 | 当前（测试）| 生产值 | 文件位置 |
|---|---|---|---|
| `kSleepAbnormalThreshold` | **600 秒**（10分钟） | **7200 秒**（2小时） | pet_health_provider.dart:539 |
| `kShiverThreshold` | **30 秒** | **120 秒**（2分钟） | pet_health_provider.dart:507 |
| `kStressFreqCooldownMinutes` | **2 分钟** | **60 分钟** | pet_health_provider.dart:515 |
| `kStressFreqThreshold` | 3 次 | 3 次（不变） | pet_health_provider.dart:514 |
| `kStateConfirmPackets` | 2 包 | 2 包（不变） | pet_health_provider.dart:272 |
| `kSleepWindowSeconds` | 7200 秒 | 7200 秒（不变） | pet_health_provider.dart:540 |
| Mock BLE 间隔 | 5 秒 | — | mock_ble_service.dart（替换为真实BLE） |

---

## 12. 已完成 / 未完成 / 待做清单

### ✅ 已完成

| 编号 | 任务 |
|---|---|
| A1 | 状态模型拆分（E1正常睡眠 / E2异常睡眠） |
| A2 | 7种通知类型逻辑 |
| A3 | UI卡片颜色/emoji/文字与状态对应 |
| A4 | 应激阈值 strC >= 2 |
| A5 | 测试冷却时间2分钟 |
| A6 | assets/images 目录 |
| B1 | JSON字段名对齐（硬件已完成） |
| B2 | 时间戳 time(&now)（硬件已完成） |
| B3 | 玩耍防抖2次确认（硬件已完成） |
| B4 | SYNC_EMPTY 返回（硬件 V6.6） |
| B5 | SYNC delay 20ms（硬件 V6.6） |
| B6 | SYNC 收 ACK 才删文件（硬件 V6.6） |
| B7 | SYNC 按钮 UI |
| B8 | 离线 CSV 解析写入 Firestore |
| B9 | APP 收 SYNC_DONE 发 ACK |
| C1 | 喂食记录 + 平静用时卡片 + 历史 BottomSheet |
| C2 | 每日20:00日报触发逻辑 + 手动测试按钮 |
| C3 | 周趋势图上周均值参考线 |
| C4 | 宠物档案：照片上传（Firebase Storage）|
| C5 | 健康日历：日记写入同步 Firestore |
| D1 | 订阅套餐展示（3种）+ 跳转独立站 |
| D2 | ZenBelly 产品完整展示页 |
| D3 | 订单跳转按钮（→ petotecolife.com/my-account/orders） |
| E1 | Edge Impulse 数据采集标注工具（3个Tab）|
| E2 | 模型训练说明页（7步流程 + 特征说明）|
| E3 | OTA 固件升级 UI（7态状态机 + BLE协议框架）|

---

### ⬜ 未完成（技术原因/需要硬件）

| 编号 | 任务 | 原因/说明 |
|---|---|---|
| B10 | BLE断线重连不丢数据 | 需要真机硬件 + flutter_blue_plus 实现真实BLE扫描/连接/重连逻辑 |
| E2实际 | AI模型实际训练 | 需要真实硬件数据采集后才能训练 |
| E3实际 | OTA实际写入 | 依赖B10完成（需要BLE Write通道） |
| F4 | 集成测试（硬件+APP联调） | 需要真机 |

---

### 🔶 计划内但尚有缺陷

| 编号 | 任务 | 当前状态 | 待补充 |
|---|---|---|---|
| C1 | 喂食记录手动添加 | 历史查看已做，无手动添加入口 | 需要手动录入喂食时间的界面 |
| C2 | 日报定时推送 | ✅ 已集成本地推送（`flutter_local_notifications 17.2.4`），日报走安静渠道 | — |
| C4 | 宠物档案完善 | 照片上传已做，无体重趋势图 | 可选：体重历史折线图 |

---

### 🆕 非计划内、建议补充的功能

| 优先级 | 功能 | 说明 |
|---|---|---|
| 🔴 高 | **本地推送通知**（flutter_local_notifications） | ✅ **已完成**（`LocalNotificationService` 4渠道分级推送，绑定报警/喂食/日报；登录后自动请求权限） |
| 🔴 高 | **设备首次配对引导流程** | ✅ **已完成**（`OnboardingScreen` 5步引导，首次登录自动弹出） |
| 🔴 高 | **F1 阈值切换为生产值** | ✅ **已完成**（`kDebugMode` 三元自动切换：debug=测试值 / release=生产值，打 release APK 时自动生效） |
| 🔴 高 | **F2 Firebase域名授权** | 生产域名（App Store / Play Store）需加入 Firebase Console 已授权域名列表 |
| 🟡 中 | **StressChartCard 接入真实14天数据** | 目前折线图为Demo数据，需从Firestore拉取真实历史 |
| 🟡 中 | **账号删除功能** | ✅ **已完成**（`AuthService.deleteAccount()` + 弹窗UI + App Store/Google Play 合规） |
| 🟡 中 | **订阅状态真实数据** | 我的页面订阅卡片目前为硬编码Demo，需接独立站API获取真实订阅状态 |
| 🟡 中 | **_seedHistoricalSessions 在生产移除** | ✅ **已完成**（仅在 `kDebugMode` 下执行） |
| 🟡 中 | **本地通知权限请求** | ✅ **已完成**（登录后延迟2秒调用 `requestPermission()`，Android 13+ / iOS 均已覆盖） |
| 🟢 低 | **多宠物支持** | 目前只支持一只宠物，未来可扩展 |
| 🟢 低 | **体重历史趋势图** | 在宠物档案页加体重历史折线图 |
| 🟢 低 | **健康报告 PDF 导出** | 在「健康报告」弹窗增加 PDF 导出功能 |
| 🟢 低 | **应用内评价请求** | 首次平静记录成功后请求用户评分 |

---

## 13. 上线前检查清单

### 必须完成（阻塞上线）
- [x] **F1** — ✅ 已完成（所有阈值通过 `kDebugMode` 三元自动切换：debug=测试值，release=生产值，发布 APK 时自动生效，无需手动改代码）
- [ ] **F2** — Firebase Console 添加生产域名授权（App Store / Play Store / 独立站域名）
- [ ] **B10** — BLE断线重连实现（使用 flutter_blue_plus，与硬件团队联调）
- [x] **本地推送通知** — ✅ `LocalNotificationService` 已集成，4渠道分级推送（报警/喂食/日报/系统）
- [x] **账号删除** — ✅ `AuthService.deleteAccount()` + 需输入 DELETE 确认 已完成
- [x] **通知权限请求** — ✅ 登录后延迟2秒自动请求（Android 13+ / iOS 均已覆盖）
- [ ] **移除 Mock BLE** — 将 `MockBleService` 替换为真实 `flutter_blue_plus` 实现
- [x] **移除 Demo 数据** — ✅ `_seedHistoricalSessions()` 仅在 `kDebugMode` 下执行

### 建议完成（提升质量）
- [x] **F3** — ✅ 代码注释已补全（`pet_health_provider.dart` `_checkAlerts` / `_isCalmState` / `_updateFeedingSession` 等核心方法均有详细说明）
- [ ] **F4** — 集成测试（真机硬件 + APP 联调，验证8条报警规则）
- [ ] **StressChartCard** — 接入真实 Firestore 14天数据
- [x] **设备配对引导** — ✅ 已实现 `OnboardingScreen`（5步引导，首次登录自动弹出）

### 可选（不影响上线）
- [ ] 订阅状态接独立站真实API
- [ ] 体重历史趋势图
- [ ] 健康报告 PDF 导出

---

## 14. 接收程序员操作步骤

### 环境要求
```
Flutter: 3.35.4（严禁升级，会破坏依赖兼容性）
Dart:    3.9.2
Java:    OpenJDK 17.0.2
Android SDK: API 35
```

### 克隆与运行
```bash
git clone https://github.com/largevillachongyang-a11y/calmpaws-petoteco.git
cd calmpaws-petoteco
flutter pub get
flutter run -d chrome   # Web预览
flutter run             # Android设备
```

### Firebase 配置
1. 从 Firebase Console 下载 `google-services.json`
2. 放到 `android/app/google-services.json`
3. 确认 `lib/firebase_options.dart` 中的 Web 配置与 Firebase Console 一致
4. 确认 Android `applicationId = "com.calmpaws.monitor"` 与 google-services.json 中 package_name 一致

### 替换 Mock BLE（关键步骤）
1. 在 `pubspec.yaml` 添加 `flutter_blue_plus: ^1.31.15`
2. 创建 `lib/services/ble_service.dart`，实现以下接口（参考 mock_ble_service.dart 的注释）：
   - `start()` — 扫描设备 → 连接 → 订阅 Notify Characteristic
   - `stop()` — 断开连接
   - `sendSync()` — BLE Write "SYNC"
   - `Stream<BlePacket> get dataStream` — 每5秒一包
   - 断线重连逻辑（B10）：监听连接状态，断线后自动重连，恢复累计计数器
3. 在 `pet_health_provider.dart` 将 `MockBleService` 替换为真实 `BleService`

### 切换生产阈值
在 `lib/providers/pet_health_provider.dart` 修改：
```dart
static const int kSleepAbnormalThreshold = 7200; // 改: 600 → 7200
static const int kShiverThreshold        = 120;  // 改: 30 → 120
static const int kStressFreqCooldownMinutes = 60; // 改: 2 → 60
```

### 集成本地推送通知

**✅ 已完成** — `lib/services/local_notification_service.dart`

**集成架构：**
```
main() → LocalNotificationService.instance.init()   // 初始化 + 创建 Android 通知渠道
MainNavScreen.initState() → Future.delayed(2s, requestPermission())  // 登录后延迟请求权限
NotificationProvider.addNotification() → _fireLocalNotification()   // 每次新通知同步推送到系统
```

**4 个通知渠道（Android）：**
| 渠道 ID | 名称 | 优先级 | 用途 |
|---|---|---|---|
| `calm_paws_alerts` | 宠物预警 | High（响铃+震动） | 颤抖/应激/踱步/嗜睡 |
| `calm_paws_feeding` | 喂食记录 | Default | 喂食会话完成 |
| `calm_paws_reports` | 每日健康报告 | Low（安静） | 每晚 20:00 日报 |
| `calm_paws_system` | 系统通知 | Min | 其他系统消息 |

**使用的包版本：**
```yaml
# pubspec.yaml（已添加）
flutter_local_notifications: 17.2.4
```

**AndroidManifest.xml 已添加权限：**
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

---

## 附录：关键常量速查表

```dart
// pet_health_provider.dart
kStateConfirmPackets    = 2        // 行为状态切换需要连续几包
kSleepAbnormalThreshold = 600      // ⚠️ 测试值，生产改7200
kSleepWindowSeconds     = 7200     // 睡眠观察窗口（2小时）
kShiverThreshold        = 30       // ⚠️ 测试值，生产改120
kStressFreqThreshold    = 3        // 60分钟内应激N次触发报警
kStressFreqCooldownMinutes = 2     // ⚠️ 测试值，生产改60

// models.dart (BlePacket.behaviorState)
shivD > 2   → shivering
strC >= 2   → stressed
strD > 3    → stressed (补充条件)
paceD > 3   → pacing
playD > 3   → playing
else        → calm

// mock_ble_service.dart
更新间隔:        5秒 (Timer.periodic(Duration(seconds: 5)))
默认焦虑等级:    0.4 (0.0~1.0)
时间段切换:      按系统时间自动切换 Phase
```


---

## 15. 新增文件索引（本轮更新）

| 文件 | 说明 |
|---|---|
| `lib/screens/onboarding/onboarding_screen.dart` | 设备首次配对引导（5步 BottomSheet，SharedPreferences 持久化） |
| `lib/services/auth_service.dart` | `deleteAccount()` 方法（已有，本轮添加 UI 菜单项） |
| `lib/services/local_notification_service.dart` | 本地推送通知服务（4渠道分级推送，Web no-op，Android 权限请求） |

---

## 16. 更新日志

### 2025-04-25（最新版本）
- 📋 **待办事项整理**：全面梳理已完成 / 未完成状态，更正 F1 标注：
  - ✅ **F1 阈值生产值**：代码已通过 `kDebugMode` 三元自动切换，无需手动改代码，标为已完成
  - 更新「非计划内功能」表格和「上线前检查清单」中 F1 的状态
- ✅ **本地推送通知集成**（flutter_local_notifications 17.2.4）：
  - 新建 `LocalNotificationService`（单例，4 个 Android 通知渠道）
  - 渠道分级：`calm_paws_alerts`（高优+震动）/ `calm_paws_feeding`（普通）/ `calm_paws_reports`（安静）/ `calm_paws_system`（最低）
  - `NotificationProvider.addNotification()` 新增 `_fireLocalNotification()` 路由逻辑，自动选择对应渠道
  - 日报通知（`actionRoute='dashboard'`）走安静的报告渠道，不打扰用户
  - `MainNavScreen` 登录后延迟 2 秒自动请求通知权限（避免与 Onboarding 弹窗冲突）
  - `main()` 新增 `LocalNotificationService.instance.init()`（创建 Android 渠道）
  - `AndroidManifest.xml` 新增 `POST_NOTIFICATIONS`、`VIBRATE`、`SCHEDULE_EXACT_ALARM` 权限
  - Web 平台自动 no-op（`kIsWeb` 判断），不影响 Web Preview

### 2025-04-24（上一版本）
- ✅ **Task 1**：Demo 数据保护 — `_seedHistoricalSessions()` 仅在 `kDebugMode` 下执行
- ✅ **Task 2**：账号删除功能 — `AuthService.deleteAccount()` + `_showDeleteAccount()` 弹窗（需输入 DELETE 确认）
- ✅ **Task 3**：设备首次配对引导 — 新建 `OnboardingScreen`（5步引导）：
  - 首次登录自动弹出 ModalBottomSheet
  - SharedPreferences `onboarding_shown` 标志持久化（永不重复弹出）
  - Debug 菜单新增「重置 Onboarding」按钮
  - 步骤：欢迎 → 充电 → 开启蓝牙 → 连接设备 → 完成佩戴
- ✅ **Task 4**：F3 代码注释补全：
  - `pet_health_provider.dart`：`_isCalmState()`、`_updateFeedingSession()` 新增详细说明
  - `pet_health_provider.dart`：所有核心逻辑段落（`_checkAlerts`、`_onPacket`、睡眠判定）均已完整注释
  - `models.dart`、`mock_ble_service.dart`、`firestore_service.dart`、`notification_provider.dart` 注释均已完整
- ✅ **Task 5**：HANDOVER_DOC.md 更新，反映本轮所有完成情况
