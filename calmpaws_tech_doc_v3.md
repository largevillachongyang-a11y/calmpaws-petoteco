# Calm Paws — 完整技术文档

> **版本：v3.0** | 更新日期：2025-07  
> **Commit：** main `796944a` | gh-pages `351f9f6`  
> **适用人员：** 产品工程师、维护开发者、硬件对接工程师

---

## 目录

1. [系统架构概述](#1-系统架构概述)
2. [硬件层：数据是如何产生的](#2-硬件层数据是如何产生的)
   - 2.1 传感器与芯片
   - 2.2 硬件端行为检测算法（Arduino）
   - 2.3 数据包格式（JSON over BLE）
   - 2.4 关键设计：为什么用累计值
   - 2.5 BLE 传输机制
3. [软件层：App 收到数据后如何处理](#3-软件层app-收到数据后如何处理)
   - 3.1 数据接收（BLE Stream）
   - 3.2 差值计算（累计值 → 5秒增量）
   - 3.3 行为状态判断（差值包 → 枚举）
   - 3.4 焦虑分计算（差值包 → 0-100分）
   - 3.5 活动量分计算
   - 3.6 完整 _onPacket 处理流程图
4. [焦虑分平滑方案：A+B 联合](#4-焦虑分平滑方案ab-联合)
   - 4.1 问题背景：为什么需要平滑
   - 4.2 A 方案：滑动窗口加权平均
   - 4.3 B 方案：连续2包状态确认
   - 4.4 A+B 联合设计与使用场景
   - 4.5 方案对比评估
5. [六大行为状态完整定义](#5-六大行为状态完整定义)
6. [八大通知系统完整说明](#6-八大通知系统完整说明)
   - 每条通知：触发条件 / 频率控制 / 内容模板 / 代码变量
7. [数据流与架构设计](#7-数据流与架构设计)
8. [数据持久化架构](#8-数据持久化架构)
9. [上线前必改清单](#9-上线前必改清单)
10. [附录：关键常量速查](#附录关键常量速查)

---

## 1. 系统架构概述

Calm Paws 是一款宠物焦虑健康监测 App，配合宠物项圈上的 BLE（蓝牙低功耗）传感器实时监测宠物行为状态，帮助宠物主人了解宠物焦虑程度并通过喂食干预（ZenBelly 益生素）追踪改善效果。

**核心数据链路（端到端）：**

```
硬件项圈（Arduino + MPU-6050 加速度传感器）
    │  每 5 秒广播一次 JSON 数据包（累计值）
    │  BLE GATT Notification
    ▼
Flutter App（BLE 接收层）
    │  MockBleService（开发期模拟）/ flutter_blue_plus（生产期）
    ▼
PetHealthProvider._onPacket(rawPacket)
    │  ① 差值计算：delta = BlePacket.deltaFrom(raw, prev)
    │  ② A方案：加权均值焦虑分（平滑显示）
    │  ③ B方案：状态2包确认（稳定切换）
    │  ④ _checkAlerts：6种预警通知
    │  ⑤ _updateFeedingSession：喂食追踪
    │  ⑥ notifyListeners：UI刷新
    ▼
UI 层（BehaviorStateCard / StressChartCard / FeedingTimerCard）
    +
通知中心（NotificationProvider via MainNavScreen 回调）
    +
Firestore 云端持久化（feeding_sessions / daily_stress / journal_entries）
```

---

## 2. 硬件层：数据是如何产生的

### 2.1 传感器与芯片

| 组件 | 型号 / 规格 | 作用 |
|------|------------|------|
| 主控芯片 | Arduino（Nordic nRF52 系列） | 处理传感器数据，发送 BLE |
| 加速度传感器 | MPU-6050 三轴加速度计/陀螺仪 | 采集三维运动数据（g值） |
| BLE 模块 | 内置 BLE 4.2/5.0 | 每5秒广播一次数据包 |
| 供电 | 项圈内锂电池（约82%初始电量） | 支持数天续航 |

### 2.2 硬件端行为检测算法（Arduino 端）

硬件通过分析加速度信号的**幅值、频率和持续时间**来识别行为类型。每5秒内，MPU-6050 持续采样（约100Hz），固件实时分类并累加：

#### 行为分类规则

| 行为类型 | 加速度特征 | 典型信号形态 | 硬件判断逻辑 |
|---------|-----------|------------|-------------|
| **应激（Stress）** | 峰值 1.5–2.0g，持续 < 0.5秒 | 短促爆发性大幅震动 | `peak_g > 1.5 && duration < 0.5s` → `stress_count++`，`stress_duration += 持续时长` |
| **发抖（Shiver）** | 接近 1g，高频小幅振动 > 10Hz | 密集小幅颤动，接近背景1g | `freq > 10Hz && amplitude < 0.3g` → `shiver_count++`，`shiver_duration += 持续时长` |
| **踱步（Pacing）** | 低频 0.5–2Hz，大幅规律摆动 | 左右摇摆的节律性运动 | `0.5Hz < freq < 2Hz && amplitude > 0.5g` → `pace_duration += 持续时长` |
| **玩耍（Play）** | 不规则高活跃，多轴混合大幅运动 | 无规律高幅跳跃旋转 | `multi_axis_high && irregular` → `play_duration += 持续时长`，`roll_count++` |
| **静止/睡眠** | 接近恒定 1g（重力分量），Z轴静止 | 平坦的1g基线，几乎无波动 | 不满足以上任一条件 |

#### 计数器更新规则

```c
// Arduino 伪代码（每100ms采样一次）
void loop() {
  read_acceleration(&ax, &ay, &az);
  float peak_g = sqrt(ax*ax + ay*ay + az*az);
  float freq = calculate_dominant_frequency(recent_samples);
  
  if (peak_g > 1.5 && burst_duration < 0.5) {
    stress_count++;                    // 应激次数累加
    stress_duration += burst_length;   // 应激时长累加（秒）
  }
  else if (freq > 10 && amplitude < 0.3) {
    shiver_count++;                    // 发抖次数累加
    shiver_duration += shiver_length;  // 发抖时长累加（秒）
  }
  else if (freq > 0.5 && freq < 2.0 && amplitude > 0.5) {
    pace_duration += 0.1;              // 踱步时长累加（秒）
  }
  else if (multi_axis_active && irregular) {
    play_duration += 0.1;              // 玩耍时长累加（秒）
    if (detected_roll) roll_count++;   // 打滚次数累加
  }
  
  // 每5秒广播当前累计值
  if (millis() - last_broadcast > 5000) {
    broadcast_ble_packet();
  }
}
```

### 2.3 数据包格式（JSON over BLE）

硬件每隔 **5秒** 通过 BLE GATT Notification 广播一次 JSON 格式的数据包：

```json
{
  "timestamp": 1720000000,   // Unix 时间戳（秒）
  "str_c":  42,              // 应激次数（累计，自开机只增不减）
  "str_d":  186,             // 应激持续秒（累计）
  "shiv_c": 8,               // 发抖次数（累计）
  "shiv_d": 23,              // 发抖持续秒（累计）
  "pace_d": 312,             // 踱步持续秒（累计）
  "play_d": 540,             // 玩耍持续秒（累计）
  "roll_c": 15,              // 打滚次数（累计）
  "battery": 82,             // 电池电量（%，瞬时值）
  "rssi":   -62              // 信号强度 dBm（瞬时值）
}
```

#### 字段类型说明

| 字段 | 类型 | 含义 |
|------|------|------|
| `str_c`, `str_d`, `shiv_c`, `shiv_d`, `pace_d`, `play_d`, `roll_c` | **累计值** | 自设备开机后单调递增，永不清零（设备重启除外） |
| `battery`, `rssi` | **瞬时值** | 当前状态，直接使用无需差值 |
| `timestamp` | **时间戳** | 当前 Unix 秒级时间戳 |

### 2.4 关键设计：为什么用累计值而非增量

这是硬件协议最重要的设计决定，App 端必须理解：

| 对比维度 | 累计值方案（当前采用） | 增量方案 |
|---------|-------------------|---------|
| **丢包容忍** | ✅ 丢1包，下包差值自然包含补偿 | ❌ 丢1包数据永久丢失 |
| **固件实现** | ✅ 简单：`count++` 即可 | ❌ 复杂：需判断发包时机和窗口 |
| **标准兼容** | ✅ 符合 BLE Characteristic 标准设计 | ❌ 非标准，调试困难 |
| **重启处理** | ❌ 设备重启后累计值归零，App 需处理负数差值 | ✅ 无需特殊处理 |
| **App 复杂度** | 需要 App 端做差值计算 | 直接使用 |

**重启保护：** `BlePacket.deltaFrom` 使用 `.clamp(0, 999)` 防止重启后差值为负数。

### 2.5 BLE 传输机制

```
GATT 服务架构（生产期）：
  Service UUID: [待硬件团队确认]
    └─ Characteristic UUID: [待确认]
       └─ Properties: NOTIFY（只读推送，无需 App 轮询）
       └─ 推送间隔: 5 秒 / 包
       └─ 数据格式: UTF-8 JSON bytes

开发期（MockBleService）：
  Timer.periodic(Duration(seconds: 5)) 模拟发包
  维护相同的累计计数器（_cumStrC 等）
  按时段模拟真实一天的行为周期
```

---

## 3. 软件层：App 收到数据后如何处理

### 3.1 数据接收（BLE Stream）

**文件：** `lib/providers/pet_health_provider.dart`

```dart
// 初始化时订阅 BLE 数据流
_bleService.stream.listen(_onPacket);

// MockBleService 每 5 秒 emit 一个 BlePacket（累计值包）
```

### 3.2 差值计算（累计值 → 5秒增量）

**文件：** `lib/models/models.dart` — `BlePacket.deltaFrom()`

这是 App 端最关键的一步转换。收到的原始包是累计值，必须先减去上一包才能得到本 5 秒内的行为增量：

```dart
factory BlePacket.deltaFrom(BlePacket current, BlePacket previous) {
  return BlePacket(
    timestamp: current.timestamp,
    strC:  (current.strC  - previous.strC ).clamp(0, 999),  // 本5秒应激次数
    strD:  (current.strD  - previous.strD ).clamp(0, 999),  // 本5秒应激秒数
    shivC: (current.shivC - previous.shivC).clamp(0, 999),  // 本5秒发抖次数
    shivD: (current.shivD - previous.shivD).clamp(0, 999),  // 本5秒发抖秒数
    paceD: (current.paceD - previous.paceD).clamp(0, 999),  // 本5秒踱步秒数
    playD: (current.playD - previous.playD).clamp(0, 999),  // 本5秒玩耍秒数
    rollC: (current.rollC - previous.rollC).clamp(0, 999),  // 本5秒打滚次数
    battery: current.battery,   // 直接用瞬时值
    rssi: current.rssi,
  );
}
```

`.clamp(0, 999)`：防止设备重启后累计值归零导致差值为负数。

**示例演示（理解差值计算）：**

| 时刻 | 收到的原始包（累计值） | 计算差值 | 差值包（本5秒增量） |
|-----|-------------------|---------|--------------------|
| T=0 | `str_c=0, pace_d=0` | 第一包，暂存 | — |
| T=5s | `str_c=2, pace_d=15` | 2-0=2, 15-0=15 | `strC=2, paceD=15` |
| T=10s | `str_c=2, pace_d=28` | 2-2=0, 28-15=13 | `strC=0, paceD=13` |
| T=15s | `str_c=5, pace_d=28` | 5-2=3, 28-28=0 | `strC=3, paceD=0` |
| T=20s（重启）| `str_c=0, pace_d=0` | 0-5=-5 → clamp → 0 | `strC=0, paceD=0` |

### 3.3 行为状态判断（差值包 → 枚举）

**文件：** `lib/models/models.dart` — `BlePacket.behaviorState` getter

⚠️ **必须传入差值包**，不能直接用原始累计包（累计值会永远满足高焦虑条件）

```dart
PetBehaviorState get behaviorState {
  if (shivD > 2) return PetBehaviorState.shivering;      // 发抖 > 2秒/5秒
  if (strC >= 1 || strD > 3) return PetBehaviorState.stressed;  // 有应激
  if (paceD > 3) return PetBehaviorState.pacing;          // 踱步 > 3秒/5秒
  if (playD > 3) return PetBehaviorState.playing;         // 玩耍 > 3秒/5秒
  return PetBehaviorState.calm;                           // 其余均为平静
}
```

**判断优先级（高→低）：** `shivering > stressed > pacing > playing > calm`

### 3.4 焦虑分计算（差值包 → 0-100分）

**文件：** `lib/models/models.dart` — `BlePacket.anxietyScore` getter

```dart
int get anxietyScore {
  int score = 0;
  score += (strC * 20).clamp(0, 40);   // 每次应激 +20分，上限 40
  score += (paceD * 3).clamp(0, 30);   // 踱步每秒 +3分，上限 30
  score += (shivD * 6).clamp(0, 24);   // 发抖每秒 +6分，上限 24
  score += (strD * 2).clamp(0, 10);    // 应激时长 +2分/秒，上限 10
  return score.clamp(0, 100);          // 最终截断到 0-100
}
```

**分值构成示例：**

| 场景 | strC | paceD | shivD | strD | 原始分 | 截断后 |
|-----|------|-------|-------|------|--------|--------|
| 完全平静 | 0 | 0 | 0 | 0 | 0 | 0 |
| 轻度踱步 | 0 | 5秒 | 0 | 0 | 15 | 15 |
| 一次应激 | 1 | 0 | 0 | 3 | 20+6=26 | 26 |
| 中度焦虑 | 2 | 8秒 | 0 | 5 | 40+24+10=74 | 74 |
| 极度发抖 | 0 | 0 | 4秒 | 0 | 24 | 24 |
| 高度应激+踱步 | 2 | 10秒 | 3秒 | 8 | 40+30+18+10=98 | 98 |

### 3.5 活动量分计算

```dart
int get activityScore {
  int score = 0;
  score += (playD * 10).clamp(0, 60);  // 玩耍每秒 +10分，上限 60
  score += (rollC * 10).clamp(0, 30);  // 打滚每次 +10分，上限 30
  score += (strC * 3).clamp(0, 10);    // 轻微应激也算活跃 +3分/次，上限10
  return score.clamp(0, 100);
}
```

**用途：** 活动量分主要用于判断昏睡（F状态）：`activityScore < 3` + 白天时段 + 无其他信号 → 疑似昏睡。

### 3.6 完整 _onPacket 处理流程

```
每 5 秒收到一个 rawPacket（累计值包）
           │
           ▼
    ① 更新电池 / RSSI
           │
           ▼
    ② 差值计算：delta = BlePacket.deltaFrom(rawPacket, _latestPacket)
       _latestPacket = rawPacket（保存为下次差值基准）
           │
           ▼
    ③ 更新 _recentDeltas（最近4包差值列表，用于A方案）
           │
           ▼
    ④ A方案：计算加权均值焦虑分
       weightedScore = Σ(delta[i].anxietyScore × weight[i]) / Σ(weight[i])
       权重：[0.5, 0.3, 0.15, 0.05]（最新→最旧）
           │
           ▼
    ⑤ B方案：状态确认
       rawState = delta.behaviorState
       if rawState == _pendingState: _pendingStateCount++
         if _pendingStateCount >= 2: _confirmedState = rawState ✅
       else: _pendingState = rawState; _pendingStateCount = 1
           │
           ▼
    ⑥ _checkAlerts(delta)
       ├─ 累加今日各状态时长（_todayPacingSeconds 等）
       ├─ 今日应激事件计数（_todayStressEventCount）
       ├─ 发抖连续秒追踪 → shiver_alert
       ├─ 应激频次追踪 → stress_frequent
       ├─ 踱步连续秒追踪 → pacing_long
       ├─ 昏睡连续秒追踪 → lethargy
       ├─ 夜间应激计数 → sleep_disturbed
       └─ 活动量兜底 → activity
           │
           ▼
    ⑦ _updateFeedingSession(delta)
       喂食会话中：每5分钟记录一个 BehaviorSnapshot
       平静检测：strC==0 && paceD<3 && shivC==0 → 准备自动结束会话
           │
           ▼
    ⑧ notifyListeners()
       → BehaviorStateCard 刷新状态显示
       → FeedingTimerCard 刷新计时
       → StressChartCard 刷新趋势
```

---

## 4. 焦虑分平滑方案：A+B 联合

### 4.1 问题背景：为什么需要平滑

原始差值包每5秒一包，单包焦虑分因行为短暂变化可能出现 `60→0→60` 的跳变，导致：
- **UI 数字抖动**：焦虑分数字像心电图，用户不知道该相信哪个数字
- **状态乱跳**：行为状态每5秒在 calm ↔ stressed 之间切换，误导用户
- **频繁预警**：单包噪声触发预警，用户很快产生"预警疲劳"

### 4.2 A 方案：滑动窗口加权平均（用于焦虑分展示）

**原理：** 维护最近4包差值包，对焦虑分做加权平均，最新包权重最高。

```
权重（最新 → 最旧）：
  w[0] = 0.50  ← 最新包（T）
  w[1] = 0.30  ← 上一包（T-5s）
  w[2] = 0.15  ← 前两包（T-10s）
  w[3] = 0.05  ← 前三包（T-15s）

加权焦虑分 = (score[0]×0.50 + score[1]×0.30 + score[2]×0.15 + score[3]×0.05)
             ÷ (0.50 + 0.30 + 0.15 + 0.05)
           = 加权和 / 1.00
```

**效果演示（从 60 突然变 0，再回到 60）：**

| 包序 | 原始分 | A方案显示分 | 变化描述 |
|-----|--------|-----------|---------|
| T=0 | 60 | 60 | 初始高焦虑 |
| T+5s（下包=0） | 0 | 0×0.5+60×0.3+60×0.15+60×0.05=30 | **不会瞬跌，平滑降低** |
| T+10s（继续=0） | 0 | 0×0.5+0×0.3+60×0.15+60×0.05=12 | 缓慢降低 |
| T+15s（继续=0） | 0 | 0 | 全部清零 |
| T+20s（跳回=60） | 60 | 60×0.5+0+0+0=30 | **不会瞬升，平滑上升** |
| T+25s（继续=60） | 60 | 60×0.5+60×0.3+0+0=48 | 继续上升 |
| T+30s（继续=60） | 60 | 60×0.5+60×0.3+60×0.15+0=57 | 趋近稳定 |

**代码实现：**
```dart
// pet_health_provider.dart
static const List<double> kAnxietyWeights = [0.5, 0.3, 0.15, 0.05];

int get currentAnxietyScore {
  if (_recentDeltas.isEmpty) return 0;
  double weightedSum = 0;
  double weightSum = 0;
  for (int i = 0; i < _recentDeltas.length && i < kAnxietyWeights.length; i++) {
    weightedSum += _recentDeltas[i].anxietyScore * kAnxietyWeights[i];
    weightSum += kAnxietyWeights[i];
  }
  return weightSum > 0 ? (weightedSum / weightSum).round() : 0;
}
```

### 4.3 B 方案：连续2包状态确认（用于行为状态切换）

**原理：** 候选状态需连续出现 ≥ 2 包（≥ 10秒）才正式更新 `_confirmedState`，单包噪声不触发切换。

```
流程：
每包计算 rawState = delta.behaviorState
   │
   ├─ rawState == _pendingState？
   │    ├─ 是 → _pendingStateCount++
   │    │        _pendingStateCount >= 2？
   │    │          ├─ 是 → _confirmedState = rawState ✅（正式切换）
   │    │          └─ 否 → 继续等待下一包
   │    └─ 否 → _pendingState = rawState
   │             _pendingStateCount = 1（重新开始等待）
   │
暴露 currentBehavior = _confirmedState（B方案确认状态）
```

**效果：**

| 包序 | rawState | _pendingState | _pendingStateCount | _confirmedState | 说明 |
|-----|---------|--------------|-------------------|----------------|------|
| T=0 | calm | calm | 1 | calm | 初始 |
| T+5s | stressed | stressed | 1 | calm | 开始等待 |
| T+10s（噪声消失）| calm | calm | 1 | calm | **单包噪声，状态不变** |
| T+5s | stressed | stressed | 1 | calm | 真实应激开始 |
| T+10s | stressed | stressed | 2 | **stressed** | ✅ 连续2包，正式切换 |

**代码：**
```dart
static const int kStateConfirmPackets = 2;

void _runBSchemeConfirmation(BlePacket delta) {
  final rawState = delta.behaviorState;
  if (rawState == _pendingState) {
    _pendingStateCount++;
    if (_pendingStateCount >= kStateConfirmPackets) {
      _confirmedState = rawState;
    }
  } else {
    _pendingState = rawState;
    _pendingStateCount = 1;
  }
}
```

### 4.4 A+B 联合设计与使用场景

| 数据用途 | 使用的方案 | 变量名 | 说明 |
|---------|-----------|--------|------|
| **UI 显示焦虑分（圆环/数字）** | A方案加权均值 | `currentAnxietyScore` | 平滑渐变，不跳动 |
| **UI 显示行为状态（标签/emoji）** | B方案确认状态 | `currentBehavior` | 稳定不闪烁，10秒延迟 |
| **预警触发判断（发抖/应激等）** | 原始差值包 | `_deltaPacket` | 最灵敏，不受平滑延迟影响 |
| **喂食平静检测** | 差值包直接判断 | `_isCalmState()` | `strC==0 && paceD<3 && shivC==0` |
| **BehaviorStateCard 顶部结论** | B方案确认状态 | `currentBehavior` | 主结论使用稳定状态 |
| **BehaviorStateCard 焦虑环** | A方案加权均值 | `currentAnxietyScore` | 数值平滑显示 |
| **每日统计时长累计** | 差值包 behaviorState | `_todayXxxSeconds` | 原始状态用于统计 |

### 4.5 方案对比评估

| 方案 | 优点 | 缺点 | 最终用途 |
|-----|------|------|---------|
| **原始单包** | 最快响应（5秒延迟） | 数值跳动，状态闪烁 | 预警判断（内部使用） |
| **A方案加权均值** | 焦虑分平滑渐变，用户友好 | 约15秒完全收敛 | UI 焦虑分展示 |
| **B方案2包确认** | 状态稳定，消除单包噪声 | 状态变化最多延迟10秒 | UI 行为状态展示 |
| **A+B联合** | 平滑+稳定两全 | 代码复杂度稍高 | **当前完整采用** |

---

## 5. 六大行为状态完整定义

### 状态总览表

| 状态代号 | Flutter枚举 | 中文名 | 英文名 | 硬件加速度特征 | behaviorState 判断条件 | UI颜色 | emoji |
|---------|-----------|-------|-------|--------------|----------------------|--------|-------|
| **状态 D** | `shivering` | 发抖 | Shivering | 近1g基线 + 高频(>10Hz)小幅颤抖 | `shivD > 2`（本5秒发抖时长>2秒） | 🔴 红色警示 | 🥶 |
| **状态 C** | `stressed` | 应激 | Stressed | 峰值1.5-2.0g，短促爆发(<0.5s) | `strC >= 1 OR strD > 3`（有应激事件或应激持续） | 🟠 橙色警示 | 😣 |
| **状态 A** | `pacing` | 踱步 | Pacing | 低频0.5-2Hz，大幅规律左右摆动 | `paceD > 3`（本5秒踱步>3秒） | 🟡 黄色提示 | 😰 |
| **状态 B** | `playing` | 玩耍 | Playing | 不规则高活跃，多轴混合大幅运动 | `playD > 3`（本5秒玩耍>3秒） | 🟢 绿色正常 | 🎾 |
| **状态 E** | `sleeping` | 睡眠 | Sleeping | 近恒定1g，Z轴静止 + 夜间时段 | 目前由昼夜时间辅助（待完善独立判断） | 🔵 蓝色静息 | 😴 |
| **状态 F** | `calm` / 候选昏睡 | 平静/昏睡 | Calm/Lethargy | 扁平1g线，Z轴静止，无其他信号 | 其他状态均不满足 → calm；白天+`activityScore<3` → 昏睡预警 | 🟢 绿色正常 | 😌 |

### 状态判断优先级

```
发抖(D) > 应激(C) > 踱步(A) > 玩耍(B) > 睡眠(E) > 平静/昏睡(F)

说明：
- 优先级决定 behaviorState 的返回值
- 多种信号同时存在时，取最高优先级状态
- 睡眠(E)目前缺少独立判断逻辑（TODO），主要由时间段辅助
- 昏睡(F)不是枚举中的独立值，而是在预警层检测（白天+activityScore<3）
```

### 各状态详细说明

#### 状态D — 发抖（Shivering）

- **硬件信号：** 加速度接近背景1g，但有高频（>10Hz）小幅振动叠加
- **判断条件：** `delta.shivD > 2`（本5秒内发抖时长超过2秒）
- **B方案输出：** 连续2包（10秒）确认才更新 currentBehavior
- **焦虑分贡献：** `shivD × 6`，上限24分（发抖是最严重的焦虑信号）
- **预警链接：** → shiver_alert（见第6章）
- **典型场景：** 极度恐惧（打雷）、疼痛、低体温

#### 状态C — 应激（Stressed）

- **硬件信号：** 加速度峰值1.5-2.0g的短促爆发，持续<0.5秒
- **判断条件：** `delta.strC >= 1`（有应激次数）或 `delta.strD > 3`（应激持续>3秒）
- **焦虑分贡献：** `strC × 20`（上限40）+ `strD × 2`（上限10）
- **预警链接：** → stress_frequent（见第6章）
- **典型场景：** 刺激反应（门铃、陌生人）、分离焦虑爆发

#### 状态A — 踱步（Pacing）

- **硬件信号：** 低频（0.5-2Hz）大幅规律性左右摆动
- **判断条件：** `delta.paceD > 3`（本5秒踱步超过3秒）
- **焦虑分贡献：** `paceD × 3`，上限30分
- **预警链接：** → pacing_long（见第6章）
- **典型场景：** 等待主人、预喂食焦虑、长期未解决的焦虑

#### 状态B — 玩耍（Playing）

- **硬件信号：** 不规则高活跃，多轴混合大幅运动，常有打滚
- **判断条件：** `delta.playD > 3`（本5秒玩耍>3秒）
- **焦虑分贡献：** 0（玩耍不计入焦虑分）
- **活动量贡献：** `playD × 10`（上限60）
- **典型场景：** 正常游戏互动、户外活动

#### 状态E — 睡眠（Sleeping）

- **硬件信号：** 几乎静止（接近恒定1g），Z轴无明显波动
- **判断条件：** 目前由昼夜时间（22:00-06:00）+ `activityScore < 3` 辅助判断（代码TODO完善）
- **预警链接：** 夜间睡眠质量 → sleep_disturbed（夜间应激计数）
- **睡眠质量分：** `total_sleep_secs/3600 × (100/6)` - `stress_penalty`（最终20-100）

#### 状态F — 平静/昏睡（Calm/Lethargy）

- **硬件信号：** 扁平1g线，Z轴静止，无其他行为信号
- **判断条件：** 所有其他状态均不满足时返回 `calm`
- **昏睡检测：** 白天（10:00-18:00）+ `activityScore < 3` + 无发抖/应激/踱步 → 累计时长 → lethargy预警
- **注意：** 健康睡眠（夜间）和昏睡（白天异常）在 enum 层都是 calm，区分依赖时段判断

---

## 6. 八大通知系统完整说明

### 通知架构设计

```
PetHealthProvider（检测触发条件）
    │ 通过回调，不直接持有 NotificationProvider
    │ onAlertNotification(type, title, body)
    │ onFeedingCompleted(session)
    │ onDailySummaryReady(summaryData)
    ▼
MainNavScreen（中间层注册回调）
    │ 接收回调后调用 NotificationProvider
    ▼
NotificationProvider（写入通知中心列表）
    + UI 显示顶部横幅 AlertBanner

设计原因：避免 Provider → Provider 循环依赖导致初始化崩溃
```

### 通知优先级规则

```
优先级顺序（高 → 低）：
shiver_alert > stress_frequent > lethargy > pacing_long > activity

- activity 横幅不覆盖任何高优先级横幅
- pacing_long / sleep_disturbed 通过回调直接写入通知中心，不独占顶部横幅
- sleep_disturbed 仅写通知中心，不设置顶部横幅
- 用户手动关闭横幅（dismissAlert）后，新 BLE 包可再次触发
```

---

### 通知 1：shiver_alert（发抖紧急预警）

**对应状态：** 状态D（shivering）

| 属性 | 详情 |
|------|------|
| **触发条件** | 连续发抖累计秒 `_continuousShiverSeconds >= kShiverThreshold` |
| **连续检测逻辑** | 每包 `delta.shivD > 0` → `_continuousShiverSeconds += 5`；否则归零并重置标志 |
| **频率控制** | 发抖中断（`shivD == 0`）时自动重置 `_shiverAlertFired = false`，下次发抖可重新触发 |
| **代码阈值（测试）** | `kShiverThreshold = 30`（30秒） |
| **正式阈值（生产）** | `180`（3分钟） |
| **优先级** | 🔴 最高 |
| **通知标题** | 🆘 紧急：{name} 持续发抖 |
| **通知正文** | 已连续发抖 X 分钟。可能原因：疼痛、低体温或极度恐惧。建议立即检查或联系兽医。 |
| **状态变量** | `_continuousShiverSeconds`、`_shiverAlertFired` |

```dart
// 检测逻辑
if (packet.shivD > 0) {
  _continuousShiverSeconds += samplingInterval;  // 每包+5秒
} else {
  _continuousShiverSeconds = 0;
  _shiverAlertFired = false;  // 中断后允许重新触发
}
if (_continuousShiverSeconds >= kShiverThreshold && !_shiverAlertFired) {
  _shiverAlertFired = true;
  // 触发通知...
}
```

---

### 通知 2：stress_frequent（应激频繁）

**对应状态：** 状态C（stressed）

| 属性 | 详情 |
|------|------|
| **触发条件** | 过去1小时内应激事件数 > `kStressFreqThreshold` 且冷却窗口已过 |
| **频次统计** | `_stressEventTimestamps`：每收到 `delta.strC > 0` 时，追加当前时间 × strC 次 |
| **1小时窗口** | 每包执行 `removeWhere(t → now.difference(t).inMinutes >= 60)`，动态维护窗口 |
| **冷却控制** | `_stressFreqLastFiredAt` 记录上次触发时间；距上次触发 < `kStressFreqCooldownMinutes` 分钟内不再触发 |
| **修复说明** | 旧版逻辑：每整点重置标志（每小时最多触发1次且依赖整点时机，不合理）；新版：基于上次触发时间的冷却窗口，更准确 |
| **代码阈值（测试）** | `kStressFreqThreshold = 3`，`kStressFreqCooldownMinutes = 15` |
| **正式阈值（生产）** | `kStressFreqThreshold = 10`，`kStressFreqCooldownMinutes = 60` |
| **优先级** | 🟠 高 |
| **通知标题** | ⚠️ {name} 应激反应频繁 |
| **通知正文** | 过去1小时内检测到 X 次应激动作（状态C）。建议查看焦虑源，考虑增加益生素用量或减少环境刺激。 |
| **状态变量** | `_stressEventTimestamps`（List）、`_stressFreqLastFiredAt`（DateTime?） |

```dart
// 检测逻辑
if (packet.strC > 0) {
  for (int i = 0; i < packet.strC; i++) {
    _stressEventTimestamps.add(now);  // 每次应激记录时间戳
  }
}
_stressEventTimestamps.removeWhere((t) => now.difference(t).inMinutes >= 60);
final count = _stressEventTimestamps.length;
final cooldownExpired = _stressFreqLastFiredAt == null ||
    now.difference(_stressFreqLastFiredAt!).inMinutes >= kStressFreqCooldownMinutes;
if (count > kStressFreqThreshold && cooldownExpired) {
  _stressFreqLastFiredAt = now;
  // 触发通知...
}
```

---

### 通知 3：pacing_long（踱步过长）

**对应状态：** 状态A（pacing）

| 属性 | 详情 |
|------|------|
| **触发条件** | 当前行为状态为 pacing 且已连续踱步 >= `kPacingLongThreshold` 秒 |
| **连续检测** | 每包 `state == pacing` → `_continuousPacingSeconds += 5`；其他状态时归零 |
| **频率控制** | `_pacingAlertDate`：记录本次触发日期；当日已触发则不再触发（每日最多1次） |
| **代码阈值（测试）** | `kPacingLongThreshold = 120`（2分钟） |
| **正式阈值（生产）** | `1800`（30分钟） |
| **优先级** | 🟠 高（写通知中心，设顶部横幅） |
| **通知标题** | ⚠️ {name} 持续焦虑踱步 |
| **通知正文** | 已连续踱步 X 分钟，焦虑状态未得到缓解。建议喂食 ZenBelly 或增加互动安抚。 |
| **状态变量** | `_continuousPacingSeconds`、`_pacingAlertDate`（DateTime?） |

---

### 通知 4：lethargy（白天异常昏睡）

**对应状态：** 状态F昏睡检测

| 属性 | 详情 |
|------|------|
| **触发条件** | 白天（10:00-18:00）连续静止 >= `kLethargyThreshold` 秒，且无发抖/应激/踱步信号 |
| **静止判断** | `packet.activityScore < 3 && packet.shivD == 0 && packet.strC == 0 && packet.paceD == 0` |
| **昼夜判断** | `isDaytime = now.hour >= 10 && now.hour < 18` |
| **连续计时** | 满足条件 → `_continuousLethargySecs += 5`；不满足时归零 |
| **频率控制** | `_lethargyAlertDate` + `_lethargyAlertFired`：每日最多1次；次日自动重置 |
| **代码阈值（测试）** | `kLethargyThreshold = 60`（1分钟） |
| **正式阈值（生产）** | `10800`（3小时） |
| **优先级** | 🟡 中 |
| **通知标题** | ⚠️ {name} 白天异常静止（疑似昏睡） |
| **通知正文** | 白天已连续静止超过 X 小时（状态F）。请注意区分健康睡眠与药物引起的昏睡，如异常请停药并联系兽医。 |
| **状态变量** | `_continuousLethargySecs`、`_lethargyAlertFired`、`_lethargyAlertDate` |

---

### 通知 5：sleep_disturbed（夜间睡眠异常）

**对应状态：** 夜间应激（22:00-06:00）

| 属性 | 详情 |
|------|------|
| **触发条件** | 夜间（22:00-06:00）应激事件总计 >= `kNightStressThreshold` 次 |
| **夜间统计** | 22:00 后每包应激自动累加 `_nightStressCount += packet.strC` |
| **重置时机** | 06:00 后第一包时重置（`_nightStressCount = 0`，`_sleepDisturbedFired = false`） |
| **频率控制** | `_sleepDisturbedFired`：每夜最多1次 |
| **代码阈值（测试）** | `kNightStressThreshold = 2`（2次） |
| **正式阈值（生产）** | `5`（5次） |
| **优先级** | 🟡 中（仅写通知中心，不设顶部横幅） |
| **通知标题** | 😴 {name} 昨夜睡眠不安 |
| **通知正文** | 昨夜检测到 X 次应激事件，睡眠质量较差。今天可适当增加日间安抚，晚餐前给予 ZenBelly。 |
| **状态变量** | `_nightStressCount`、`_sleepDisturbedFired`、`_nightStartDate` |

---

### 通知 6：activity（活动量偏低，兜底）

| 属性 | 详情 |
|------|------|
| **触发条件** | `delta.activityScore < 10` + 白天时段（10:00-18:00） |
| **频率控制** | 实时持续（只要满足条件就设置横幅，关闭后下包可再触发）；被更高优先级覆盖时不显示 |
| **优先级规则** | 仅在 `!_hasAlert || _alertType == 'activity'` 且无高优先级预警时才设置横幅 |
| **优先级** | 🟢 最低 |
| **通知标题** | ⚠️ 活动量偏低 |
| **通知正文** | {name} 今日活动量偏低，建议充分户外玩耍或联系兽医检查。 |

---

### 通知 7：feeding（喂食完成回调）

| 属性 | 详情 |
|------|------|
| **触发条件** | 用户点击"已喂食" + 宠物连续平静 >= 120秒（`_isCalmState()` 连续成立） |
| **平静判断** | `delta.strC == 0 && delta.paceD < 3 && delta.shivC == 0` |
| **超时保护** | 喂食会话最长 5400 秒（90分钟），超时强制结束 |
| **记录内容** | `FeedingSession`：喂食时间、`timeToCalm`（平静用时秒）、喂食前/后应激次数 |
| **类型** | ℹ️ 信息级 |
| **通知标题** | 🎉 {name} 完成喂食 |
| **通知正文** | 喂食后 X 分 Y 秒恢复平静。Time-to-Calm 已记录。 |
| **状态变量** | `_activeSession`、`_sessionElapsedSeconds`、`autoCompleteDelay = 120` |

---

### 通知 8：daily_summary（每日健康总结）

| 属性 | 详情 |
|------|------|
| **触发条件** | 每天 20:00–20:04 时间窗口内，每分钟轮询一次 |
| **频率控制** | `_lastDailySummaryDate`：记录上次触发日期，同日重复轮询不重复触发（5分钟窗口去重） |
| **修复说明** | 旧版为每5分钟触发（测试模式）；已恢复为生产模式（20:00-20:04） |
| **触发时机** | `_dailySummaryTimer`（每分钟检查）：`now.hour == 20 && now.minute < 5` |
| **包含数据** | 今日踱步/玩耍/应激/发抖/睡眠/昏睡秒数、喂食次数、**今日应激事件总计（独立日计数器 `_todayStressEventCount`）**、平均 Time-to-Calm、平均焦虑分 |
| **应激计数修复** | 旧版用 `_stressEventTimestamps.length`（仅含最近1小时），导致总结中应激次数偏低；新版使用跨天清零的独立计数器 `_todayStressEventCount` |
| **类型** | ℹ️ 信息级 |
| **通知标题** | 📊 {name} 今日健康总结 |
| **通知正文** | 踱步 X 分钟 / 玩耍 Y 分钟 / 应激 Z 次 / 喂食 N 次，今日平静趋势 +/-X% |

---

### 完整通知系统汇总表

| # | 通知 type | 状态 | 触发核心条件 | 频率/冷却 | 测试阈值 | 生产阈值 | 优先级 |
|---|---------|------|------------|---------|---------|---------|--------|
| 1 | `shiver_alert` | D 发抖 | 连续发抖 ≥ 阈值秒 | 发抖中断后重置，可再次 | 30s | 180s | 🔴 最高 |
| 2 | `stress_frequent` | C 应激 | 1h内应激 > 阈值次 | 冷却窗口后可再次 | 3次/冷却15min | 10次/冷却60min | 🟠 高 |
| 3 | `pacing_long` | A 踱步 | 连续踱步 ≥ 阈值秒 | 每日最多1次 | 120s | 1800s | 🟠 高 |
| 4 | `lethargy` | F 昏睡 | 白天连续静止 ≥ 阈值秒 | 每日最多1次 | 60s | 10800s | 🟡 中 |
| 5 | `sleep_disturbed` | 夜间应激 | 夜间应激 ≥ 阈值次 | 每夜最多1次 | 2次 | 5次 | 🟡 中 |
| 6 | `activity` | 活动量低 | activityScore < 10 + 白天 | 实时持续，被高优先级覆盖 | 同生产 | activityScore < 10 | 🟢 最低 |
| 7 | `feeding` | 喂食完成 | 喂食 + 平静 ≥ 120s | 每次喂食会话结束触发 | — | — | ℹ️ 信息 |
| 8 | `daily_summary` | 每日总结 | 每天 20:00–20:04 | 每日1次 | 已改回20:00 | 20:00–20:04 | ℹ️ 信息 |

---

## 7. 数据流与架构设计

### 完整数据流图

```
【硬件层】
Arduino + MPU-6050
  │  三轴加速度采样（~100Hz）
  │  固件：判断应激/发抖/踱步/玩耍
  │  累计计数器自增（str_c, shiv_d, pace_d 等）
  │  每5秒广播 JSON 数据包
  │  BLE GATT Notification
  ▼

【传输层】
MockBleService（开发）/ flutter_blue_plus（生产）
  │  Stream<BlePacket>（累计值包）
  ▼

【数据处理层】
PetHealthProvider._onPacket(rawPacket)
  │
  ├─ 差值计算 → delta（5秒增量包）
  │
  ├─ [A方案] _recentDeltas 滑动窗口 → currentAnxietyScore（平滑焦虑分）
  │
  ├─ [B方案] pendingState → confirmedState（稳定行为状态）
  │
  ├─ _checkAlerts → 8种预警触发
  │     └─ onAlertNotification 回调 → MainNavScreen → NotificationProvider
  │
  ├─ _updateFeedingSession → 喂食追踪 + 快照
  │     └─ onFeedingCompleted 回调 → MainNavScreen → NotificationProvider
  │
  └─ notifyListeners
        │
        ▼
【UI层】
BehaviorStateCard    ← currentBehavior + currentAnxietyScore + todayXxxSeconds
StatusCardsRow       ← todayPacingSeconds / todayPlaySeconds 等
StressChartCard      ← _stressChartData（14日趋势）
FeedingTimerCard     ← activeSession + sessionElapsedLabel
AlertBanner          ← hasAlert + alertMessage + alertType

        │
        ▼
【持久化层】
Firestore（云端）：feeding_sessions / daily_stress / journal_entries / pet_profile
SharedPreferences（本地）：宠物档案（毫秒级读取）/ 通知记录
```

### Firestore 路径规范

```
users/
  {uid}/
    pet_profile/
      main                     ← 宠物档案（merge写入）
    feeding_sessions/
      {sessionId}              ← feed_time, time_to_calm, stress_before/after
    journal_entries/
      {entryId}                ← date, stool/mood/appetite/energy emoji, notes
    daily_stress/
      {yyyy-MM-dd}             ← stress_score, is_after_treatment, label

注意：
  ✅ 新路径：users/{uid}/pet_profile/main
  ⚠️ 旧路径：users/{uid}/pet/profile（已废弃，仅作 fallback 读取兼容）
  ✅ 查询全部避免 where+orderBy 组合，防止 Firestore 复合索引要求
  ✅ 排序统一在内存中完成（数据量小）
```

---

## 8. 数据持久化架构

| 数据类型 | 存储位置 | 读取时机 | 写入时机 |
|---------|---------|---------|---------|
| 宠物档案 | SharedPreferences（主）+ Firestore（云备份） | App启动，登录后 loadPetForUser() | 用户保存编辑 |
| 喂食记录 | Firestore `feeding_sessions/` | 登录后加载最近30条 | 喂食会话结束 |
| 健康日志 | Firestore `journal_entries/` | 登录后加载最近60条 | 用户提交日志 |
| 每日压力点 | Firestore `daily_stress/{date}` | 登录后加载最近14天 | 喂食完成后 |
| 通知记录 | SharedPreferences `notifications_{uid}` | 登录后加载 | 每次触发通知 |

**三层加载策略（登录后）：**
1. **第1层：** SharedPreferences（本地，毫秒级，最快）→ 立即显示
2. **第2层：** Firestore pet_profile（云端，换机恢复场景）→ 无本地数据时 fallback
3. **第3层：** Firestore 历史数据（feeding/journal/stress，约3条并发 Future.wait）

---

## 9. 上线前必改清单

### 🔴 必须修改（上线前）

| # | 文件 | 变量/位置 | 当前值（测试） | 应改为（生产） |
|---|------|----------|--------------|--------------|
| 1 | `pet_health_provider.dart` | `kShiverThreshold` | `30` 秒 | `180` 秒（3分钟） |
| 2 | `pet_health_provider.dart` | `kStressFreqThreshold` | `3` 次 | `10` 次 |
| 3 | `pet_health_provider.dart` | `kStressFreqCooldownMinutes` | `15` 分钟 | `60` 分钟 |
| 4 | `pet_health_provider.dart` | `kPacingLongThreshold` | `120` 秒 | `1800` 秒（30分钟） |
| 5 | `pet_health_provider.dart` | `kLethargyThreshold` | `60` 秒 | `10800` 秒（3小时） |
| 6 | `pet_health_provider.dart` | `kNightStressThreshold` | `2` 次 | `5` 次 |
| 7 | `mock_ble_service.dart` | 整个文件 | MockBleService | 替换为 flutter_blue_plus 真实实现 |

### 🟡 建议修改（上线前评估）

| # | 说明 |
|---|------|
| 8 | `anxietyScore` 权重（strC×20, paceD×3, shivD×6）需数据科学家验证后调整 |
| 9 | `kStateConfirmPackets = 2`（B方案包数）可根据硬件噪声水平调整为1-3 |
| 10 | `kAnxietyWeights`（A方案权重）可根据用户体验测试调整 |
| 11 | 每日总结内容目前为估算值，接入真实云数据后需重写 `_triggerDailySummary` |
| 12 | Demo 历史数据（`_seedHistoricalSessions`）在真实用户首次启动时仍会显示 |

### 🔧 TODO 待实现

| # | 说明 | 文件 |
|---|------|------|
| T1 | 替换 MockBleService 为 flutter_blue_plus | `mock_ble_service.dart` |
| T2 | 宠物档案 GET/PUT 接入真实后端 API | `pet_health_provider.dart` |
| T3 | 喂食记录 POST /api/feeding-sessions | `pet_health_provider.dart` |
| T4 | 添加蓝牙权限声明（AndroidManifest.xml / Info.plist） | Android/iOS 配置 |
| T5 | BLE 断连重连逻辑 | 待创建 ble_connection_manager.dart |
| T6 | 通知持久化（目前关 App 后历史通知消失） | `notification_provider.dart` |
| T7 | 睡眠状态独立检测逻辑（目前 sleeping 缺少专项判断） | `models.dart` |

---

## 附录：关键常量速查

```dart
// ── BLE 数据采样 ──────────────────────────────────────────────────────────
const int samplingInterval = 5;           // 秒，每包代表时长

// ── A方案：加权平均焦虑分 ─────────────────────────────────────────────────
const List<double> kAnxietyWeights = [0.5, 0.3, 0.15, 0.05]; // 最新→最旧

// ── B方案：状态确认包数 ───────────────────────────────────────────────────
const int kStateConfirmPackets = 2;        // 连续2包（10秒）才切换状态

// ── 预警阈值（⚠️ 当前为测试值，上线前改回注释中的生产值）──────────────────
const int kShiverThreshold = 30;           // 发抖：测试30s / 生产180s
const int kStressFreqThreshold = 3;        // 应激频繁：测试3次 / 生产10次
const int kStressFreqCooldownMinutes = 15; // 应激冷却：测试15min / 生产60min
const int kPacingLongThreshold = 120;      // 踱步过长：测试120s / 生产1800s
const int kLethargyThreshold = 60;         // 昏睡：测试60s / 生产10800s
const int kNightStressThreshold = 2;       // 夜间应激：测试2次 / 生产5次

// ── 喂食相关 ──────────────────────────────────────────────────────────────
const int autoCompleteDelay = 120;         // 喂食后至少120秒才自动判定平静
const int sessionTimeout = 5400;           // 喂食会话最大时长：90分钟
const int snapshotInterval = 300;          // 喂食快照间隔：每5分钟

// ── 单包焦虑分权重 ────────────────────────────────────────────────────────
// strC × 20（上限40）+ paceD × 3（上限30）+ shivD × 6（上限24）+ strD × 2（上限10）
// 满分 = 40 + 30 + 24 + 10 = 104，截断至100
```

---

## 版本信息与部署链接

| 项目 | 值 |
|------|---|
| **文档版本** | v3.0（2025-07） |
| **App commit（main）** | `796944a` |
| **Pages commit（gh-pages）** | `351f9f6` |
| **沙盒预览** | https://5060-ix0gn3gj900bc21kuk2wm-02b9cc79.sandbox.novita.ai |
| **GitHub Pages** | https://largevillachongyang-a11y.github.io/calmpaws-petoteco/ |
| **GitHub 仓库** | https://github.com/largevillachongyang-a11y/calmpaws-petoteco |

---

*文档生成：Calm Paws Engineering | 2025-07 | v3.0*
