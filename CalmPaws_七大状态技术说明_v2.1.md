# CalmPaws 七大行为状态技术说明文档
**版本：v2.1 | 日期：2025年7月**
**主要更新：采样率升级至100Hz / pacing双重验证 / 焦虑分算法说明 / 数据清洗目标更新**

**v2.1更新说明（基于代码核查）：**
- 修复焦虑分架构图旧值（strC×20→×10，strD×2→×1）
- 修复应激频繁冷却时间内部矛盾（统一为15分钟测试值/60分钟生产值）
- 修复E2异常昏睡触发条件（删除不存在的str_c=0判断）
- 新增睡眠入口阈值kSleepEntryThreshold（calm持续30分钟才算入睡）
- 新增服务器端睡眠计时同步架构说明（B方案）
- 新增加权平均焦虑分A方案说明
- 新增kMinPlaySeconds活动量告警参数
- 新增kDebugMode切换机制说明
- 更新固件版本号至V7.2

---

## 概览

CalmPaws 项目通过三层协同判断，识别狗的7种行为状态：

```
第一层：ESP32 硬件（100Hz 原始采样 + 物理算法）
    ↓ 上传原始XYZ
第二层：服务器（100Hz 直接推理 + AI模型 + 物理算法 + pacing双重验证）
    ↓ 推送JSON计数包
第三层：APP（差值解包 + 状态确认 + 睡眠细分）
    ↓ 显示最终状态
```

**判断优先级（高→低）：**
```
shivering > stressed > pacing > playing > calm → sleepNormal / sleepAbnormal
```

---

## 七大状态详细说明

---

### 状态 D｜Shivering 发抖

| 项目 | 内容 |
|------|------|
| **APP枚举** | `PetBehaviorState.shivering` |
| **APP显示** | 发抖 / Shivering 🥶 |
| **UI颜色** | 红色警告 |
| **优先级** | 最高（第1位）|

#### 狗的行为表现
- 全身持续细微震颤，幅度极小但频率高
- 肌肉紧绷、蜷缩、不敢移动
- 典型场景：长期分离焦虑、恐惧等待（动物医院门口）、雷雨天、陌生环境

#### 与"甩身抖毛"的区别
| | 发抖（shivering） | 甩身（shaking） |
|--|-----------------|----------------|
| G力范围 | 0.8~1.2g（接近静止） | >2g（大幅运动） |
| 幅度 | 极小（delta_g 0.03~0.2） | 极大（delta_g >1.0） |
| 持续时间 | 数十秒~数分钟 | 1~2秒 |
| 含义 | 焦虑/恐惧 | 正常甩干/甩毛 |

#### 判断方案：**物理阈值算法（服务器端 algorithm.py）**

> **v2.0变更说明**：v2.0 AI模型已去除 shivering 训练类（仅保留 calm/pacing/playing 三类）。发抖检测改回物理阈值算法，在 `algorithm.py` 中直接判断。

```
检测条件（每个100Hz采样点）：
  micro_tremor 条件（高频细振）：
    0.8g ≤ G力 ≤ 1.2g           ← 接近静止，身体几乎不移动
    AND 0.03 ≤ delta_G ≤ 0.2    ← 相邻采样点小幅波动（高频细振）

  触发条件：
    一个推理窗口内 micro_tremor_count ≥ 3
    → shiv_c（发抖次数）+1
    → shiv_d（发抖秒数）累加

APP层判断（差值包）：
    shivD > 2  →  PetBehaviorState.shivering
```

#### 数据来源
- **v2.0：物理阈值算法**（algorithm.py 直接检测，不依赖AI模型）
- 参考文献：见本文档"算法设计参考文献"第一节

---

### 状态 C｜Stressed 应激

| 项目 | 内容 |
|------|------|
| **APP枚举** | `PetBehaviorState.stressed` |
| **APP显示** | 应激 / Stressed 😣 |
| **UI颜色** | 橙色警告 |
| **优先级** | 第2位（仅低于发抖）|

#### 狗的行为表现
- 突然猛地抖一下或几下，幅度明显，持续时间短
- 全身紧绷、猛然弓起身体、瞬间站起或卧倒
- 典型场景：听到巨响（鞭炮/雷声）、陌生人突然靠近、被碰触敏感部位

#### 与"发抖"的区别
| | 应激（stressed） | 发抖（shivering） |
|--|----------------|-----------------|
| G力范围 | 1.2~2.2g | 0.8~1.2g |
| 幅度 | 大（delta_G > 0.3） | 小（delta_G 0.03~0.2）|
| 频率 | 低频冲击（1~3次/秒） | 高频细振（>5次/秒）|
| 持续时间 | 1~5秒（瞬时） | 30秒~数分钟（持续）|
| 危险程度 | 中（瞬时应激） | 高（持续焦虑）|

