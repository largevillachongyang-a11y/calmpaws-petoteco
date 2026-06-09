# CalmPaws 最终对接文档（给 Cursor）

> **本文档性质**：替代 v2 和 v3，一份完整的最终对接文档
> **日期**：2026-06-08
> **服务器版本**：V5.1 + E1-G（含管理后台、OTA、FCM）
> **服务器地址**：`http://api.myvideotest2026.top`（HTTP/HTTPS 均可）
> **APP 仓库**：`calmpaws-petoteco`（main 分支）
> **Cursor 之前的工作**：v2 文档的 14/14 项全部完成（P0-P1 + 收尾），做得很好

---

## 0. TL;DR — Cursor 要做的 5 件事

1. **鉴权迁移**：所有 API 调用从 `?key=calmpaws_secret` 改为 `Authorization: Bearer <firebase_id_token>`
2. **新增「我的设备」页面**：调用 `/api/user/devices` 展示绑定设备列表
3. **新增「绑定设备」流程**：用户输入 device_id + device_key → 绑定后才能看数据
4. **注册 FCM 推送 Token**：APP 登录后调用 `/api/user/register_fcm` 注册推送
5. **改造 APP 启动流程**：登录 → 查设备 → 有设备进 Dashboard / 无设备去绑定页

---

## 一、v2 之后服务器做了什么

### 1.1 Cursor 需要关心的（影响 APP 代码）

| 变更 | 说明 | APP 影响 |
|------|------|----------|
| Firebase Admin SDK 集成 | 服务器可验证 Firebase ID Token | APP 改用 Bearer 鉴权 |
| 双模式鉴权 | device_key（ESP32）+ Firebase Token（APP）并存 | APP 切换鉴权方式 |
| 设备绑定系统 | 用户绑定/解绑设备，一设备一用户 | 新增绑定 UI |
| 权限隔离 | Bearer 鉴权时校验用户是否绑定了该设备 | 403 处理 |
| FCM 推送 | 服务器可发推送通知 | APP 注册 FCM token |

### 1.2 Cursor 不需要关心的（纯服务器/管理后台）

- 管理后台（E1-E6）：设备批量管理、用户管理、服务器监控、数据导出分析
- OTA 远程固件更新（G 阶段）：纯服务器+固件，不涉及 APP
- 数据库自动重连修复
- VPS 迁移

---

## 二、鉴权迁移指南（最重要）

### 2.1 旧方式（v2，即将废弃）

```
GET /api/status/collar_001?key=calmpaws_secret
```

### 2.2 新方式（APP 必须迁移到此）

```
GET /api/status/collar_001
Authorization: Bearer eyJhbGciOiJSUzI1NiIs...
```

### 2.3 Flutter 代码改造

**获取 Token：**

```dart
import 'package:firebase_auth/firebase_auth.dart';

Future<String?> getIdToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  return await user.getIdToken(); // 自动处理过期刷新
}
```

**改造 ServerApiService：**

```dart
// ── 改造前（v2）──
Future<Map<String, dynamic>> fetchStatus(String deviceId) async {
  final url = '${EnvironmentConfig.baseUrl}/api/status/$deviceId?key=${EnvironmentConfig.deviceKey}';
  final response = await http.get(Uri.parse(url));
  // ...
}

// ── 改造后 ──
Future<Map<String, dynamic>> fetchStatus(String deviceId) async {
  final token = await getIdToken();
  if (token == null) throw Exception('用户未登录');
  final url = '${EnvironmentConfig.baseUrl}/api/status/$deviceId';
  final response = await http.get(
    Uri.parse(url),
    headers: {'Authorization': 'Bearer $token'},
  );
  // ...
}
```

**建议封装统一鉴权 header 方法：**

```dart
Future<Map<String, String>> _authHeaders() async {
  final token = await getIdToken();
  if (token == null) throw Exception('用户未登录');
  return {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };
}
```

### 2.4 需要改的 API 清单

| API | 方法 | 改法 |
|-----|------|------|
| `/api/status/<device_id>` | GET | 去掉 `?key=`，加 Bearer header |
| `/api/history/<device_id>` | GET | 同上 |
| `/api/alerts/<device_id>` | GET | 同上 |
| `/api/app_online` | POST | 同上 |
| `/api/set_species` | POST | 同上 |
| `/api/reset/<device_id>` | POST | 同上 |

