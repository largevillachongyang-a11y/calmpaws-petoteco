# CalmPaws APP 差距清单（对照《全景对接文档 v2》）

> **生成日期**：2026-06-03  
> **对照文档**：`docs/CalmPaws_全景对接文档_给Cursor_v2.md`（仓库内，可 `@` 引用）  
> **代码仓库**：`calmpaws-petoteco`（main 分支，约 commit `c8affaf` 及之后）  
> **说明**：本清单只评估 **APP 侧**；硬件/服务器以对接文档 §三、§六 为「已就绪」前提。

---

## 一、总体完成度（估算）

| 维度 | 文档要求完成度 | 说明 |
|------|----------------|------|
| **§0 三件立刻要做的事** | **0 / 3** | 均未按 v2 规范落地 |
| **§5.1 立刻做清单（移除+新增+修改）** | **约 1 / 14 项** | 仅部分 API 轮询、204 半成品 |
| **四条工程铁律** | **约 1 / 4** | 204 部分处理；其余三项未做 |
| **§5.4 明确不变项** | **约 6 / 7** | Firebase Auth、pet_profile、/api/status 轮询等基本保留 |
| **近期 Cursor 额外工作（文档外）** | — | i18n、头像 Web Base64、GitHub Pages CI 等（见 §七） |

**结论**：当前 APP 仍停留在 **「ZenBelly 喂食 + 本地/Firestore 模拟曲线 + APP 端算焦虑分」** 阶段，与 v2 要求的 **「VPS 历史 API + 服务器 anxiety_score + 三档染色图表」** 存在 **整段架构差距**，需按文档 §十 分步实施。

---

## 二、§0 TL;DR — 三件主任务

| # | 文档要求 | 当前状态 | 差距 |
|---|----------|----------|------|
| 1 | 移除 `FeedingTimerCard` + `TimeToCalmCard`（ZenBelly 喂食流程） | ❌ **仍在 Dashboard** | 产品已确定砍掉喂食流程，两卡片 **P1 一并删除** |
| 2 | 重写 `StressChartCard`：24h / 7d / 30d，`GET /api/history` | ❌ **仍是 14 天模拟折线**（`generateDailyStressChart()` + Firestore 写入路径仍在） | 需全新图表 + `fetchHistory` + 数据模型 |
| 3 | 删除 APP 端焦虑分 **getter**，改用服务器 `anxiety_score` | ❌ **仍在 APP 算** | P0-2：删 `BlePacket.anxietyScore` getter、`currentAnxietyScore` getter；**`_recentDeltas` 先保留**，全文搜引用确认无其他消费者后再定是否删 |

---

## 三、§5.1 修改清单逐项对照

### 3.1 应移除

| 项 | 状态 | 代码位置 / 备注 |
|----|------|-----------------|
| `FeedingTimerCard` | ❌ 未移除 | `lib/widgets/dashboard/feeding_timer_card.dart`，Dashboard 仍挂载 |
| APP 端焦虑分 getter | ❌ 未移除 | 删 getter 即可（见上）；`_recentDeltas` **暂不删**，先 grep 确认引用链 |
| Firestore `daily_stress` 写入 | ❌ 仍在写 | `pet_health_provider.dart` → `saveDailyStressPoint`；`firestore_service.dart` `_dailyStress` |
| Firestore `feeding_sessions` 写入 | ❌ 仍在写 | P1 随喂食流程删除一并停写；`TimeToCalmCard` **确认删除** |

### 3.2 应新增

| 项 | 状态 | 代码位置 / 备注 |
|----|------|-----------------|
| `lib/config/environment_config.dart` | ✅ **已建** | P0-1：`baseUrl` / `deviceKey` / `testDeviceId` 集中配置 |
| `ServerApiService.fetchHistory(range)` | ❌ **不存在** | 无 `/api/history` 任何调用 |
| `HistoryPoint` / `HistorySummary` / `HistoryResponse` | ❌ **不存在** | 文档 §5.2 模型未建 |
| 状态染色 `StateColors` / `state_colors.dart` | ❌ **不存在** | 无 `dominant_state` 字段使用 |
| 重写 `StressChartCard`（三档 Tab + 折线/柱 + 染色 + 监测时长） | ❌ **未做** | 见 `stress_chart_card.dart` 仍为 14 天 ZenBelly 对比 UI |

### 3.3 应修改

