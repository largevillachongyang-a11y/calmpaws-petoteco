# CalmPaws APP 待办清单（最终对接阶段）

> **更新日期**：2026-06-03（联调稳定：登录+Dashboard OK；history 401 待服务器）  
> **总览文档**：`docs/最终对接_联调状态与后续工作.md`  
> **上一阶段**：v2 对接 14/14 已完成 → 见 `docs/APP_差距清单_对照全景对接v2.md`  
> **预览**：https://largevillachongyang-a11y.github.io/calmpaws-petoteco/  
> **联调环境**：`https://api.myvideotest2026.top` · 测试设备 `collar_001` · 绑定 key `calmpaws_secret`

---

## 阶段总览

| 阶段 | 范围 | 状态 |
|------|------|------|
| **v2（P0–P1 + 收尾）** | 历史图、焦虑分、label、204、alerts 横幅等 | ✅ **已完成** |
| **最终对接 P0** | Bearer 鉴权、设备绑定、启动流程 | ✅ **已完成** |
| **最终对接 P1** | FCM 注册 + 推送接收 | ⚠️ **代码完成**；Web 预览暂关闭，真机待测 |
| **可选 P2** | 二维码绑定、头像迁 VPS | ⏸️ 按需 |

**核心变化**：从「全局 `?key=` + 写死 `collar_001`」→「Firebase 登录 + 用户绑定设备 + Bearer Token」。

---

## §0 — 五件主任务（TL;DR）

| # | 任务 | 优先级 | 状态 |
|---|------|--------|------|
| 1 | 鉴权迁移：`?key=` → `Authorization: Bearer <firebase_id_token>` | P0 | [x] |
| 2 | 新增「我的设备」页：`GET /api/user/devices` | P0 | [x] |
| 3 | 新增「绑定设备」流程：`POST /api/user/bind_device` | P0 | [x] |
| 4 | 注册 FCM Token：`POST /api/user/register_fcm` | P1 | [x] 代码完成，Web 暂跳过 |
| 5 | 改造启动流程：登录 → 查设备 → Dashboard / 绑定页 | P0 | [x] |

---

## 5.1 鉴权层（P0 — 先做）

| # | 待办 | 状态 | 代码/备注 |
|---|------|------|-----------|
| 1 | 封装 `getIdToken()` + `_authHeaders()` | [x] | `lib/services/auth_api_helper.dart` |
| 2 | `GET /api/status/<id>` 改 Bearer，去掉 `?key=` | [x] | `server_api_service.dart` |
| 3 | `GET /api/history/<id>` 改 Bearer | [x] | 同上 |
| 4 | `GET /api/alerts/<id>` 改 Bearer | [x] | 同上 |
| 5 | `POST /api/app_online` 改 Bearer | [x] | 同上 |
| 6 | `POST /api/set_species` 改 Bearer | [x] | 同上 |
| 7 | `POST /api/reset/<id>` 改 Bearer | [x] | 同上 |
| 8 | **401**：`getIdToken(true)` 重试一次，仍失败 → 登出跳登录 | [x] | 全 API 统一 |
| 9 | **403**：提示「请先绑定此设备」 | [x] | status/history/alerts 等 |
| 10 | **404 / 409**：绑定页专用提示 | [x] | 见 §5.3 |
| 11 | 删除 `EnvironmentConfig.deviceKey` 及 `apiUri` 自动带 key | [x] | 绑定时用户输入 key |
| 12 | 全文搜索确认无残留 `?key=calmpaws_secret` | [x] | 联调验收项 |

**不需要改鉴权**：`GET /api/health`

---

## 5.2 设备管理页（P0）

| # | 待办 | 状态 |
|---|------|------|
| 1 | 新建 `device_management_screen.dart` | [x] |
| 2 | 调用 `GET /api/user/devices` 展示列表 | [x] |
| 3 | 列表项：device_id + 物种图标 + bound_at | [x] |
| 4 | 空列表引导 +「添加设备」按钮 | [x] |
| 5 | 每项「解绑」+ 确认弹窗 → `POST /api/user/unbind_device` | [x] |
| 6 | 从 Dashboard 或「我的」页可进入 | [x] |

---

## 5.3 绑定设备页（P0）

| # | 待办 | 状态 |
|---|------|------|
| 1 | 新建 `bind_device_screen.dart` | [x] |
| 2 | 输入框：device_id + device_key（包装盒 key） | [x] |
| 3 | `POST /api/user/bind_device` | [x] |
| 4 | **404** → 设备不存在 | [x] |
| 5 | **401** → device_key 错误 | [x] |
| 6 | **409** → 已被其他用户绑定 | [x] |
| 7 | 成功 → 设备列表或 Dashboard | [x] |
| 8 | （P2）扫码绑定 JSON `{"d":"...","k":"..."}` | [ ] 可选 |

---

## 5.4 启动流程（P0）