#### 判断方案：**物理算法（服务器端）**

```
检测条件（每个100Hz采样点）：
  macro_tremor 条件（中等冲击抖动）：
    1.2g ≤ G力 ≤ 2.2g           ← 中等力度区间（文献[1]犬步行峰值1.7~2.6g有重叠，靠后续条件区分）
    AND delta_G > 0.3             ← 相邻采样点非节律性大幅跳变（区别于步行的平滑节律变化）
    AND max_G < 4.0               ← 排除跳跃/碰撞等极端运动（>4g时判断为玩耍/意外）

  触发条件：
    一个推理窗口内 macro_tremor_count ≥ 2  ← 要求至少2点，过滤单点噪声
    → str_c（应激次数）+1
    → str_d（应激秒数）累加

APP层判断（差值包）：
    strC ≥ 2  OR  strD > 3  →  PetBehaviorState.stressed
    （要求strC≥2是为了过滤单次噪声误报）
```

**⚠️ 已知局限：**
> 犬正常步行峰值G（1.7~2.6g，见文献[1] PMC12076518）与应激G值范围（1.2~2.2g）存在重叠。现行方案靠 `delta_G>0.3（非节律跳变）+ macro_count≥2` 组合条件区分，但无独立犬类应激行为的实测G值数据验证。**此阈值属于工程估算，待真实传感器数据采集后重新标定。**

#### 数据来源
- **不需要训练数据**，纯物理阈值判断
- 应激是短时中等G力冲击，物理特征比AI更直接可靠
- 参考文献：见本文档"算法设计参考文献"第二节

---

### 状态 A｜Pacing 踱步

| 项目 | 内容 |
|------|------|
| **APP枚举** | `PetBehaviorState.pacing` |
| **APP显示** | 踱步 / Pacing 😰 |
| **UI颜色** | 黄色 |
| **优先级** | 第3位 |

#### 狗的行为表现
- 在固定区域来回走动，步伐有规律节奏
- 频繁重复同一路线，无目的性
- 典型场景：等待主人归来、被关在小空间、焦虑时的刻板行为

#### 传感器特征
| 特征 | 数值范围 |
|------|---------|
| RMS（运动强度） | 中等（0.5~0.8g） |
| 频率 | 规律节律，0.5~2Hz 周期性摆动 |
| 多轴相关性 | 规律左右或前后摆动 |

#### 判断方案：**AI模型 + 物理算法双重验证（服务器端）**

```
第一步：AI模型判断
  数据流：
    ESP32 → 100Hz原始XYZ（无降采样）
    服务器 → 取最近300行（3秒@100Hz窗口）
    → DSP提取39个特征（每轴13个：均值/RMS/偏度/峰度/FFT偏度/峰度/8个频段能量）
    → TFLite模型推理 → 输出3类概率（calm/pacing/playing）
    → pacing概率 > 55%（置信度阈值）→ 候选pacing

第二步：物理算法验证（RMS验证）
  对同一300行窗口计算合加速度RMS：
    G = sqrt(x²+y²+z²)
    g_centered = G - mean(G)
    rms = sqrt(mean(g_centered²))

  验证规则：
    rms > 0.15  →  确认有运动 → 最终判定为 pacing ✅
    rms ≤ 0.15  →  判定为静止（AI误判）→ 降级为 calm ❌

⚠️ 为什么需要双重验证：
  纯Pacing（原地踱步）与calm（静止）的传感器信号高度相似
  AI模型单独判断准确率仅50~55%
  加入RMS物理验证后，可过滤AI对静止状态的误报
  数据支撑：calm的rms最大值0.146，pacing的rms最小值0.139，边界清晰

第三步：APP层判断（差值包）：
  paceD > 3  →  PetBehaviorState.pacing
```

#### 训练数据来源（Kaggle清洗 - 当前版本）
```
原始标签 → CalmPaws标签
Pacing    → pacing（纯原地踱步，最纯净）

丢弃标签：
Walking  → 丢弃（步行与玩耍信号重叠，污染边界）
Trotting → 丢弃（小跑介于pacing和playing之间，信号模糊）

数据量：Pacing 771s ≈ 13分钟（200个窗口）
```

---

### 状态 B｜Playing 玩耍

| 项目 | 内容 |
|------|------|
| **APP枚举** | `PetBehaviorState.playing` |
| **APP显示** | 玩耍 / Playing 🎾 |
| **UI颜色** | 绿色（积极） |
| **优先级** | 第4位 |

#### 狗的行为表现
- 奔跑、扑咬、追逐、跳跃，动作幅度大且不规则
- 多轴同时有大幅运动，方向随机
- 典型场景：和主人互动、玩球、追逐其他狗

