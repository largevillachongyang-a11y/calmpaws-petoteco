# CalmPaws 项目全景对接文档 v2 —— 给新 AI 工具(Cursor)

> **本文档目的**:
> 项目早期 APP 由另一个 AI 协助开发,该工具已停用。换 Cursor 继续开发 APP。
> 本文档把服务器、固件、APP 三方的进度、决策、对接接口完整说清楚,让 Cursor 能无缝接手。
>
> **日期**:2026-06-02 · **版本**:v2
> **整理人**:服务器/固件侧 AI 协助方
> **受众**:Cursor + APP 开发者
>
> **v2 更新**:加强时区/海外用户处理、配置剥离、网络层防御、状态颜色映射四个工程细节(详见第 5、11 节)

---

## 0. TL;DR(给 Cursor 的执行清单)

接手 APP 后立刻做的 3 件事:

1. **移除「平静响应计时器」卡片**(`FeedingTimerCard`),不再围绕 ZenBelly 益生菌做喂食流程
2. **重写「应激减少趋势」卡片**(`StressChartCard`),改成 24h / 7d / 30d 三档切换,数据从我们的 VPS 拉(`GET /api/history`),不再从 Firestore 读 `daily_stress`
3. **移除 APP 端焦虑分计算逻辑**(`pet_health_provider.dart` 里 `currentAnxietyScore`、`_recentDeltas` 加权均值等),改用服务器返回的 `anxiety_score` 字段

**四个必须遵守的工程铁律**(第 11 节有详细说明):
- 🕐 **时区**:24h 时间戳是 UTC,必须 `.toLocal()`;7d/30d 日期字符串是服务器 UTC 自然日,海外用户要警惕日期边界
- ⚙️ **配置剥离**:`baseUrl` / `deviceKey` 必须独立在 `lib/config/EnvironmentConfig` 类里,不能散落在代码中
- 🛡️ **204 状态码**:`/api/status` 可能返回 204,网络层要短路成空对象,不能让空 body 进 JSON 解析器
- 🎨 **状态染色**:充分利用 `dominant_state` 字段,给曲线/柱状染色(行为-颜色映射表)

---

## 一、项目概览

**CalmPaws**:宠物焦虑监测项圈。
- 硬件:ESP32-C3 + IMU(LSM6DSOX),戴在宠物脖子上
- 行为识别:7 大状态(calm / playing / pacing / stressed / shivering / sleepNormal / sleepAbnormal)
- 数据流:项圈 → WiFi+HTTP → VPS(Flask + AI 推理 + MariaDB)→ APP
- **目标市场:海外(注意:全文涉及时区的地方都按海外场景设计)**

**架构(已落地):**

```
项圈 ESP32(每5秒上传)
    ↓ HTTP POST /api/upload
VPS Flask 服务器(api.myvideotest2026.top,测试期临时域名)
    ├ AI 推理(TFLite 模型)
    ├ 物理算法(踱步/颤抖/玩耍/应激检测)
    ├ 焦虑分计算(0-100)
    └ MariaDB 持久化
         ├ records         (推理记录,保留30天)
         ├ heartbeats      (心跳,保留30天)
         └ daily_summary   (每日汇总,永久保留)
    ↓ HTTP GET /api/history
APP(Flutter)
    ├ Firebase Auth(账号登录,保留)
    ├ 实时数据展示(GET /api/status)
    └ 历史曲线(GET /api/history)  ← 本次主要新增
```

---

## 二、关键架构决策(都已定好)

| 决策项 | 结果 | 理由 |
|---|---|---|
| 项圈数据怎么传 | **只走 WiFi+HTTP**,不再依赖 BLE | BLE 后台会被 iOS/Android 系统挂起,不可靠 |
| 数据持久化在哪 | **服务器端(VPS+MariaDB)** | APP 端持久化是残缺方案,关 APP 就丢数据 |
| 焦虑分谁算 | **服务器算** | 数据已在服务器,APP 直接用 |
| 用户系统在哪 | **保留 Firebase Auth** | Firebase Auth 免费且成熟,自建无意义 |
| 业务数据在哪 | **挪到我们 VPS** | Firestore 收费 + 跟设备数据分散不便 |
| Firestore 哪些保留 | **只保留 pet_profile** | feeding_sessions、journal_entries、daily_stress 全部废弃 |
| 头像存哪 | **建议挪到 VPS,后续做** | VPS 还有 86GB 空间 |
| 推送通知 | **未来用 Firebase Cloud Messaging** | Firebase 强项,服务器调它的 API 即可 |
| 多设备方案 | **每设备独立 device_key** | 不再共用 `calmpaws_secret` |
| **时区处理** | **API 全部用 UTC,APP 转本地时区** | 海外用户场景下,服务器/数据库/APP 解耦最干净 |