| 项 | 状态 | 代码位置 / 备注 |
|----|------|-----------------|
| 实时数据用 `/api/status` 的 `anxiety_score` | ❌ 未对接 | `_parsePacket` 未解析 `anxiety_score`；仍对差分包本地计算 |
| 「今日监测时长」从 `history 24h summary.online_minutes` 读 | ❌ 未做 | 无 history 接口；无该 UI 字段 |
| 网络层 204 短路 | ⚠️ **部分** | `server_api_service.dart` 对 204 不 `jsonDecode`（✓），但未返回统一空对象；其他 API 路径未统一防御 |

---

## 四、四条工程铁律对照

| 铁律 | 要求 | 当前状态 | 差距 |
|------|------|----------|------|
| 🕐 **时区** | 24h `time` UTC → `.toLocal()`；7d/30d 用 `date` 字符串 | ❌ 无 history 数据流 | 实施 `HistoryPoint.localDateTime` 后需在图表层落实 |
| ⚙️ **配置剥离** | 统一 `EnvironmentConfig` | ✅ P0-1 已完成 | 全 API 带 `key`；默认值仅存在于 `environment_config.dart` |
| 🛡️ **204 防御** | `/api/status` 204 不解析空 body | ⚠️ 基本满足 | 建议补 `StatusPacket?` / 空工厂，UI 显式「暂无数据」 |
| 🎨 **状态染色** | `dominant_state` → 颜色映射 | ❌ 全项目无 `dominant_state` | 需新建 `StateColors` 并接入新图表 |

---

## 五、§5.4「不变项」— 已对齐 / 偏差

| 项 | 文档要求 | 当前状态 |
|----|----------|----------|
| Firebase Auth | 保留 | ✅ 使用中 |
| Firestore `pet_profile` | 保留 | ✅ 使用中（含 Web Base64 头像 workaround，见 §七） |
| 头像 | 文档建议后续迁 VPS | ✅ **本期不动**；Web Base64 方案 **保留**，等 VPS 头像 API 再统一迁 |
| `/api/status` 轮询 | 保留（文档写 2s） | ✅ `_pollIntervalSeconds = 2` |
| `/api/app_online` | 保留 | ✅ `notifyAppOnline()` 已实现 |
| `/api/set_species` | 保持 | ✅ `setSpecies()` 已实现 |
| `/api/alerts` | 保持 | ✅ `fetchAlerts()` 已实现 |

---

## 六、API 对接细节差距

| 接口 | 文档 | 当前 APP |
|------|------|----------|
| `GET /api/status/<id>?key=...` | 200 JSON / 204 无 body | ✅ 轮询有；❌ **URL 未附 `key` 参数**；❌ 未用 `anxiety_score` |
| `GET /api/history/<id>?range=24h\|7d\|30d&key=...` | 核心新增 | ❌ **完全未实现** |
| `GET /api/health` | 健康检查 | ✅ `healthCheck()` 有 |
| 鉴权 | 临时 `calmpaws_secret` | ✅ APP 已带 key（P0-1）；服务器验证待下版 |

---

## 七、文档外 — 近期 Cursor 已完成（供参考）

以下工作 **不在 v2 对接清单内**，但已存在于 main，实施 v2 时注意不要误删：

| 内容 | 状态 | 备注 |
|------|------|------|
| 我的/宠物页 i18n（编辑资料、取消按钮、Sync 按钮） | ✅ 已做 | |
| 宠物/用户头像 Web Base64 | ✅ 已做 | **产品确认：本期保留不动**，不纳入 P0～P1 |
| 用户资料头像上传 + 主页相机角标 | ✅ 已做 | |
| Dashboard / 宠物页头像 Provider 同步 | ✅ 已做 | |
| GitHub Pages 自动部署（push main → build web → gh-pages） | ✅ 已做 | `.github/workflows/deploy-pages.yml` |

---

## 八、Dashboard 现状 vs 目标结构

**当前 Dashboard 组件（`dashboard_screen.dart`）：**

```
Header（宠物头像）
DeviceStatusBar（含 SYNC）
FeedingTimerCard          ← 文档要求删除
BehaviorStateCard       ← 仍用 APP 端 anxietyScore
TimeToCalmCard            ← P1 删除（产品已确定）
StressChartCard           ← 需整卡重写
StatusCardsRow
JournalQuickEntry         ← 文档未要求删（Firestore journal 未列入废弃）
```