#### 传感器特征
| 特征 | 数值范围 |
|------|---------|
| RMS | 高（均值0.93g） |
| 频率 | 不规律宽频，无固定周期 |
| 多轴 | X/Y/Z均有大幅波动 |
| 峰值G | 可达4~16g（跳跃/碰撞）|

#### 判断方案：**AI模型（服务器端）**

```
数据流同pacing第一步，模型输出3类概率：
  playing概率 > 55% → 判定为playing
  → play_d（玩耍秒数）累加

APP层判断（差值包）：
  playD > 3  →  PetBehaviorState.playing
```

#### 训练数据来源（Kaggle清洗 - 当前版本）
```
原始标签 → CalmPaws标签
Playing   → playing（玩耍）
Galloping → playing（奔跑）
Trotting  → playing（小跑，高活动量）
Walking   → playing（步行，高活动量）

数据量：约200个窗口
```

---

### 状态 F｜Calm 平静

| 项目 | 内容 |
|------|------|
| **APP枚举** | `PetBehaviorState.calm` |
| **APP显示** | 平静 / Calm 😌 |
| **UI颜色** | 绿色（正常） |
| **优先级** | 第5位（兜底）|

#### 狗的行为表现
- 清醒但不动：趴着休息、坐着观察、站立等待
- 偶有轻微抬头、甩尾等小动作
- 与睡眠的区别：清醒状态，持续时间较短，随时可能切换

#### 传感器特征
| 特征 | 数值范围 |
|------|---------|
| RMS | 极低（均值0.031g，最大0.146g） |
| G力 | ≈1g（接近静止） |
| 频率 | 低频为主，偶发轻微波动 |
| delta_G | 极小但不为零（有微小姿势调整）|

#### 判断方案：**AI模型（服务器端）+ 兜底逻辑**

```
方案一：AI模型输出calm概率 > 55%
方案二：pacing被AI候选，但rms ≤ 0.15 → 降级为calm
方案三：其余状态均不满足 → 默认归为calm

APP层判断：
  前4个状态（shivering/stressed/pacing/playing）均不满足
  且sleepNormal/sleepAbnormal条件也不满足
  →  PetBehaviorState.calm
```

#### 训练数据来源（Kaggle清洗）
```
原始标签 → CalmPaws标签
Lying on chest → calm（趴卧）
Sitting        → calm（坐立）
Standing       → calm（站立）

数据量：Lying 10,313s + Sitting 5,094s + Standing 4,487s ≈ 330分钟
```

---

### 状态 E1｜SleepNormal 正常睡眠

| 项目 | 内容 |
|------|------|
| **APP枚举** | `PetBehaviorState.sleepNormal` |
| **APP显示** | 正常睡眠 / Sleeping 😴 |
| **UI颜色** | 蓝色 |
| **优先级** | 第6位（calm细分）|

#### 狗的行为表现
- 深度睡眠，长时间不动
- 周期性翻身、腿部轻微抽动（REM睡眠）
- 典型时段：夜间22:00~08:00，也可能午睡

#### 与calm的区别
```
calm        = 清醒静止，持续几分钟，随时切换
sleepNormal = calm基础上，连续静止 ≥ 30分钟 + 有翻身信号(roll_c > 0)，持续数小时
```

#### 判断方案：**APP层推断**（不需要模型）

```
前提条件：BlePacket层状态 = calm

判断逻辑（两步）：

  第一步：入睡门槛判断
    calm 持续时间 < kSleepEntryThreshold（30分钟）
      → 仍显示 calm（平静休息），不进入睡眠判断
      → 此阶段 roll_c 不触发睡眠状态切换

    calm 持续时间 ≥ kSleepEntryThreshold（30分钟）
      → 进入第二步睡眠状态判断

  第二步：入睡后睡眠质量判断
    如果检测到 roll_c 增量（有翻身/微动信号）：
      → 重置无翻身计时器
      → _sleepState = sleepNormal ✅

关键字段：
  roll_c：ESP32 Z轴极性反转检测
    z_first > 0.6g（背部朝上） AND z_last < -0.6g（腹部朝上）
    → roll_c + 1（计为翻身一次）

APP确认条件：
  _confirmedState == calm  AND  _sleepState == sleepNormal
  →  最终显示 sleepNormal
```

#### ⚠️ 睡眠计时的架构说明（重要）

> **服务器端维护计时 + APP同步（B方案）**：
> 睡眠相关计时（`continuous_calm_sec`、`sleep_no_roll_sec`、`sleep_state`）由**服务器端 `server.py` 的 `_update_sleep_state()` 函数**维护，而非APP本地独立计时。
>
> APP通过每次 `/api/status` 轮询响应中的这三个字段同步服务器状态，即使APP重启或重连，睡眠计时也不会丢失。
>
> APP本地的 `_continuousCalmSeconds` 等变量仍作为备份计算，但以服务器数据为准（`_onSleepStateFromServer()` 回调覆盖本地值）。