---

## 三、服务器侧已完成的工作

### 3.1 数据库结构(MariaDB 11.8.7)

**已建好三张表:**

```sql
-- 表1:推理记录(每次推理一条,5-10秒一条)
records (
    id, device_id, ts, species, label, confidence,
    str_c, str_d, shiv_c, shiv_d, pace_d, play_d, roll_c,
    anxiety_score,    -- 服务器算好的焦虑分 0-100
    battery, charging, is_offline,
    created_at,
    INDEX idx_device_ts (device_id, ts)
)

-- 表2:心跳(每5秒一条,用于"监测时长"统计)
heartbeats (
    id, device_id, ts,
    battery, charging, boot_cnt, flash_pct,
    INDEX idx_device_ts (device_id, ts)
)

-- 表3:每日汇总(每天1条,永久保留)
daily_summary (
    id, device_id, date,
    avg_anxiety, peak_anxiety, min_anxiety,
    calm_count, playing_count, pacing_count, stressed_count,
    shivering_count, sleep_normal_count, sleep_abnormal_count,
    dominant_state,
    record_count, heartbeat_count, online_seconds,
    avg_battery, min_battery,
    UNIQUE KEY (device_id, date)
)
```

### 3.2 服务器版本

**当前版本:V3.9**(部署在 `https://api.myvideotest2026.top`)

主要功能:
- 接收 ESP32 心跳和上传(已有)
- AI 推理 + 物理算法(已有)
- 焦虑分计算(V3.8 新增)
- 写 MariaDB 持久化(V3.8 新增)
- 历史曲线 API(V3.9 新增,**本次 APP 对接重点**)

### 3.3 自动化任务

- **每天 00:30 UTC 自动聚合昨天数据**到 daily_summary(systemd timer 已部署)
- **每月 1 号 02:00 UTC 自动归档**超过 30 天的 records 到 CSV.gz(systemd timer 已部署)

> ⚠️ **海外用户重要提醒**:聚合任务按服务器 UTC 时间运行。
> 海外用户当地时间凌晨打开 APP 时,可能因为"当地凌晨 ≠ UTC 凌晨"看到昨天数据
> 还没汇总进 7d/30d 曲线。详见第 11 节工程铁律。

### 3.4 焦虑分公式(服务器端实现,沿用 APP 原公式)

```
anxiety_score = strC × 10 + paceD × 3 + shivD × 6 + strD × 1
截断到 0-100
```

---

## 四、API 接口规范(APP 对接重点)

### 4.1 实时数据(已有,APP 已在使用)

```
GET https://api.myvideotest2026.top/api/status/<device_id>?key=calmpaws_secret
```

**两种可能的响应**:

#### 成功(200):
```json
{
    "device_id": "collar_001",
    "species": "dog",
    "label": "calm",
    "confidence": 0.98,
    "anxiety_score": 0,          ← V3.8 新增,APP 直接用
    "str_c": 0, "str_d": 0,
    "shiv_c": 0, "shiv_d": 0,
    "pace_d": 0, "play_d": 5,
    "roll_c": 0,
    "battery": 100,
    "charging": false,
    "timestamp": 1780368699,     ← UTC unix 秒
    "_offline": false
}
```

#### 暂无数据(204 No Content):
**响应体可能为空白**(取决于客户端 HTTP 库的行为)。

> ⚠️ **铁律 3 - 防御 204**:Flutter 的 Dio / http 库收到 204 时,response.data 通常是 `null` 或空字符串。
> **务必在网络拦截器/Service 层判断状态码**,遇到 204 直接短路返回 `null` 或空对象,
> **不要把空 body 喂给 JSON 解析器**,否则会引发空指针红屏。详见第 11 节。

