# CalmPaws APP 差距清单（对照《全景对接文档 v2》）

> **更新日期**：2026-06-03（P0 收尾 + P1 完成后）  
> **对照文档**：`docs/CalmPaws_全景对接文档_给Cursor_v2.md`  
> **代码仓库**：`calmpaws-petoteco`（main 分支）  
> **预览**：https://largevillachongyang-a11y.github.io/calmpaws-petoteco/  
> **说明**：本清单只评估 **APP 侧**；硬件/服务器以对接文档 §三、§六 为「已就绪」前提。

---

## 一、总体完成度（2026-06-03 更新）

| 维度 | 完成度 | 说明 |
|------|--------|------|
| **§0 三件立刻要做的事** | **3 / 3** | 喂食卡移除、历史图重写、服务器焦虑分 — 均已完成 |
| **§5.1 立刻做清单** | **约 13 / 14 项** | 仅剩 P2（头像 VPS、FCM）及服务器联调验证 |
| **四条工程铁律** | **4 / 4** | 时区、EnvironmentConfig、204 防御、状态染色均已落地 |
| **§5.4 明确不变项** | **7 / 7** | 全部对齐 |

**结论**：APP 已从「ZenBelly 喂食 + 本地算分 + 模拟曲线」切换到 **「VPS 实时 status + history 三档图表 + 服务器 anxiety_score/label」** 架构。剩余工作主要为 **服务器数据就绪后的联调验证** 与 **P2 可选能力**。

---

## 二、§0 TL;DR — 三件主任务

| # | 文档要求 | 当前状态 |
|---|----------|----------|
| 1 | 移除 `FeedingTimerCard` + `TimeToCalmCard` | ✅ **P1 已删除**，Dashboard 不再挂载 |
| 2 | 重写 `StressChartCard`：24h / 7d / 30d + `/api/history` | ✅ **P0-4 完成**，三档 Tab + 染色 + 监测时长 footer |
| 3 | 删除 APP 端焦虑分 getter，改用服务器 `anxiety_score` | ✅ **P0-2 完成**；P0 收尾已删 `_recentDeltas` |

---

## 三、§5.1 修改清单逐项对照

### 3.1 应移除

| 项 | 状态 | 备注 |
|----|------|------|
| `FeedingTimerCard` | ✅ 已移除 | 文件可保留未引用，或后续清理 |
| `TimeToCalmCard` | ✅ 已移除 | 同上 |
| APP 端焦虑分 getter | ✅ 已移除 | UI 读 `serverAnxietyScore` |
| `_recentDeltas` 滑动窗口 | ✅ **P0 收尾已删** | 无其他引用 |
| Firestore `daily_stress` 写入 | ✅ P1 已停写 | `firestore_service` 方法仍存在但未调用 |
| Firestore `feeding_sessions` 写入 | ✅ P1 已停写 | 同上 |

### 3.2 应新增

| 项 | 状态 | 代码位置 |
|----|------|----------|
| `environment_config.dart` | ✅ | `lib/config/environment_config.dart` |
| `ServerApiService.fetchHistory` | ✅ | `lib/services/server_api_service.dart` |
| `HistoryPoint` / `HistorySummary` / `HistoryResponse` | ✅ | `lib/models/history_models.dart` |
| `StateColors` / `state_colors.dart` | ✅ | `lib/theme/state_colors.dart` |
| 重写 `StressChartCard` | ✅ | `lib/widgets/dashboard/stress_chart_card.dart` |

### 3.3 应修改

| 项 | 状态 | 备注 |
|----|------|------|
| 实时数据用 `anxiety_score` | ✅ | `_parsePacket` 解析 + Provider 暴露 |
| 行为状态读服务器 `label` | ✅ **P0 收尾** | `BlePacket.serverLabel` + `StateColors.behaviorFromLabel` |
| 「今日监测时长」从 history summary | ✅ | 图表 footer 读 `online_minutes` / `days_with_data` |
| 网络层 204 防御 + UI | ✅ **P0 收尾** | status 204 → 设备栏「等待项圈上报数据」 |
| 全 API 带 `?key=` | ✅ P0-1 | `EnvironmentConfig.apiUri` |