#### 数据来源
- **不需要训练数据**，APP层根据calm + roll_c推断
- roll_c由ESP32物理算法检测Z轴翻转产生

---

### 状态 E2｜SleepAbnormal 异常昏睡

| 项目 | 内容 |
|------|------|
| **APP枚举** | `PetBehaviorState.sleepAbnormal` |
| **APP显示** | 异常昏睡 / Lethargic ⚠️ |
| **UI颜色** | 警告色 |
| **优先级** | 第7位（sleepNormal细分）|

#### 狗的行为表现
- 长时间一动不动，无任何翻身或微动
- 白天长时间昏睡，呼叫无反应
- 典型场景：生病、中暑、服药后过度镇静、抑郁

#### 与sleepNormal的区别
```
sleepNormal  = calm（≥30分钟）+ 有roll_c（健康的自然睡眠有翻身）
sleepAbnormal = calm（≥30分钟）+ 连续2小时无roll_c（不正常的静止）
```

#### 判断方案：**APP层推断**（不需要模型）

```
前提条件：BlePacket层状态 = calm，且已达到入睡门槛（≥30分钟）

判断逻辑：
  观察窗口：2小时（kSleepAbnormalThreshold = 7200秒）
            调试模式下：10分钟（kDebugMode = true时 = 600秒）

  如果在入睡后：
    roll_c = 0  连续超过 kSleepAbnormalThreshold 秒（2小时）
    → _sleepState = sleepAbnormal
    → 触发 sleep_abnormal 告警推送

⚠️ 注意：触发条件仅检测 roll_c = 0（无翻身），
   不检测 str_c（应激次数不影响此判断）。

告警内容：
  "已连续 X 分钟未检测到翻身/微动（roll_c = 0）"
  建议主人检查宠物状态

APP确认条件：
  _confirmedState == calm  AND  _sleepState == sleepAbnormal
  →  最终显示 sleepAbnormal + 发送告警
```

#### 数据来源
- **不需要训练数据**，APP层纯逻辑推断
- 依赖：calm状态（AI模型）+ roll_c计数（ESP32物理算法）+ 时间累计（服务器端+APP层）

---

## APP 焦虑分算法说明

### 焦虑分（anxietyScore）0-100

焦虑分基于每5秒差值包实时计算，反映当前5秒内宠物的焦虑程度。

```dart
int get anxietyScore {
  int score = 0;
  score += (strC * 10).clamp(0, 20);                // 应激次数 × 10，上限20（⚠️ 阈值未验证，降低误报影响）
  score += (paceD * 3).clamp(0.0, 30.0).toInt();   // 踱步秒数 × 3，上限30
  score += (shivD * 6).clamp(0.0, 40.0).toInt();   // 发抖秒数 × 6，上限40（物理算法可靠，提升权重）
  score += (strD * 1).clamp(0.0, 10.0).toInt();    // 应激时长 × 1，上限10（同样降低）
  return score.clamp(0, 100);
}
```

#### 各项权重说明

| 信号 | 权重 | 上限 | 判断依据 | 可靠性 |
|------|------|------|---------|--------|
| 应激次数(strC) | ×10/次 | 20分 | 物理算法，阈值未验证，降低权重减少误报影响 | ⭐⭐⭐ |
| 应激时长(strD) | ×1/秒 | 10分 | 同上 | ⭐⭐⭐ |
| 发抖时长(shivD) | ×6/秒 | 40分 | 物理算法，阈值有文献支撑，可靠 | ⭐⭐⭐⭐⭐ |
| 踱步时长(paceD) | ×3/秒 | 30分 | AI模型+物理双验证，中等可靠 | ⭐⭐⭐ |

#### ⚠️ 踱步权重说明

**为什么踱步权重较低（上限仅30分，且可靠性标注为中等）：**

1. **模型准确率限制**：当前pacing识别准确率约78%，存在约22%的误判率（主要是calm被误判为pacing）
2. **双重验证已过滤部分误判**：加入RMS物理验证后，将静止误判为pacing的情况大幅减少
3. **避免误导用户**：若踱步权重过高（如×10/秒），一次误判会导致焦虑分虚高，用户会认为产品不准确
4. **实际影响**：踱步信号满5秒上限（paceD=5时）贡献15分；实际典型贡献约9~15分，不会主导整体分值

#### 焦虑分示例场景

