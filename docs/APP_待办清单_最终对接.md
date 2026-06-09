# CalmPaws APP 待办清单（最终对接阶段）

> **更新日期**：2026-06-08  
> **依据文档**：`docs/CalmPaws_最终对接文档_给Cursor.md`（服务器 V5.1 回应，**替代 v2 作为下一阶段主文档**）  
> **上一阶段**：v2 对接 14/14 已完成 → 见 `docs/APP_差距清单_对照全景对接v2.md`  
> **预览**：https://largevillachongyang-a11y.github.io/calmpaws-petoteco/  
> **联调环境**：`https://api.myvideotest2026.top` · 测试设备 `collar_001` · 绑定 key `calmpaws_secret`

---

## 阶段总览

| 阶段 | 范围 | 状态 |
|------|------|------|
| **v2（P0–P1 + 收尾）** | 历史图、焦虑分、label、204、alerts 横幅等 | ✅ **已完成** |
| **最终对接（本文档）** | Bearer 鉴权、设备绑定、启动流程、FCM | ❌ **未开始** |
| **可选 P2** | 二维码绑定、头像迁 VPS | ⏸️ 按需 |

**核心变化**：从「全局 `?key=` + 写死 `collar_001`」→「Firebase 登录 + 用户绑定设备 + Bearer Token」。

---

## §0 — 五件主任务（TL;DR）

| # | 任务 | 优先级 | 状态 |
|---|------|--------|------|
| 1 | 鉴权迁移：`?key=` → `Authorization: Bearer <firebase_id_token>` | P0 | [x] |
| 2 | 新增「我的设备」页：`GET /api/user/devices` | P0 | [x] |
| 3 | 新增「绑定设备」流程：`POST /api/user/bind_device` | P0 | [x] |
| 4 | 注册 FCM Token：`POST /api/user/register_fcm` | P1 | [ ] |
| 5 | 改造启动流程：登录 → 查设备 → Dashboard / 绑定页 | P0 | [x] |

---

## 5.1 鉴权层（P0 — 先做）

| # | 待办 | 状态 | 代码/备注 |
|---|------|------|-----------|
| 1 | 封装 `getIdToken()` + `_authHeaders()` | [ ] | 建议放 `lib/services/auth_api_helper.dart` 或扩展现有 auth 服务 |
| 2 | `GET /api/status/<id>` 改 Bearer，去掉 `?key=` | [ ] | `server_api_service.dart` |
| 3 | `GET /api/history/<id>` 改 Bearer | [ ] | 同上 |
| 4 | `GET /api/alerts/<id>` 改 Bearer | [ ] | 同上 |
| 5 | `POST /api/app_online` 改 Bearer | [ ] | 同上 |
| 6 | `POST /api/set_species` 改 Bearer | [ ] | 同上 |
| 7 | `POST /api/reset/<id>` 改 Bearer | [ ] | 同上 |
| 8 | **401**：`getIdToken(true)` 重试一次，仍失败 → 登出跳登录 | [ ] | 全 API 统一 |
| 9 | **403**：提示「请先绑定此设备」 | [ ] | status/history/alerts 等 |
| 10 | **404 / 409**：绑定页专用提示 | [ ] | 见 §5.3 |
| 11 | 删除 `EnvironmentConfig.deviceKey` 及 `apiUri` 自动带 key | [ ] | 绑定时用户输入 key，不写死配置 |
| 12 | 全文搜索确认无残留 `?key=calmpaws_secret` | [ ] | 联调验收项 |

**过渡期**：服务器仍支持旧 `?key=`，可单 API 验证后再批量改。

**不需要改鉴权**：`GET /api/health`

---

## 5.2 设备管理页（P0）

| # | 待办 | 状态 |
|---|------|------|
| 1 | 新建 `device_management_screen.dart` | [ ] |
| 2 | 调用 `GET /api/user/devices` 展示列表 | [ ] |
| 3 | 列表项：device_id + 物种图标 + bound_at | [ ] |
| 4 | 空列表引导 +「添加设备」按钮 | [ ] |
| 5 | 每项「解绑」+ 确认弹窗 → `POST /api/user/unbind_device` | [ ] |
| 6 | 从 Dashboard 或「我的」页可进入 | [ ] |

---

## 5.3 绑定设备页（P0）