### 4.2 历史曲线 API(V3.9 新增,本次对接核心)

```
GET https://api.myvideotest2026.top/api/history/<device_id>
```

**参数:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `range` | string | 是(或用 from/to) | `24h` / `7d` / `30d` |
| `key` | string | 是 | 设备 key(目前 `calmpaws_secret`,后续会变) |
| `from` | int(unix秒,UTC) | 否 | 自定义起点(配 `to` 用,覆盖 `range`) |
| `to` | int(unix秒,UTC) | 否 | 自定义终点 |

> ⚠️ **本接口永远返回 200**,即使没数据也返回 `points: []` 空数组。
> 但 Flutter 仍要做防御性解析(空数组合法、null 字段处理)。

**返回 - 24h(从 records 表 5 分钟聚合):**

```json
{
  "device_id": "collar_001",
  "from": 1780303490,                    ← UTC unix 秒,APP 转本地时区显示
  "to": 1780390068,                      ← 同上
  "interval_seconds": 300,
  "points": [
    {
      "time": 1780368300,                ← UTC unix 秒,必须 .toLocal() 转本地时区!
      "anxiety_score": 0.0,              // 该桶平均焦虑分,画曲线用这个
      "dominant_state": "calm",          // 主导状态,用于染色
      "states": {
        "calm": 61, "playing": 1, "pacing": 0, "stressed": 0,
        "shivering": 0, "sleep_normal": 0, "sleep_abnormal": 0
      },
      "battery_avg": 100.0,
      "record_count": 62                 // 该桶推理总次数
    },
    { ... 下一个 5 分钟桶 ... }
  ],
  "summary": {
    "avg_anxiety": 0.0,
    "peak_anxiety": 0,
    "dominant_state": "calm",
    "heartbeat_count": 3315,
    "online_minutes": 276,               // 监测时长(分钟)
    "online_seconds": 16575,
    "total_records": 1966
  }
}
```

**返回 - 7d / 30d(从 daily_summary 表读):**

```json
{
  "device_id": "collar_001",
  "days": 7,
  "points": [
    {
      "date": "2026-06-02",              ← ⚠️ 字符串,服务器 UTC 自然日
                                         //   海外用户看到时要谨慎,见第 11 节
      "anxiety_score": 0.0,
      "peak_anxiety": 0,
      "min_anxiety": 0,
      "dominant_state": "calm",          // 主导状态,柱状图染色用
      "states": { ... },
      "record_count": 1966,
      "online_minutes": 276,
      "battery_avg": 69, "battery_min": 44
    },
    { ... 下一天 ... }
  ],
  "summary": {
    "avg_anxiety": 0.0,
    "peak_anxiety": 0,
    "dominant_state": "calm",
    "online_hours_total": 4.6,
    "online_minutes_total": 276,
    "days_with_data": 1,
    "days_total": 7
  }
}
```

**字段说明:**

| 字段 | 24h 有 | 7d/30d 有 | 说明 |
|------|---|---|------|
| `time` | ✅(unix秒,UTC) | — | 该桶起点时间戳,**必须转本地时区显示** |
| `date` | — | ✅(YYYY-MM-DD,UTC) | 日期,**海外用户场景注意边界** |
| `anxiety_score` | ✅ | ✅ | **平均焦虑分,画主曲线/柱用这个** |
| `peak_anxiety` | — | ✅ | 当天峰值 |
| `min_anxiety` | — | ✅ | 当天最低 |
| `dominant_state` | ✅ | ✅ | **主导状态(7选1),染色用** |
| `states` | ✅ | ✅ | 7 种状态各自计数 |
| `record_count` | ✅ | ✅ | 推理总数 |
| `online_minutes` | — | ✅ | 该天监测分钟数 |
| `battery_avg` | ✅ | ✅ | 平均电量 |

### 4.3 其他已有接口(APP 已在使用,保持现状)

```
POST /api/app_online                    # 通知服务器 APP 在前台(切换实时模式)
GET  /api/alerts/<device_id>            # 拉低电量等告警
POST /api/set_species                   # 切换狗/猫物种
GET  /api/health                        # 服务器健康检查
```

