# 给 Claude：history Bearer 鉴权复测问题

日期：2026-06-10

## 结论

服务器 P0 修复还没有完全达到约定验收标准。

已确认：

- 无 token 访问 `/api/history/collar_001` 返回 401，符合预期。
- 假 Bearer token 访问 `/api/history/collar_001` 返回 401，符合预期。
- 新建 Firebase 临时账号后，`/api/user/devices` 可以用该账号 Bearer token 返回 200，说明 token 是有效的、Firebase Admin 验证链路可用。

但问题是：

- 同一个“有效但未绑定 collar_001 的 Firebase 用户”访问 `/api/history/collar_001` 返回 401。
- 按之前约定，token 有效但设备不属于该用户时应返回 403。

## 复测步骤

### 1. 无 token

```text
GET /api/history/collar_001?range=24h -> 401
GET /api/history/collar_001?range=7d  -> 401
GET /api/history/collar_001?range=30d -> 401
```

结果符合预期。

### 2. 假 token

请求头：

```text
Authorization: Bearer definitely.invalid.test.token
```

结果：

```text
GET /api/history/collar_001?range=24h -> 401
GET /api/history/collar_001?range=7d  -> 401
GET /api/history/collar_001?range=30d -> 401
```

结果符合预期。

### 3. 有效 Firebase token，但用户未绑定设备

用 Firebase REST 创建临时 email/password 用户，并拿到 ID token。

先验 token 是否有效：

```text
GET /api/user/devices
Authorization: Bearer <valid Firebase ID token>
```

实际结果：

```json
{"devices":[],"uid":"UZIpKDEIloZFb2Y2SN9PXvTig9V2"}
```

说明：

- Bearer token 有效。
- 服务器能正确解析 uid。
- 该用户没有绑定设备。

再访问设备数据：

```text
GET /api/status/collar_001  -> 401
GET /api/alerts/collar_001  -> 401
GET /api/history/collar_001?range=24h -> 401
```

## 与验收标准不一致的地方

之前约定：

- token 缺失或无效：401
- token 有效但设备未绑定/不属于该用户：403
- token 有效且用户绑定该设备：200

当前实际：

- token 有效但设备未绑定时，`history/status/alerts` 返回 401。

这会让 APP 无法区分：

- 登录过期/需要重新登录
- 账号没有绑定该设备
- 设备权限被拒绝

## 建议修改

在 `check_request_key` 或每个设备数据接口的 Bearer 分支里区分三类结果：

1. 没有 Bearer / token 无效 / token 过期  
   返回 401。

2. Bearer token 有效，但 `uid` 未绑定 `device_id`  
   返回 403，body 建议：

```json
{"error":"device_not_bound","device_id":"collar_001"}
```

3. Bearer token 有效，且 `uid` 已绑定 `device_id`  
   返回 200。

## APP 侧处理决定

在服务器修到上述标准前，APP 侧暂时不移除 history 旧 key 兜底逻辑。

原因：

- 现在还没有完成“已绑定账号 Bearer history 200”的正向验收。
- 未绑定账号返回码也还没有达到 403 标准。

等服务器修正后，再做下一轮验收：

```text
绑定账号 + Bearer:
GET /api/history/collar_001?range=24h -> 200
GET /api/history/collar_001?range=7d  -> 200
GET /api/history/collar_001?range=30d -> 200

未绑定账号 + Bearer:
GET /api/history/collar_001?range=24h -> 403

无 token / 假 token:
GET /api/history/collar_001?range=24h -> 401
```