```
APP 启动
  → Firebase 登录？
    → 否 → 登录页（现有 AuthScreen）
    → 是 → GET /api/user/devices
      → 有设备 → MainNavScreen / Dashboard（用当前选中设备）
      → 无设备 → BindDeviceScreen
```

| # | 待办 | 状态 |
|---|------|------|
| 1 | 改造 `_AuthGate` 或中间层：登录后先拉设备列表 | [x] | `device_gate.dart` |
| 2 | 无设备时不自动 `connectDevice()` 写死 ID | [x] | `pet_health_provider.dart` |
| 3 | 有设备时注册 FCM（P1） | [x] | `fcm_service.dart` |

---

## 5.5 Dashboard 改造（P0）

| # | 待办 | 状态 |
|---|------|------|
| 1 | `device_id` 从当前绑定设备取，禁止硬编码 `collar_001` | [x] |
| 2 | 多设备时顶部设备切换器（下拉） | [x] |
| 3 | 切换设备后重连轮询 + 清 history 缓存 | [x] |
| 4 | v2 已有 UI（行为卡、历史图、204、alerts 横幅）**保持不变** | ✅ |

---

## 5.6 FCM 推送（P1）

| # | 待办 | 状态 |
|---|------|------|
| 1 | `pubspec.yaml` 添加 `firebase_messaging` | [x] |
| 2 | 启动 / 登录后 `registerFCMToken()` | [x] | `user_device_api_service.dart` |
| 3 | 监听 `onTokenRefresh` 重新注册 | [x] | `fcm_service.dart` |
| 4 | 前台 in-app 通知中心 | [x] | `main_nav_screen.dart` |
| 5 | 后台系统通知栏 | [x] | Android/iOS 本地通知；Web 靠 SW |
| 6 | Web 预览 FCM | ⏸️ | gh-pages 子路径限制，已临时关闭防闪退 |

---

## 5.7 EnvironmentConfig 改造（P0）

| 项 | v2（当前） | 目标 |
|----|-----------|------|
| `baseUrl` | ✅ 保留 | 保留 |
| `testDeviceId` / 写死 ID | 已删除 | ✅ |
| `deviceKey` | 已删除 | ✅（绑定时输入） |
| `apiUri` 自动带 key | 已删除 | ✅ Bearer |
| `fcmWebVapidKey` | — | 新增，Web 可选 |

---

## 新增工程铁律（在 v2 四条之上）

| # | 铁律 | 状态 |
|---|------|------|
| 5 | 每次 API 前 `getIdToken()`，401 时 `getIdToken(true)` | [x] |
| 6 | 所有 `device_id` 从当前设备对象取，禁止硬编码 | [x] |
| 7 | FCM token：每次启动 + 刷新时注册 | [x] |

v2 铁律 1–4（时区、EnvironmentConfig、204、StateColors）：✅ 已实现，迁移时**不要破坏**。

---

## 联调验证检查表

### 已通过 ✅

- [x] Google 登录稳定，不再闪退
- [x] 绑定 `collar_001` + 正确 device_key
- [x] Dashboard 轮询 `/api/status`（Bearer）
- [x] 代码中无 `?key=calmpaws_secret`

### 待服务器修复 ⏳

- [ ] `/api/history` 三档正常（Bearer）— **当前 401**
- [ ] `/api/alerts` 正常（Bearer）
- [ ] FCM 注册成功（真机 P1）
- [ ] 服务器推送 APP 能收到（真机 P1）
- [ ] 解绑后访问该设备 → 403
- [ ] 多设备切换正常

---

## 验收文档

| 文件 | 内容 |
|------|------|
| `docs/最终对接_P0_验收说明.md` | Bearer + 设备绑定 |
| `docs/最终对接_P1_验收说明.md` | FCM 注册与推送 |

---

## v2 已完成 — 本阶段勿改坏

- ✅ 移除 FeedingTimer / TimeToCalm
- ✅ StressChartCard 24h/7d/30d + `/api/history`
- ✅ 服务器 `anxiety_score` + `label`
- ✅ 204 等待 UI
- ✅ StateColors 七状态
- ✅ alerts 60s 轮询 + ServerAlertsBanner
- ✅ Firestore 喂食/日压力读写已清理

---

## APP 不需要做（服务器侧）

管理后台、OTA 固件、数据库运维、焦虑分算法、推送**发送**逻辑 — 均在服务器。

---

## 文档索引

| 文件 | 用途 |
|------|------|
| `docs/CalmPaws_最终对接文档_给Cursor.md` | 服务器给的完整规范（主文档） |
| **`docs/最终对接_联调状态与后续工作.md`** | **联调结论 + 后续分工（推荐阅读）** |
| `docs/APP_待办清单_最终对接.md` | **本文件** — 待办与进度 |
| `docs/APP_差距清单_对照全景对接v2.md` | v2 阶段完成记录（归档） |
| `docs/CalmPaws_全景对接文档_给Cursor_v2.md` | v2 历史参考 |

---

*进度更新：2026-06-03 联调 — P0 可用；history 401 待服务器；Web FCM 暂缓。*