| 场景 | 典型数据 | 焦虑分 |
|------|---------|--------|
| 完全平静 | strC=0, shivD=0, paceD=0 | 0分 |
| 轻度焦虑（踱步） | paceD=4 | 12分 |
| 中度焦虑（应激1次） | strC=1, strD=2 | 12分 |
| 高度焦虑（发抖） | shivD=3 | 18分 |
| 严重焦虑（应激+发抖） | strC=2, shivD=3 | 38分 |

### 焦虑分平滑机制（A方案）

**UI展示的焦虑分并非原始单包计算值，而是最近4包的加权平均**，目的是消除单包噪声导致的数值跳动：

```dart
// 权重：最新包0.5，前一包0.3，再前0.15，最早0.05
static const List<double> kAnxietyWeights = [0.5, 0.3, 0.15, 0.05];
// 维护最近4包差值，加权计算展示焦虑分
final List<BlePacket> _recentDeltas = [];
```

| 包序 | 权重 | 说明 |
|------|------|------|
| 最新包（当前5秒） | 0.50 | 主要贡献 |
| 前一包（-5秒） | 0.30 | 次要贡献 |
| 前两包（-10秒） | 0.15 | 轻微平滑 |
| 前三包（-15秒） | 0.05 | 极小贡献 |

> **效果**：单次短暂应激不会造成焦虑分骤升，需要持续2~3包相同信号才会体现出较大变化，用户体验更稳定。

#### 活动尽兴分（activityScore）0-100

```dart
int get activityScore {
  int score = 0;
  score += (playD * 10).clamp(0.0, 60.0).toInt();  // 玩耍每秒 +10分，上限60
  score += (rollC * 10).clamp(0, 30);               // 打滚每次 +10分，上限30
  score += (strC * 3).clamp(0, 10);                 // 轻微应激也算活跃
  return score.clamp(0, 100);
}
```

---

## 系统架构总览

```
┌─────────────────────────────────────────────────────────┐
│                    ESP32 硬件层                          │
│  采样：ISM330DHCX @ 100Hz                               │
│  输出：原始XYZ（每次500行）+ 心跳包                      │
│                                                         │
│  物理计算（每3秒窗口@100Hz）：                            │
│  ├── micro_tremor_count → 发抖信号                       │
│  ├── macro_tremor_count → 应激信号                       │
│  └── Z轴翻转检测 → roll_c 翻身计数                       │
└─────────────────────┬───────────────────────────────────┘
                      │ HTTP上传 XYZ + roll_c/str_c等
┌─────────────────────▼───────────────────────────────────┐
│                    服务器层                              │
│                                                         │
│  inference.py（AI推理）：                                │
│  100Hz → 无降采样 → 300行窗口（3秒）                     │
│  → DSP 39特征（FFT_LENGTH=16）→ TFLite模型              │
│  → 输出：calm / pacing / playing 概率                    │
│  → pacing候选 + RMS物理验证（rms > 0.15）               │
│                                                         │
│  物理算法：                                              │
│  ├── stressed：macro_tremor≥2(G:1.2~2.2,dG>0.3)        │
│  │           ⚠️ 与步行G值有重叠，靠组合条件区分           │
│  ├── shivering：物理阈值（G:0.8~1.2,dG:0.03~0.2,micro≥3）│
│  └── roll_c：Z轴翻转计数                                 │
│                                                         │
│  睡眠计时维护（_update_sleep_state）：                    │
│  ├── continuous_calm_sec：calm持续时长                   │
│  ├── sleep_no_roll_sec：入睡后无翻身时长                  │
│  └── sleep_state：当前睡眠状态（APP同步用）               │
│                                                         │
│  输出JSON：str_c/str_d/shiv_c/shiv_d/                   │
│            pace_d/play_d/roll_c/battery/                │
│            sleep_state/sleep_no_roll_sec/               │
│            continuous_calm_sec                          │
└─────────────────────┬───────────────────────────────────┘
                      │ 推送JSON包（每5秒/60秒）
┌─────────────────────▼───────────────────────────────────┐
│                    APP层（Flutter）                      │
│                                                         │
│  BlePacket 差值解包 → 5秒内增量：                         │
│  ├── shivD > 2      → shivering  🥶（最高优先）          │
│  ├── strC≥2||strD>3 → stressed   😣                     │
│  ├── paceD > 3      → pacing     😰                     │
│  ├── playD > 3      → playing    🎾                     │
│  └── 其余           → calm       😌                     │
│                                                         │
│  焦虑分计算（每5秒，加权平均4包）：                       │
│  单包原始分：                                            │
│    strC×10(上限20) + paceD×3(上限30) +                  │
│    shivD×6(上限40) + strD×1(上限10)                     │
│  展示值：最近4包加权平均（权重0.5/0.3/0.15/0.05）         │
│  ⚠️ strC权重已降低（阈值未验证，误报代价高）               │
│                                                         │
│  PetHealthProvider 睡眠细分（calm基础上）：               │
│  ├── calm < 30分钟            → calm（平静休息）          │
│  ├── calm ≥ 30分钟 + roll_c   → sleepNormal  😴          │
│  └── calm ≥ 30分钟 + 2h无roll_c → sleepAbnormal ⚠️      │
│  （睡眠计时从服务器同步，APP重启不丢失）                  │
│                                                         │
│  状态确认机制：连续2包（10秒）相同状态才切换显示            │
└─────────────────────────────────────────────────────────┘
```