### 4.4 错误处理

| 状态码 | 含义 | 实际接口 | APP 应对 |
|--------|------|---------|----------|
| 200 | 正常 | `/api/history`、`/api/status`(有数据时) | 画图/显示 |
| 204 | 暂无数据 | **仅 `/api/status` 会返回**(没缓存数据时) | **网络层短路,不要解析空 body** |
| 401 | key 无效 | 所有 API | 检查 key 配置 |
| 503 | 数据库暂不可用 | 所有 API | 提示稍后重试 |
| 500 | 服务器错误 | 所有 API | 显示错误,可重试 |

### 4.5 鉴权(本期临时方案,后续会改)

- 当前所有请求带 `?key=calmpaws_secret`(或 HTTP 头 `X-Device-Key`)
- 多设备改造后会换成:每设备独立 key + Firebase ID Token 验证
- **Cursor 必须把 baseUrl 和 deviceKey 剥离到独立 EnvironmentConfig 类**,详见第 11 节铁律 2

---

## 五、APP 端要做的修改清单

### 5.1 立刻做(本次主任务)

**移除:**
- [ ] `FeedingTimerCard`(平静响应计时器卡片,跟 ZenBelly 喂食流程绑定的那个)
- [ ] `pet_health_provider.dart` 里 APP 端的焦虑分计算:`currentAnxietyScore`、`_recentDeltas` 加权均值、`_computeAnxiety` 等所有 APP 侧计算逻辑
- [ ] 写入 Firestore 的 `daily_stress` 子集合(废弃)
- [ ] 写入 Firestore 的 `feeding_sessions`(看产品方向,如果完全砍掉喂食流程就废弃)

**新增:**
- [ ] **`lib/config/environment_config.dart`**(配置类,放 baseUrl / deviceKey,**铁律 2**)
- [ ] `ServerApiService.fetchHistory(range)` 方法,调 `/api/history`
- [ ] 数据模型:`HistoryPoint`、`HistorySummary`、`HistoryResponse`(见 5.2)
- [ ] **状态染色映射表**:`Map<String, Color>` 把 7 种状态映射到颜色(铁律 4)
- [ ] 重写 `StressChartCard`:
  - 三档切换 tab:24小时 / 7天 / 30天
  - 24h 用折线图,5 分钟一个点,无数据时段断开不连线
  - 7d/30d 用柱状图,每天 1 根柱,无数据天显示灰色空柱
  - 底部展示「监测时长 X 小时 / X 天有数据」(从 `summary` 字段读)
  - **柱子/曲线段按 `dominant_state` 染色,这是核心视觉**

**修改:**
- [ ] `pet_health_provider.dart` 实时数据展示:直接用 `/api/status` 返回的 `anxiety_score`,删掉 APP 端再算的逻辑
- [ ] 「今日累计监测时长」改从 `/api/history?range=24h` 的 `summary.online_minutes` 读
- [ ] 网络层(`ServerApiService`)加上 **204 响应短路**逻辑

### 5.2 推荐数据模型

```dart
class HistoryPoint {
  final int? time;              // unix秒 UTC (24h 有,7d/30d 没有)
  final String? date;           // YYYY-MM-DD UTC (7d/30d 有)
  final double anxietyScore;
  final String dominantState;
  final Map<String, int> states;
  final int recordCount;
  final double batteryAvg;
  final int? onlineMinutes;     // 仅 7d/30d 有
  final int? peakAnxiety;       // 仅 7d/30d 有
  final int? minAnxiety;        // 仅 7d/30d 有

  /// 24h 用:把 UTC 时间戳转 APP 本地时区
  DateTime? get localDateTime =>
    time == null ? null : DateTime.fromMillisecondsSinceEpoch(time! * 1000, isUtc: true).toLocal();

  /// 7d/30d 用:直接解析 date 字符串
  DateTime? get dateAsDateTime =>
    date == null ? null : DateTime.parse(date!);
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
}

class HistoryResponse {
  final String deviceId;
  final List<HistoryPoint> points;
  final HistorySummary summary;
  final int? from;
  final int? to;
  final int? days;
  final int? intervalSeconds;

  /// 空响应工厂,网络层 204 时返回此对象,防止崩溃
  factory HistoryResponse.empty(String deviceId) => HistoryResponse(
    deviceId: deviceId,
    points: [],
    summary: HistorySummary(
      avgAnxiety: 0, peakAnxiety: 0, dominantState: 'calm',
    ),
  );
}
```