**不需要改的（无鉴权）：**

| API | 说明 |
|-----|------|
| `/api/health` | 健康检查 |

### 2.5 过渡期说明

服务器同时支持新旧两种方式。APP 可以分步迁移，不会中断。但最终目标是删掉所有 `?key=` 代码。

---

## 三、新增 API 规范

### 3.1 获取用户绑定的设备列表

```
GET /api/user/devices
Authorization: Bearer <token>
```

**200：**
```json
{
  "devices": [
    {
      "device_id": "collar_001",
      "species": "dog",
      "bound_at": "2026-06-05T10:30:00"
    }
  ]
}
```

**401：** token 无效

### 3.2 绑定设备

```
POST /api/user/bind_device
Authorization: Bearer <token>
Content-Type: application/json

{"device_id": "collar_001", "device_key": "calmpaws_secret"}
```

**200：** `{"message": "bound", "device_id": "collar_001"}`
**404：** 设备不存在
**401：** device_key 错误
**409：** 已被其他用户绑定

**安全设计说明：**
- 绑定需要 device_key（印在包装盒上），防止乱猜 ID 抢绑
- 一台设备只能被一个用户绑定
- 要转让设备，原用户必须先解绑

### 3.3 解绑设备

```
POST /api/user/unbind_device
Authorization: Bearer <token>
Content-Type: application/json

{"device_id": "collar_001"}
```

**200：** `{"message": "unbound", "device_id": "collar_001"}`
**403：** 不是你的设备

### 3.4 注册 FCM 推送 Token

```
POST /api/user/register_fcm
Authorization: Bearer <token>
Content-Type: application/json

{
  "fcm_token": "dKj8sF...(Firebase Cloud Messaging token)",
  "device_type": "android"
}
```

**200：** `{"message": "registered"}`

**调用时机：**
- APP 每次启动时
- FCM token 刷新时（`FirebaseMessaging.instance.onTokenRefresh`）
- 用户登录后

**Flutter 代码示例：**

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> registerFCMToken() async {
  final fcmToken = await FirebaseMessaging.instance.getToken();
  if (fcmToken == null) return;
  
  final headers = await _authHeaders();
  await http.post(
    Uri.parse('${EnvironmentConfig.baseUrl}/api/user/register_fcm'),
    headers: headers,
    body: jsonEncode({
      'fcm_token': fcmToken,
      'device_type': Platform.isIOS ? 'ios' : 'android',
    }),
  );
}

// 监听 token 刷新
FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
  registerFCMToken();
});
```

---

## 四、错误码总表

| HTTP 状态码 | 含义 | APP 处理 |
|-------------|------|----------|
| 200 | 正常 | 正常解析 |
| 204 | 暂无数据（仅 /api/status） | 不解析 body，显示「等待项圈上报」（v2 已实现） |
| 401 | token 无效/过期/缺失 | 刷新 token，再失败跳登录页 |
| 403 | token 有效但无权访问此设备 | 提示「请先绑定此设备」 |
| 404 | 设备不存在 | 提示「设备不存在」 |
| 409 | 绑定冲突 | 提示「设备已被其他用户绑定」 |
| 500 | 服务器内部错误 | 提示「服务器异常，请稍后重试」 |

**401 处理逻辑（重要）：**

```dart
if (response.statusCode == 401) {
  // 1. 尝试强制刷新 token
  final newToken = await user.getIdToken(true);
  // 2. 用新 token 重试一次
  final retry = await http.get(url, headers: {'Authorization': 'Bearer $newToken'});
  if (retry.statusCode == 401) {
    // 3. 还是 401 → 用户已登出或被禁用 → 跳登录页
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }
}
```

---

## 五、APP 改造清单

### 5.1 鉴权层（P0，先做）

- [ ] 封装 `getIdToken()` + `_authHeaders()` 统一方法
- [ ] 所有 API 调用改 Bearer header（§2.4 清单）
- [ ] 处理 401（自动刷新 + 跳登录页）
- [ ] 处理 403（提示绑定设备）
- [ ] 删除 `EnvironmentConfig` 中的 `deviceKey`（不再需要）

### 5.2 设备管理页面（P0）

- [ ] 新建 `device_management_screen.dart`
- [ ] 调用 `GET /api/user/devices` 展示列表
- [ ] 列表项：device_id + 物种图标 + 绑定时间
- [ ] 空列表引导 + 「添加设备」按钮
- [ ] 每个设备有「解绑」按钮（带确认弹窗）
- [ ] 从 Dashboard 或设置页可导航到此

### 5.3 绑定设备页面（P0）

- [ ] 新建 `bind_device_screen.dart`
- [ ] 两个输入框：device_id + device_key
- [ ] 错误处理：404/401/409 各显示不同提示
- [ ] 成功后跳设备列表或 Dashboard
- [ ] （P2 可选）扫码功能：二维码内容格式 `{"d":"collar_001","k":"cp_xxx"}`

### 5.4 APP 启动流程改造（P0）

```
APP 启动
  → 检查 Firebase 登录状态
    → 未登录 → 登录页
    → 已登录 → 调用 GET /api/user/devices
      → 有设备 → 进 Dashboard（用第一个设备）
      → 无设备 → 跳绑定页