**v2 目标（文档隐含）：**

```
Header
DeviceStatusBar
BehaviorStateCard       ← 读服务器 anxiety_score + label
StressChartCard         ← 24h/7d/30d + /api/history + 染色
（监测时长 summary 在图表底部）
（移除 FeedingTimerCard；TimeToCalm 待产品确认）
```

---

## 九、建议实施顺序（给 Cursor / 开发者）

按文档 §十，建议 **严格顺序**（每步可单独 PR + 预览验证）：

| 阶段 | 任务 | 建议模型 | 预估工作量 |
|------|------|----------|------------|
| **P0-1** | 新建 `EnvironmentConfig`，迁移 baseUrl / deviceKey / deviceId；所有 API 带 `?key=` | Sonnet | 小 |
| **P0-2** | `_parsePacket` 增加 `anxiety_score`；Provider 删除 `currentAnxietyScore` 加权链；UI 改读服务器分 | Sonnet | 中 |
| **P0-3** | 实现 `fetchHistory` + 三模型 + 204/空数组防御 | Sonnet | 中 |
| **P0-4** | 重写 `StressChartCard`（三档 + 染色 + 监测时长 + 时区） | Sonnet | 大 |
| **P1** | 移除 `FeedingTimerCard` + `TimeToCalmCard`；停写 `feeding_sessions` / `daily_stress` | Sonnet | 中 |
| **P1** | 新建 `StateColors`；7 状态图例 | Auto | 小 |
| **P2** | 头像迁 VPS（文档阶段 2）；FCM 推送（阶段 3） | 后续 | — |

**实施纪律（已确认）**：

- 严格按 **P0-1 → P0-2 → P0-3 → P0-4 → P1** 顺序
- **每个阶段单独 PR**，不混做
- **本期不动头像**（Web Base64 保留）
- P0 阶段 **不删 `_recentDeltas`**，只删两个 anxiety getter（P0-2 前先 grep）

---

## 十、验收检查表（全部打勾 = v2 APP 对接完成）

- [ ] Dashboard 无 `FeedingTimerCard`、无 `TimeToCalmCard`
- [ ] 无 APP 端 `currentAnxietyScore` / `BlePacket.anxietyScore` getter（`_recentDeltas` 若仍服务差分逻辑可保留）
- [ ] 实时 UI 显示 `/api/status` 的 `anxiety_score`
- [ ] `StressChartCard` 可切换 24h / 7d / 30d
- [ ] 图表数据来自 `/api/history`，非 Firestore / mock
- [ ] 24h 横轴为本地时区；7d/30d 用 `date` 字符串
- [ ] 折线/柱按 `dominant_state` 染色 + 图例
- [ ] 底部显示 `summary.online_minutes` 或 `days_with_data` 等
- [ ] 所有 API URL 从 `EnvironmentConfig` 读取且带 `key`
- [ ] `/api/status` 返回 204 时 APP 不崩溃、显示「暂无数据」
- [ ] 不再写入 Firestore `daily_stress`、`feeding_sessions`（若产品确认砍喂食）

---

## 十一、文档存放位置

| 文件 | 路径 |
|------|------|
| 对接文档 v2 | `docs/CalmPaws_全景对接文档_给Cursor_v2.md` |
| 本差距清单 | `APP_差距清单_对照全景对接v2.md` |

---

## 十二、决策确认（2026-06-03，项目负责人补充）

1. **`_recentDeltas`**：不直接删；P0-2 前全文搜引用；仅删 `currentAnxietyScore` getter 与 `BlePacket.anxietyScore` getter。
2. **API key**：APP 按 v2 所有 URL 带 `key`；服务器老接口暂未必验证，下版服务器补强。
3. **`TimeToCalmCard`**：与 `FeedingTimerCard` 一并删除（ZenBelly 流程已砍）。
4. **Web 头像 Base64**：本期保留，不动；VPS 头像 API 就绪后再迁。
5. **v2 文档已进仓库 `docs/`**，与代码同 PR 版本管理。
6. **实施**：P0-1 ✅ 已完成（见 `docs/P0-1_验收说明.md`）；P0-2 起待逐步开工。

---

*本文件由 Cursor 对照代码静态分析生成，未运行 curl 实测 API。联调时请以对接文档 §七 curl 命令验证服务器返回为准。*