---

## 判断来源汇总表

| # | 状态 | 中文 | 判断来源 | 需要训练数据 | 关键信号 |
|---|------|------|---------|------------|---------|
| 1 | `shivering` | 发抖 | 服务器物理算法（algorithm.py） | ❌ 不需要 | G 0.8~1.2g + delta_G 0.03~0.2 + micro_count≥3 |
| 2 | `stressed` | 应激 | 服务器物理算法 | ❌ 不需要 | G 1.2~2.2g + delta_G>0.3（⚠️ 与步行G值有重叠，靠组合条件区分） |
| 3 | `pacing` | 踱步 | AI模型+物理双验证 | ✅ 需要 | AI概率>55% AND rms>0.15 |
| 4 | `playing` | 玩耍 | 服务器AI模型 | ✅ 需要 | 高RMS不规律运动 |
| 5 | `calm` | 平静 | 服务器AI模型 | ✅ 需要 | 低RMS（<0.146g）接近静止 |
| 6 | `sleepNormal` | 正常睡眠 | APP层推断 | ❌ 不需要 | calm ≥ 30分钟 + roll_c有值 |
| 7 | `sleepAbnormal` | 异常昏睡 | APP层推断 | ❌ 不需要 | calm ≥ 30分钟 + 2h无roll_c |

**结论：AI模型只需训练3类（calm / pacing / playing），其余4种状态由物理算法或APP逻辑推断。**

---

## 数据清洗目标（Kaggle DogMoveData.csv）- v2版本

| 训练类别 | Kaggle原始标签 | 可用数据量 | 备注 |
|---------|-------------|----------|------|
| `calm` | Lying on chest + Sitting + Standing | ~330分钟 | 信号一致，可靠 |
| `pacing` | Pacing（仅此一项） | ~13分钟（771秒） | 纯净踱步，丢弃Walking/Trotting |
| `playing` | Playing + Galloping + Trotting + Walking | 充足 | 高活动量统一归入 |

**丢弃原因说明：**
- `Walking`（步行）：信号特征介于pacing和playing之间，归入任何一类都会污染边界
- `Trotting`（小跑）：高频率运动，信号更接近playing，归入pacing会造成混淆

**清洗参数：**
- 采样率：100Hz（无降采样，直接使用原始数据）
- 窗口：300行（3秒@100Hz），步进300（无重叠）
- 传感器列：ANeck_x / ANeck_y / ANeck_z（颈部加速度）
- 数据均衡：每类200个窗口（总600个文件）
- 文件命名：`calm.0001.csv`、`pacing.0001.csv`、`playing.0001.csv`（点号分隔，Edge Impulse识别标签）

---

## 版本历史

| 版本 | 日期 | 主要变更 |
|------|------|---------|
| v1.0 | 2025年7月 | 初始版本，服务器40Hz推理，4类模型（含shivering） |
| v2.0 | 2025年7月 | 升级100Hz推理；3类模型（去除shivering）；pacing双重验证（RMS>0.15）；焦虑分算法说明；数据清洗目标更新（丢弃Walking/Trotting） |
| v2.1 | 2025年7月 | 修复焦虑分架构图旧值；修复应激频繁冷却时间内部矛盾；修复E2触发条件（删除不存在的str_c判断）；新增kSleepEntryThreshold参数；新增服务器睡眠计时同步B方案说明；新增加权平均焦虑分A方案；新增kMinPlaySeconds参数；新增kDebugMode机制说明；更新固件版本至V7.2 |

---

*文档更新时间：2025年7月*
*对应代码版本：ESP32固件 V7.2 / 服务器算法 v2.0（inference.py / algorithm.py / server.py）/ APP Flutter build 12*

---

## 参数分类管理：测试数据 vs 暂定数据

系统中存在两类性质不同的"测试参数"，必须明确区分：

### 切换机制：kDebugMode

**所有测试/生产参数通过 `kDebugMode` 常量统一切换**，不需要逐个修改：

```dart
// 位置：lib/providers/pet_health_provider.dart 顶部
// true  = 调试模式（测试值，所有阈值压缩以便快速验证）
// false = 生产模式（真实临床标准，上线前必须确认为 false）
static const bool kDebugMode = true;   // ⚠️ 上线前改为 false
```