### 5.3 画曲线建议

**24 小时(折线图):**
- 横轴:0:00~23:59(基于 `point.localDateTime` 也就是 .toLocal() 后的本地时间)
- 纵轴:焦虑分 0-100
- 数据:`points[i].anxietyScore`
- 无数据时段:断开折线(诚实展示)
- **每段曲线按 `dominant_state` 染色**(铁律 4 颜色映射)
- 底部:`今日已监测 ${summary.onlineMinutes ~/ 60} 小时`

**7 天 / 30 天(柱状图):**
- 横轴:近 7 天 / 近 30 天日期
- 纵轴:焦虑分 0-100
- 数据:`points[i].anxietyScore`(每天 1 柱)
- 无数据的天:APP 自己补空柱(`points` 数组里不会出现这天)
- **柱子按 `dominant_state` 染色**
- 底部:`本周/本月监测 ${summary.daysWithData}/${summary.daysTotal} 天 · 累计 ${summary.onlineHoursTotal} 小时`

### 5.4 不变的地方

- 保留 Firebase Auth(账号登录)
- 保留 Firestore 的 `pet_profile`(宠物档案)
- 保留 Firebase Storage(头像)
- 保留 `/api/status` 实时轮询(每 2 秒)
- 保留 `/api/app_online` 通知 APP 上线

---

## 六、固件侧情况(供 Cursor 了解,不需要 APP 配合)

**两套硬件并行:**

### 6.1 旧开发板(已稳定运行)

- 主控:ESP32-C3 + ISM330DHCX + CH343 外置串口
- 固件:**R7 版本**(`calmpaws_v9.0_final_r7.ino`)
- 已稳定运行 22+ 小时,推理 2000+ 次零失败
- 当前 collar_001 设备就是这块板

### 6.2 新硬件 V9.1(自研 PCB,开发中)

- 主控:ESP32-C3 + LSM6DSOX + 内置 USB-CDC(无外置串口芯片)
- 硬件按键:SW1(用户键 GPIO1)、SW2(BOOT GPIO9)、SW3(复位 EN)
- LED:GPIO10
- 电池采样:GPIO2(1M/1M 分压)
- Flash:W25Q16(2MB,或可能实际焊 W25Q128=16MB,待固件读取确认)
- **当前问题**:烧录流程未稳定,最小测试固件未成功烧入,暂停推进
- 正式固件功能需要在最小固件验证通过后开始写,会包含:
  - R2~R7 全部修复
  - 省电优化(WiFi 退避重连、modem-sleep、上传策略方案C)
  - 多 LED 状态机
  - 按键多功能(单击/双击/长按)

### 6.3 BLE 配网协议(给 APP 备用)

固件支持 BLE 配网,APP 后续做配网页面时按此协议:

```
APP 通过 BLE 特征值写入:
  "WIFI:ssid:password"            # 基础配网
  "WIFI:ssid:password:server_url" # 同时改服务器地址(测试用)

项圈回复:
  "OK:WIFI"      # 配网成功
  "FAIL:WIFI"    # 配网失败
```

**APP 配网页面流程**(正式产品要做,本期可暂缓):
1. APP 扫描周边 WiFi 列表
2. 用户选择目标 WiFi
3. 用户输入密码
4. APP 通过 BLE 把「WiFi 名+密码」发送给项圈
5. 项圈连接,完成配网

---

## 七、当前测试环境

**测试设备**(目前唯一):
- `device_id`: `collar_001`
- `key`: `calmpaws_secret`(开发期临时方案)
- 状态:实时在用,产生真实数据
- 已有约 2000 条推理记录,3000+ 心跳,平均焦虑分 0(静止状态)

**测试命令(curl):**