```

### 5.5 Dashboard 改造（P0）

- [ ] device_id 不再硬编码 `collar_001`，从设备列表取
- [ ] 多设备时顶部加切换器（下拉选择）

### 5.6 FCM 推送接收（P1）

- [ ] `pubspec.yaml` 加 `firebase_messaging`
- [ ] APP 启动时调 `registerFCMToken()`
- [ ] 监听 token 刷新事件
- [ ] 前台推送：显示 in-app 横幅
- [ ] 后台推送：系统通知栏

### 5.7 EnvironmentConfig 改造

```dart
// ── 改造前（v2）──
class EnvironmentConfig {
  static const baseUrl = 'https://api.myvideotest2026.top';
  static const deviceId = 'collar_001';      // 写死
  static const deviceKey = 'calmpaws_secret'; // 写死
}

// ── 改造后 ──
class EnvironmentConfig {
  static const baseUrl = 'https://api.myvideotest2026.top';
  // deviceId → 动态获取，从 /api/user/devices 拿
  // deviceKey → 删除，仅绑定时用户手动输入
}
```

---

## 六、工程铁律（在 v2 四条基础上新增）

### v2 铁律（已实现，继续保持）

| # | 铁律 | 状态 |
|---|------|------|
| 1 | 时区：24h 用 `.toLocal()`，7d/30d 用 `date` 字符串 | ✅ 已实现 |
| 2 | 配置剥离：`EnvironmentConfig` 集中管理 | ✅ 已实现 |
| 3 | 204 防御：不 `jsonDecode` 空 body | ✅ 已实现 |
| 4 | 状态染色：`dominant_state` → `StateColors` | ✅ 已实现 |

### 新增铁律

| # | 铁律 | 说明 |
|---|------|------|
| 5 | **Token 生命周期** | 每次 API 调用前都调 `getIdToken()`（不缓存 token 字符串），收到 401 时 `getIdToken(true)` 强制刷新 |
| 6 | **device_id 动态化** | 所有用到 device_id 的地方从当前设备对象取，禁止出现硬编码 `collar_001` |
| 7 | **FCM token 及时注册** | 每次启动 + token 刷新时注册，不能只注册一次 |

---

## 七、执行顺序

```
第 1 步：封装 getIdToken() + _authHeaders()
         ↓
第 2 步：改一个 API（如 /api/status）验证 Bearer 鉴权可用
         ↓  验证通过
第 3 步：批量改其余 API
         ↓
第 4 步：实现 GET /api/user/devices → 设备列表页
         ↓
第 5 步：实现 POST /api/user/bind_device → 绑定页
         ↓
第 6 步：改造启动流程（登录 → 查设备 → Dashboard/绑定）
         ↓
第 7 步：Dashboard 动态 device_id + 多设备切换
         ↓
第 8 步：实现解绑功能
         ↓
第 9 步：FCM 注册 + 推送接收
         ↓
完成 → 联调
```

---

## 八、测试命令

APP 开发过程中可用这些命令验证服务器：

```bash
# 健康检查
curl -s https://api.myvideotest2026.top/api/health