---

## 四、四条工程铁律对照

| 铁律 | 状态 |
|------|------|
| 🕐 **时区** | ✅ 24h `time` → `.toLocal()`；7d/30d 用 `date` 字符串 |
| ⚙️ **配置剥离** | ✅ `EnvironmentConfig` 集中 baseUrl / key / deviceId |
| 🛡️ **204 防御** | ✅ 不 `jsonDecode` 空 body；UI 显式提示 |
| 🎨 **状态染色** | ✅ `dominant_state` → `StateColors` + 图例 7 项 |

---

## 五、§5.4「不变项」

| 项 | 状态 |
|----|------|
| Firebase Auth | ✅ |
| Firestore `pet_profile` | ✅ |
| 头像 Web Base64（本期保留） | ✅ 刻意不动，等 VPS API |
| `/api/status` 轮询 2s | ✅ |
| `/api/app_online` | ✅ |
| `/api/set_species` | ✅ |
| `/api/alerts` | ✅ `fetchAlerts()` 已实现（Dashboard 未深度集成） |

---

## 六、API 对接细节

| 接口 | APP 状态 | 服务器待确认 |
|------|----------|--------------|
| `GET /api/status/<id>?key=` | ✅ 轮询、解析 anxiety_score/label/sleep_*；204 UI | 项圈未上报时 204；label 枚举与文档一致 |
| `GET /api/history/<id>?range=&key=` | ✅ 三档拉取 + 缓存 + 刷新 | points / summary 字段是否按 v2 填充 |
| `GET /api/health` | ✅ | — |
| 鉴权 key | ✅ APP 已带 | 服务器验证逻辑待下版 |

---

## 七、Dashboard 当前结构（目标已达成）

```
Header（宠物头像）
DeviceStatusBar（含 SYNC；204 时琥珀色等待提示）
BehaviorStateCard（服务器 label + anxiety_score）
StressChartCard（24h/7d/30d + 染色 + 监测时长）
StatusCardsRow
JournalQuickEntry
```

**已移除**：`FeedingTimerCard`、`TimeToCalmCard`

---

## 八、验收检查表

- [x] Dashboard 无 `FeedingTimerCard`、无 `TimeToCalmCard`
- [x] 无 APP 端 `currentAnxietyScore` / `BlePacket.anxietyScore` getter
- [x] 实时 UI 显示 `/api/status` 的 `anxiety_score`
- [x] 行为卡状态来自服务器 `label`（真实模式）
- [x] `StressChartCard` 可切换 24h / 7d / 30d
- [x] 图表数据来自 `/api/history`
- [x] 24h 本地时区；7d/30d 用 `date`
- [x] 折线/柱按 `dominant_state` 染色 + 图例
- [x] 底部显示 `summary.online_minutes` 或等价字段
- [x] 所有 API 从 `EnvironmentConfig` 且带 `key`
- [x] `/api/status` 204 不崩溃、显示「暂无数据/等待上报」
- [x] 不再写入 Firestore `daily_stress`、`feeding_sessions`
- [ ] **联调**：服务器有真实项圈数据后端到端目测（需硬件/服务器配合）

---

## 九、各阶段 commit 记录（供追溯）

| 阶段 | 内容 |
|------|------|
| P0-1 | `EnvironmentConfig`、全 API 带 `?key=` |
| P0-2 | 解析 `anxiety_score`；删 APP 端焦虑分 getter |
| P0-3 | `fetchHistory` + history 模型 + Provider 缓存 |
| P0-4 | 重写 `StressChartCard` 三档图表 |
| P1 | 移除 ZenBelly 喂食流程；停写 feeding/daily_stress |
| P0 收尾 | label 驱动行为卡、204 UI、删 `_recentDeltas` |

验收文档：`docs/P0-1_验收说明.md` … `docs/P0-4_验收说明.md`、`docs/P1_验收说明.md`、`docs/P0_收尾_验收说明.md`

---

## 十、文档存放位置

| 文件 | 路径 |
|------|------|
| 对接文档 v2 | `docs/CalmPaws_全景对接文档_给Cursor_v2.md` |
| 本差距清单 | `docs/APP_差距清单_对照全景对接v2.md` |