```bash
# 24h 历史
curl -s 'https://api.myvideotest2026.top/api/history/collar_001?range=24h&key=calmpaws_secret' | jq

# 7d 历史
curl -s 'https://api.myvideotest2026.top/api/history/collar_001?range=7d&key=calmpaws_secret' | jq

# 30d 历史
curl -s 'https://api.myvideotest2026.top/api/history/collar_001?range=30d&key=calmpaws_secret' | jq

# 实时
curl -s 'https://api.myvideotest2026.top/api/status/collar_001?key=calmpaws_secret' | jq

# 健康检查
curl -s 'https://api.myvideotest2026.top/api/health'
```

---

## 八、未来工作(给 Cursor 知道全貌,不在本期做)

按优先级排:

### 阶段 1(下一步)
1. **多设备支持** —— 服务器加 devices 表,每设备独立 key。固件烧录时改 key
2. **Firebase Auth + 服务器集成** —— 服务器加 Firebase token 验证中间件,APP 调 API 时带 Firebase 给的 ID token
3. **APP 端「添加设备」流程** —— 用户扫码/输入 device_id 绑定到自己账号

### 阶段 2
4. **管理后台**(Web)
   - 总览:设备总数、在线状态、推理总量、扫描攻击拦截统计
   - 单设备:数据曲线、心跳历史、上传成功率
   - 管理员账号
5. **宠物档案/头像迁移**(从 Firestore/Storage 挪到 VPS,可选)

### 阶段 3
6. **推送通知**(Firebase Cloud Messaging)
   - 设备离线 N 分钟推送
   - 异常状态(持续应激、颤抖等)推送
7. **数据分析**
   - 用户的宠物焦虑趋势分析报告
   - 群体数据(匿名)用于产品迭代

### 阶段 4
8. **APP 配网页面** —— 等新硬件固件稳定后做
9. **数据库性能优化** —— 设备数过千时考虑分区表、读写分离等

---

## 九、参考文件

服务器和固件侧已经积累的文档/代码,需要时可参考:

| 文件 | 内容 |
|------|------|
| `server_v3.9.py` | 当前服务器主程序(VPS 上 /www/calmpaws/) |
| `aggregate_daily.py` | 每日聚合脚本(VPS 上 /www/calmpaws/) |
| `archive_records.py` | 月度归档脚本(VPS 上 /www/calmpaws/) |
| `APP_对接说明_v1.md` | 之前给 APP 开发的初版对接文档(本文档的子集) |
| `CalmPaws_待办清单_新硬件与APP_v3.md` | 项目总待办 |
| `固件烧录现状_v1.md` | 新硬件固件烧录的现状记录 |

---

## 十、给 Cursor 的开工指引

**第一步:理解全局**

读完本文档,确认理解了:
- APP 不再依赖 BLE 拿数据,改走 HTTP
- 焦虑分服务器算好,APP 直接用,不要再算
- 历史数据三档(24h/7d/30d)调用 `/api/history`
- Firebase 留作账号登录,业务数据走我们 VPS
- **第 11 节四个工程铁律必须遵守**

**第二步:开 Flutter 项目**

仓库:`https://github.com/largevillachongyang-a11y/calmpaws-petoteco`
技术栈:Flutter 3.35.4,Dart,Provider 状态管理,fl_chart 图表库

**第三步:照清单改**

按本文档第五节「APP 端要做的修改清单」逐项推进:
1. **先建 `lib/config/environment_config.dart`**(铁律 2,后续所有代码都依赖它)
2. 用 curl 跑通 API,看返回数据
3. 写数据模型 `HistoryPoint` / `HistorySummary` / `HistoryResponse`(注意 `localDateTime` getter)
4. 写 `fetchHistory` 方法(注意 204 防御)
5. 写状态颜色映射表
6. 重写 `StressChartCard`(三档切换 + 染色)
7. 移除旧逻辑(焦虑分计算、FeedingTimerCard、Firestore 写入)
8. 跑测试,跟服务器对接验证

**第四步:遇到问题**

服务器端的问题(API 返回不对、想加字段、有 bug)直接反馈给项目负责人,服务器侧可以快速迭代。

---

## 十一、四个工程铁律(v2 新增,必须严格遵守)

### 🕐 铁律 1:时区错位的隐形 Bug

**项圈面向海外市场,时区是不可忽视的工程细节。**