| # | 待办 | 状态 |
|---|------|------|
| 1 | 新建 `bind_device_screen.dart` | [ ] |
| 2 | 输入框：device_id + device_key（包装盒 key） | [ ] |
| 3 | `POST /api/user/bind_device` | [ ] |
| 4 | **404** → 设备不存在 | [ ] |
| 5 | **401** → device_key 错误 | [ ] |
| 6 | **409** → 已被其他用户绑定 | [ ] |
| 7 | 成功 → 设备列表或 Dashboard | [ ] |
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
| 1 | 改造 `_AuthGate` 或中间层：登录后先拉设备列表 | [ ] | `main.dart` |
| 2 | 无设备时不自动 `connectDevice()` 写死 ID | [ ] | `pet_health_provider.dart` |
| 3 | 有设备时注册 FCM（P1 可后补） | [ ] | |

---

## 5.5 Dashboard 改造（P0）

| # | 待办 | 状态 |
|---|------|------|
| 1 | `device_id` 从当前绑定设备取，禁止硬编码 `collar_001` | [ ] |
| 2 | 多设备时顶部设备切换器（下拉） | [ ] |
| 3 | 切换设备后重连轮询 + 清 history 缓存 | [ ] |
| 4 | v2 已有 UI（行为卡、历史图、204、alerts 横幅）**保持不变** | ✅ |

---

## 5.6 FCM 推送（P1）

| # | 待办 | 状态 |
|---|------|------|
| 1 | `pubspec.yaml` 添加 `firebase_messaging` | [ ] |
| 2 | 启动 / 登录后 `registerFCMToken()` | [ ] |
| 3 | 监听 `onTokenRefresh` 重新注册 | [ ] |
| 4 | 前台 in-app 横幅 | [ ] |
| 5 | 后台系统通知栏 | [ ] |
| 6 | Web 预览是否支持 FCM 需评估（可能仅 Android/iOS） | [ ] |

---

## 5.7 EnvironmentConfig 改造（P0）

| 项 | v2（当前） | 目标 |
|----|-----------|------|
| `baseUrl` | ✅ 保留 | 保留 |
| `testDeviceId` / 写死 ID | `collar_001` | **删除或仅 dev fallback** |
| `deviceKey` | `calmpaws_secret` | **删除**（绑定时输入） |
| `apiUri` 自动带 key | ✅ 有 | **改为 Bearer，不带 key** |

---

## 新增工程铁律（在 v2 四条之上）

| # | 铁律 | 状态 |
|---|------|------|
| 5 | 每次 API 前 `getIdToken()`，401 时 `getIdToken(true)` | [ ] |
| 6 | 所有 `device_id` 从当前设备对象取，禁止硬编码 | [ ] |
| 7 | FCM token：每次启动 + 刷新时注册 | [ ] |

v2 铁律 1–4（时区、EnvironmentConfig、204、StateColors）：✅ 已实现，迁移时**不要破坏**。

---

## 建议执行顺序（与服务器文档 §七 一致）

```
① 封装 getIdToken + _authHeaders
② 只改 /api/status，Bearer 联调通过
③ 批量改 history / alerts / app_online / set_species / reset
④ GET /api/user/devices → 设备列表页
⑤ POST bind_device → 绑定页
⑥ 启动流程：登录 → 查设备 → Dashboard 或绑定
⑦ Dashboard 动态 device_id + 多设备切换
⑧ 解绑 unbind_device
⑨ FCM 注册 + 接收推送
⑩ 全文验收（§联调检查表）
```

---

## 联调验证检查表

- [ ] 登录后 `GET /api/user/devices` → 200
- [ ] 绑定 `collar_001` + 正确 device_key → 200
- [ ] 绑定后 Dashboard 轮询 `/api/status`（Bearer）
- [ ] `/api/history` 三档正常（Bearer）
- [ ] `/api/alerts` 正常（Bearer）
- [ ] 错误 device_key → 401
- [ ] 抢绑已绑设备 → 409
- [ ] 解绑后访问该设备 → 403
- [ ] Token 过期自动刷新
- [ ] 代码中无 `?key=calmpaws_secret`
- [ ] FCM 注册成功（P1）
- [ ] 服务器推送 APP 能收到（P1）
- [ ] 多设备切换正常

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
| `docs/APP_待办清单_最终对接.md` | **本文件** — 待办与进度 |
| `docs/APP_差距清单_对照全景对接v2.md` | v2 阶段完成记录（归档） |
| `docs/CalmPaws_全景对接文档_给Cursor_v2.md` | v2 历史参考 |

---

*进度更新：每完成一步在此文件打勾，并随 commit 提交。*