---

## 十一、决策确认（仍然有效）

1. **Web 头像 Base64**：本期保留，VPS 头像 API 就绪后再迁（P2）。
2. **API key**：APP 全量带 key；服务器验证待下版。
3. **Mock 模式**：保留 `MockBleService` + B 方案 2 包确认，供无服务器调试。
4. **真实模式**：行为/焦虑/睡眠以服务器字段为准，不做 APP 端重算。

---

## 十二、§十三 — 给服务器团队同步（2026-06-03）

### APP 已完成（可验收）

1. **配置与鉴权**：`baseUrl`、`deviceId`、`key` 集中配置；所有 HTTP 请求带 `?key=calmpaws_secret`（可改环境变量）。
2. **实时 `/api/status`**：2s 轮询；解析 `anxiety_score`、`label`、`battery`、`rssi`、`sleep_*`；同 timestamp 去重；**204 显示等待 UI**。
3. **历史 `/api/history`**：24h / 7d / 30d 三档；Provider 缓存；刷新按钮同时重拉三档。
4. **Dashboard 产品形态**：无喂食流程；行为卡 + 三档焦虑历史图 + 7 状态图例。
5. **部署**：push `main` → GitHub Actions → gh-pages 预览。

### APP 侧待完成（不阻塞服务器）

| 项 | 优先级 | 说明 |
|----|--------|------|
| 清理未引用代码 | 低 | `feeding_timer_card.dart`、`mock_ble` 中废弃方法、`firestore` 停写方法 |
| `/api/alerts` UI 集成 | 低 | 已有 `fetchAlerts()`，未在 Dashboard 展示 |
| i18n 行为卡「焦虑分」硬编码 | 低 | `_AnxietyRing` 底部文案未走 `AppStrings` |

### 依赖服务器 / 硬件（请服务器侧推进）

| 项 | APP 期望 | 当前风险 |
|----|----------|----------|
| **项圈上报** | `/api/status` 返回 200 + 完整 JSON | 长期 204 → APP 只显示「等待上报」 |
| **`label` 枚举** | `calm` / `pacing` / `stressed` / `playing` / `shivering` / `sleep_normal` / `sleep_abnormal` | 若字段缺失，行为卡回退 Mock 逻辑 |
| **`anxiety_score`** | 0–100 数值 | 缺失则显示 0 |
| **`/api/history` points** | 24h 桶 + 7d/30d 日汇总；含 `dominant_state` | 空数组 → 图表空态（已有引导文案） |
| **summary** | `online_minutes`（24h）、`days_with_data`（7d/30d） | 缺失则 footer 不显示监测时长 |
| **key 校验** | 非法 key 返回 401/403 | APP 目前按 200/204 处理，需约定错误码 |
| **头像 API** | P2，文档阶段 2 | APP 仍 Firestore Base64 |
| **FCM** | P2，文档阶段 3 | 未实现 |

### 建议联调顺序（服务器 ↔ APP）

1. `curl /api/health` → 200  
2. 项圈上报一条 → `curl /api/status/collar_001?key=...` → 200，字段含 `label`、`anxiety_score`  
3. APP 预览连接 → 行为卡与 Network 响应一致  
4. 确认 history 三档有数据 → APP 图表非空  
5. 项圈停报 → status 204 → APP 琥珀色等待条（不崩溃）

### 快速 curl（复制给服务器）

```bash
curl -s "https://api.myvideotest2026.top/api/health?key=calmpaws_secret"
curl -s "https://api.myvideotest2026.top/api/status/collar_001?key=calmpaws_secret" -w "\nHTTP:%{http_code}\n"
curl -s "https://api.myvideotest2026.top/api/history/collar_001?range=24h&key=calmpaws_secret" | head -c 800
curl -s "https://api.myvideotest2026.top/api/history/collar_001?range=7d&key=calmpaws_secret" | head -c 800
```

---

*本文件随 main 代码更新；联调问题请对照 `docs/P0_收尾_验收说明.md` 与 Network 面板截图反馈。*