**24h 历史(unix 时间戳):**
- API 返回的 `time` 是 **UTC unix 秒**
- Flutter 画横轴(0:00~23:59)时,**必须先 `.toLocal()` 转本地时区**:
  ```dart
  final localTime = DateTime.fromMillisecondsSinceEpoch(
    point.time * 1000,
    isUtc: true,   // 关键:声明数据是 UTC
  ).toLocal();      // 关键:转到用户手机本地时区
  ```
- **如果忘了 `.toLocal()`,海外用户的曲线会整体偏移几小时**(例如美国用户的"今晚 8 点"会显示在"中午 12 点"附近)

**7d/30d 历史(日期字符串):**
- API 返回的 `date` 字段是 **服务器 UTC 自然日**(如 `"2026-06-02"` = UTC 6 月 2 日 00:00~24:00)
- 服务器**每天 00:30 UTC** 聚合昨天的数据
- **海外用户场景的边界问题:**
  - 美国西岸用户(UTC-8):当地时间凌晨 1 点 = UTC 9 点,他打开 APP 时,服务器**已经聚合**完昨天的数据
  - 美国东岸用户(UTC-5):当地时间凌晨 1 点 = UTC 6 点,服务器**还没开始聚合**(等到 UTC 00:30 = 当地 19:30 才聚合)
  - **结论:海外用户在当地上午打开 APP 时,如果发现"昨天没有数据",可能不是 bug,是聚合还没跑**

**APP 端对策:**
1. 24h 时间戳一律 `.toLocal()`
2. 7d/30d 横轴标签直接用 `point.date` 字符串(已是 UTC 自然日),不要再转
3. 在 UI 上标注「数据按 UTC 自然日划分」(可选,但推荐)
4. 如果"今天"那条数据缺失,显示"今日数据正在生成中"而不是直接显示空白

---

### ⚙️ 铁律 2:配置剥离与解耦设计

**当前测试期硬编码了临时域名和全局密钥**,正式产品上线前必然要换。**绝不允许这些值散落在各处。**

**强制要求:**

```dart
// lib/config/environment_config.dart
class EnvironmentConfig {
  /// 服务器 API 基础 URL
  /// 测试期临时域名,正式产品上线前必换
  static const String baseUrl = 'https://api.myvideotest2026.top';

  /// 设备 key(开发期临时全局 key,多设备改造后改为每设备独立 key)
  static const String deviceKey = 'calmpaws_secret';

  /// 当前测试设备 ID
  static const String testDeviceId = 'collar_001';

  /// API 请求超时
  static const Duration requestTimeout = Duration(seconds: 10);

  /// 是否启用调试模式
  static const bool debugMode = true;
}
```

**所有调用 API 的代码必须从这里读取,不允许任何 `'https://...'` 或 `'calmpaws_secret'` 出现在其他文件里。**

**好处:**
- 切换正式域名:改 1 行
- 多设备改造时把 deviceKey 从静态改成动态:改 1 处
- 切换开发/生产环境:加个 `static const env = 'dev'` 即可

**反例(禁止):**
```dart
// ❌ 不要这样
final url = 'https://api.myvideotest2026.top/api/history/collar_001?key=calmpaws_secret';
```

**正例:**
```dart
// ✅ 应该这样
final url = '${EnvironmentConfig.baseUrl}/api/history/$deviceId?key=${EnvironmentConfig.deviceKey}';
```

---

### 🛡️ 铁律 3:HTTP 204 状态码的防御性处理

**问题描述:**

`/api/status/<device_id>` 在服务器内存中暂无该设备最新数据时,会返回 **HTTP 204 No Content**。
204 的特征是 **响应体为空**(Dio / http 库返回 `response.data == null` 或空字符串)。

**如果直接把空 body 喂给 `jsonDecode()` 或反序列化器,会引发空指针红屏崩溃。**

**正确做法(Service 层短路):**

```dart
Future<StatusPacket?> fetchStatus(String deviceId) async {
  try {
    final response = await dio.get(
      '${EnvironmentConfig.baseUrl}/api/status/$deviceId',
      queryParameters: {'key': EnvironmentConfig.deviceKey},
    );

    // 🛡️ 关键:204 状态码短路
    if (response.statusCode == 204) {
      return null;  // 或返回一个标志"暂无数据"的空对象
    }

    // 200 才解析
    if (response.statusCode == 200 && response.data != null) {
      return StatusPacket.fromJson(response.data);
    }

    return null;
  } catch (e) {
    // 错误处理
    return null;
  }
}
```