**上线前操作清单：**
1. 将 `kDebugMode` 改为 `false`
2. 重新 build → 所有阈值自动切换为生产值
3. 无需逐个修改参数

### 第一类：纯测试参数（上线前必须改回生产值）

为方便开发期快速验证效果，人为调低阈值，**生产环境绝不能用**。

| 参数 | 测试值（kDebugMode=true） | 生产值（kDebugMode=false） | 说明 |
|------|--------------------------|--------------------------|------|
| `kShiverThreshold` | 30秒 | 180秒（3分钟） | 发抖预警阈值 |
| `kStressFreqThreshold` | 3次 | 10次 | 1小时内应激频次阈值 |
| `kStressFreqCooldownMinutes` | 15分钟 | 60分钟 | 应激频繁预警冷却时间 |
| `kPacingLongThreshold` | 120秒 | 1800秒（30分钟） | 连续踱步预警阈值 |
| `kLethargyThreshold` | 60秒 | 10800秒（3小时） | 白天昏睡预警阈值 |
| `kMinPlaySeconds` | 120秒 | 1800秒（30分钟） | 今日累计玩耍不足告警阈值 |
| `kNightStressThreshold` | 2次 | 5次 | 夜间应激预警阈值 |
| `kSleepEntryThreshold` | 120秒 | 1800秒（30分钟） | calm持续多久算入睡 |
| `kSleepAbnormalThreshold` | 600秒（10分钟） | 7200秒（2小时） | 入睡后多久无翻身算异常昏睡 |

**代码注释规范：** `// 测试值：X | 生产值：Y`

### 第二类：暂定参数（测试=生产，上线不用改，但待实证数据验证）

目前测试和生产使用同一个值，是当前最合理的工程估算，尚无充分实证，未来迭代时应基于真实数据重新验证。

| 参数 | 当前值 | 设定依据 | 未来验证方向 |
|------|--------|---------|------------|
| `strC × 10`（焦虑分权重） | 10分/次 | 降低权重：应激阈值与步行G值有重叠，误报代价高 | 阈值经真实数据验证后可考虑恢复至×20 |
| `paceD × 3`（踱步权重） | 3分/秒 | 工程估算：中等强度，且AI有误判风险 | 同上 |
| `shivD × 6`（发抖权重） | 6分/秒 | 物理阈值有文献支撑，保持权重 | 同上 |
| `strD × 1`（应激时长权重） | 1分/秒 | 同 strC，降低误报影响 | 同上 |
| RMS验证阈值 `rms > 0.15` | 0.15g | 数据支撑：calm最大值0.146，pacing最小值0.139 | 增加真实样本后重新验证边界 |
| pacing置信度阈值 55% | 0.55 | Edge Impulse默认值 + 实测可用 | 收集边界样本后微调 |
| `kStateConfirmPackets = 2` | 2包（10秒） | 工程经验：避免单包噪声 | 根据硬件真实噪声水平可调1~3 |
| 焦虑分加权权重 | [0.5, 0.3, 0.15, 0.05] | 工程经验：近包权重高，平滑噪声 | 可根据用户反馈调整平滑强度 |

**代码注释规范：** `// 暂定值，待实证数据后调整`

---

## 算法设计参考文献与阈值依据

---

### 一、发抖检测（Shivering）— 物理阈值算法

**v2.0架构说明**：v2.0 AI模型已去除 shivering 训练类（仅保留 calm/pacing/playing 三类）。发抖检测改为 `algorithm.py` 中的**物理阈值算法**直接判断，无需AI模型参与。

**物理阈值（algorithm.py）：**
- G值：0.8~1.2g（接近静止，身体几乎不运动）
- delta_G：0.03~0.2g（相邻采样点小幅高频波动）
- micro_tremor_count ≥ 3（一个推理窗口内满足条件的点数）

物理阈值的科学依据：

| 文献 | 来源 | 年份 | 依据内容 |
|------|------|------|---------|
| Haubenberger & Hallett, *Essential Tremor* | N Engl J Med 378:1802 | 2018 | 确立生理性颤抖频率范围 **4~16 Hz**，寒冷/恐惧诱发的颤抖属此范围；振幅小（相对于身体运动 <0.3g） |
| Bhatia et al., *Consensus Statement on Classification of Tremors* | Mov. Disord. 33:75 | 2018 | 国际运动障碍学会共识：姿势性/动作性颤抖频率 4~12 Hz；生理性颤抖在正常个体中频率 8~12 Hz |
| Flores-Pita et al., *Analysis of dog movement using a single accelerometer* | Front. Vet. Sci. (PMC12076518) | 2025 | 犬颈部传感器实测：静止/坐立时 G≈1g；发抖表现为 G 值接近 1g（0.8~1.2g）的高频小幅波动 |
| Ramkumar et al. / van der Linden et al., *Accelerometric Classification of Resting and Postural Tremor Amplitude* | Sensors 23:8621 | 2023 | 确认加速度计可靠量化颤抖幅度；频率滤波范围 3~12 Hz 覆盖颤抖信号主区间；FFT谱能量是最佳特征之一 |
| *Generalized Tremors in Dogs: 198 Cases (2003–2023)* | PMC11951301 | 2025 | 大样本（n=198）犬类全身颤抖研究；不同病因（中毒/低钙/恐惧）的颤抖均表现为持续连续震颤，幅度与病因相关 |