# 旧方式鉴权（过渡期仍可用）
curl -s "https://api.myvideotest2026.top/api/status/collar_001?key=calmpaws_secret"

# 获取 Firebase token（在 Flutter 里打印后复制出来）
# final token = await FirebaseAuth.instance.currentUser?.getIdToken();
# print('TOKEN: $token');

# 用 token 测试（替换 <TOKEN>）
curl -s -H "Authorization: Bearer <TOKEN>" https://api.myvideotest2026.top/api/user/devices

# 绑定设备
curl -s -X POST https://api.myvideotest2026.top/api/user/bind_device \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"device_id":"collar_001","device_key":"calmpaws_secret"}'

# 绑定后查状态
curl -s -H "Authorization: Bearer <TOKEN>" https://api.myvideotest2026.top/api/status/collar_001

# 注册 FCM token
curl -s -X POST https://api.myvideotest2026.top/api/user/register_fcm \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"fcm_token":"test_fcm_token_123","device_type":"android"}'
```

---

## 九、联调验证检查表

- [ ] APP 登录后调 `/api/user/devices` 返回 200
- [ ] 绑定 collar_001 成功（需 device_key）
- [ ] 绑定后 Dashboard 正常轮询 `/api/status`（Bearer 鉴权）
- [ ] 历史曲线 `/api/history` 正常（Bearer 鉴权）
- [ ] 告警 `/api/alerts` 正常（Bearer 鉴权）
- [ ] 错误的 device_key → 401
- [ ] 抢绑已绑设备 → 409
- [ ] 解绑后访问该设备 → 403
- [ ] token 过期后自动刷新
- [ ] 全文搜索无 `?key=calmpaws_secret`
- [ ] FCM token 注册成功
- [ ] 服务器发推送后 APP 收到通知
- [ ] 多设备切换正常

---

## 十、多设备场景

```
用户 A（Firebase uid_aaa）
  ├── collar_001（A 的狗）
  └── collar_002（A 的猫）

用户 B（Firebase uid_bbb）
  └── collar_003（B 的狗）
```

- 用户 A 只能看 collar_001 和 002 的数据（403 拦截 003）
- 一台设备只能被一个用户绑定
- 单设备用户：直接进 Dashboard
- 多设备用户：顶部下拉切换

---

## 十一、v2 已完成项（保持不变）

以下 v2 工作已由 Cursor 完成，不需要改动：

- ✅ `FeedingTimerCard` / `TimeToCalmCard` 已移除
- ✅ `StressChartCard` 三档图表（24h/7d/30d）来自 `/api/history`
- ✅ 焦虑分来自服务器 `anxiety_score`
- ✅ 行为状态来自服务器 `label`
- ✅ 204 防御 + 等待 UI
- ✅ `StateColors` 七状态染色
- ✅ 60s 告警轮询 + 横幅
- ✅ Firestore 喂食/日压力读写已清理

---

## 十二、二维码绑定格式

包装盒上的二维码内容（JSON 字符串）：

```json
{"d":"collar_001","k":"cp_a3f8k2m9p4q7x1y6bv"}
```

APP 扫码后解析 `d` 为 device_id，`k` 为 device_key，自动调用绑定 API。

---

## 十三、APP 侧不需要做的事

| 事项 | 原因 |
|------|------|
| 管理后台 | 纯 Web 端，已独立部署 |
| OTA 固件更新 | 纯服务器+ESP32 固件 |
| 数据库管理 | 服务器自动处理 |
| 焦虑分算法 | 在服务器端运行 |
| 推送发送逻辑 | 服务器端触发 |

---

## 十四、联调环境信息

| 项目 | 值 |
|------|-----|
| 服务器地址 | `api.myvideotest2026.top` |
| HTTP | ✅ 可用（ESP32 用） |
| HTTPS | ✅ 可用（APP 用） |
| 测试设备 | `collar_001`，key: `calmpaws_secret` |
| Firebase 项目 | `petoteco-5e807` |
| APP 仓库 | `calmpaws-petoteco`（main 分支） |

---

**遇到服务器端问题（API 返回不对、想加字段、有 bug）直接反馈，服务器侧可以快速迭代。**

> 整理日期：2026-06-08
> 服务器版本：V5.1 + E1-G
> 数据库：MariaDB 11.8