**`/api/history` 的情况:**
- 永远不会返回 204(没数据时返回 200 + `points: []`)
- 但仍要做 null / 空数组防御,例如 `summary` 字段全为 0、`points` 是空数组
- 推荐用 `HistoryResponse.empty()` 工厂方法生成空对象

**通用原则:**
- 网络层永远要假设响应可能是空
- 解析前一定先检查 `statusCode` 和 `response.data != null`
- UI 层要能处理 null/空响应(显示"暂无数据"而不是崩溃)

---

### 🎨 铁律 4:状态染色给曲线注入灵魂

**充分利用 `dominant_state` 字段,给图表染色,而不是用单一颜色。**

**行为-颜色映射表(推荐方案):**

```dart
// lib/theme/state_colors.dart
class StateColors {
  /// 7种状态到颜色的映射
  static const Map<String, Color> stateColorMap = {
    'calm':            Color(0xFF4CAF50),  // 绿色:平静
    'sleep_normal':    Color(0xFF66BB6A),  // 浅绿:正常睡眠
    'playing':         Color(0xFF42A5F5),  // 蓝色:玩耍(开心活跃)
    'pacing':          Color(0xFFFFC107),  // 黄色:踱步(轻度焦虑)
    'stressed':        Color(0xFFFF9800),  // 橙色:应激
    'shivering':       Color(0xFFF44336),  // 红色:颤抖(严重应激)
    'sleep_abnormal':  Color(0xFFFF5722),  // 深橙:睡眠异常
  };

  static Color colorFor(String state) =>
    stateColorMap[state] ?? Colors.grey;

  /// 中文标签(展示用)
  static const Map<String, String> stateLabelCN = {
    'calm':            '平静',
    'sleep_normal':    '睡眠',
    'playing':         '玩耍',
    'pacing':          '踱步',
    'stressed':        '应激',
    'shivering':       '颤抖',
    'sleep_abnormal':  '睡眠异常',
  };
}
```

**应用场景:**

**24h 折线图:**
- 同一焦虑分数值,但状态不同时,曲线段颜色不同
- 例如:平均焦虑分都是 30,但一段是 pacing(黄)、一段是 stressed(橙),颜色立刻区分
- 用户一眼看到"绿色 → 橙色"的过渡,直观感受到情绪变化

**7d/30d 柱状图:**
- 每根柱子整体染色,绿色=平静的一天,红色=应激的一天
- 用户一眼看出"这周有 3 天偏红"
- 视觉冲击力强,胜过单看数值

**图例:**
- UI 底部显示颜色图例:🟢 平静 / 🔵 玩耍 / 🟡 踱步 / 🟠 应激 / 🔴 颤抖
- 用户立刻看懂颜色含义

**进阶玩法(可选):**
- 渐变色:同一柱子按 states 比例做渐变(例如 60% calm + 40% pacing → 绿黄渐变)
- 点击柱子展开:显示该天各状态时长详情

**反例(禁止):**
- 所有柱子单一颜色:浪费了 `dominant_state` 字段,信息密度不够,产品力被降级

---

**铁律小结:**

| 铁律 | 解决的问题 | 失败后果 |
|------|------------|----------|
| 1️⃣ 时区 | 海外用户曲线偏移 | 海外用户用不了 / 数据看似错乱 |
| 2️⃣ 配置剥离 | 后续重构成本爆炸 | 域名/key 换一次改几十处 |
| 3️⃣ 204 防御 | 客户端空指针崩溃 | APP 在某些时刻直接红屏 |
| 4️⃣ 状态染色 | 视觉力不够 | 产品看上去廉价 |

四条铁律都是低成本高收益的工程细节,**Cursor 必须严格遵守**。

---

**祝对接顺利。**

> 本文档版本:v2
> 服务器版本:V3.9
> 数据库:MariaDB 11.8.7
> 整理日期:2026-06-02