**物理阈值与文献的对应关系：**
- 0.8~1.2g（接近静止）：对应文献中"发抖时动物几乎不运动，G值接近静止值1g"（Flores-Pita 2025）
- delta_G 0.03~0.2g：对应颤抖频率 4~16 Hz 在100Hz采样下的相邻点幅度变化范围（Haubenberger 2018）
- micro_count ≥ 3：要求多个连续点满足条件，避免单点噪声误触发（Generalized Tremors in Dogs 2025）

---

### 二、应激检测（Stressed）— 物理阈值算法

**阈值：G值1.2~2.2g，delta_G>0.3，macro_count≥2，max_G<4.0**

| 文献 | 来源 | 年份 | 依据内容 |
|------|------|------|---------|
| Flores-Pita et al., *Analysis of dog movement using a single accelerometer* | Front. Vet. Sci. (PMC12076518) | 2025 | 实测犬颈部加速度：**步行峰值约 1.7~2.6g，步行谐波频率 1.62~1.95 Hz**。应激突发冲击特征：G值在1.2~2.2g区间 + 相邻采样点非节律性大幅跳变（delta_G>0.3），区别于步行的平滑周期性变化 |
| *Generalized Tremors in Dogs: 198 Cases (2003–2023)* | PMC11951301 | 2025 | 区分短促爆发性强烈震动（应激/中毒等）与持续细微颤抖（发抖）的G值幅度范围差异；应激爆发G值明显高于发抖幅度 |
| Bolton et al., *Use of a Collar-Mounted Triaxial Accelerometer to Predict Speed and Gait in Dogs* | Animals 11:1262 (PMC8146851) | 2021 | 犬颈圈加速度delta-G随运动强度增加；步行与慢跑/奔跑的delta-G有明确分界，支持使用delta_G区分运动类型 |

**⚠️ 已知局限与注意事项：**
> 犬只正常步行峰值G（1.7~2.6g）与应激阈值下界（1.2g）存在重叠。现行方案靠 **delta_G>0.3（非节律跳变）+ macro_count≥2 + max_G<4.0** 组合条件来区分应激突发与正常步行节律。此阈值属于工程估算，尚无独立犬类应激行为的实测G值文献直接验证，**待真实传感器数据收集后重新标定**。

---

### 三、踱步检测（Pacing）— RMS双重验证

**RMS阈值（rms > 0.15）来源：CalmPaws实测Kaggle DogMoveData 600窗口统计分析**

| 类别 | RMS均值 | RMS标准差 | RMS最小值 | RMS最大值 | 关键结论 |
|------|--------|---------|---------|---------|---------|
| calm | 0.031g | 0.030g | 0.003g | **0.146g** | 静止状态RMS上限为0.146g |
| pacing | 0.635g | 0.195g | **0.139g** | 1.096g | 踱步状态RMS下限为0.139g |
| playing | 0.931g | 0.431g | 0.256g | 4.432g | 玩耍RMS明显更高 |

**结论：** calm上限（0.146g）与pacing下限（0.139g）之间存在约0.007g的重叠区间，取 **0.15g** 为验证阈值，位于两者边界中间，可有效过滤AI将静止误判为踱步的情况。

踱步步态频率的文献交叉验证：

| 文献 | 来源 | 年份 | 依据内容 |
|------|------|------|---------|
| Flores-Pita et al., *Analysis of dog movement using a single accelerometer* | Front. Vet. Sci. (PMC12076518) | 2025 | 实测：犬颈部步行步幅频率 **1.62~1.95 Hz**（步/秒），与本文档定义的踱步频率特征 0.5~2 Hz 一致；小型犬步频高于大型犬 |
| Chambers et al., *Deep Learning Classification of Canine Behavior Using a Single Collar-Mounted Accelerometer* | PLOS ONE (PMC8228965) | 2021 | 2500+只犬的大规模深度学习行为分类研究（步行/坐/趴/进食/玩耍）；验证加速度计用于犬行为分类的可行性，为本系统 AI 分类提供技术参考 |
