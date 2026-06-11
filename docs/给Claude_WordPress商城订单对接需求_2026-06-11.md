# 给 Claude：WordPress / WooCommerce 商城订单对接需求

日期：2026-06-11

## 背景

CalmPaws APP 当前已经有 Firebase 登录体系，用户可用 Google 或邮箱密码登录。商城页面目前只做产品展示，并跳转到 `https://petotecolife.com/` 完成购买。

因为商城是 WordPress 站点，订单、支付、订阅都在 WordPress / WooCommerce 侧产生。APP 不能直接使用 WooCommerce API key，也不能假展示订单。因此需要服务器侧做安全中转：

APP -> CalmPaws API Server -> WordPress / WooCommerce API

## 目标

服务器新增一组只读商城接口，让 APP 登录用户可以在 APP 内查看自己在 WordPress/WooCommerce 的订单和订阅状态。

第一阶段只做只读查询，不做 APP 内支付，不做 APP 内取消订阅，不修改 WordPress 数据。

## 安全原则

1. APP 只带 Firebase Bearer token。
2. WooCommerce consumer key / secret 只能保存在服务器环境变量，不能下发到 APP。
3. 服务器必须验证 Firebase token 后，再用该用户邮箱查询 WooCommerce。
4. 查询结果只返回当前 Firebase 用户邮箱对应的订单。
5. 服务器日志不能打印 Firebase token、WooCommerce secret、完整支付信息。

## 需要配置的服务器环境变量

```bash
WORDPRESS_URL=https://petotecolife.com
WC_CONSUMER_KEY=ck_xxx
WC_CONSUMER_SECRET=cs_xxx
```

如果 WordPress 后台开启了不同的 REST 路径或安全插件限制，请同步实际可访问路径。

## 新增接口 1：查询订单列表

### Request

```http
GET /api/shop/orders
Authorization: Bearer <firebase_id_token>
```

可选参数：

```http
GET /api/shop/orders?page=1&per_page=20
```

### 服务器逻辑

1. 验证 Firebase Bearer token。
2. 取出 Firebase 用户的 `uid` 和 `email`。
3. 如果 email 为空，返回 400。
4. 用 email 查询 WooCommerce customer：

```http
GET /wp-json/wc/v3/customers?email=<email>
```

5. 如果找不到 customer，返回空订单列表，不算错误。
6. 如果找到 customer，使用 customer id 查询订单：

```http
GET /wp-json/wc/v3/orders?customer=<customer_id>&page=1&per_page=20&orderby=date&order=desc
```

7. 返回 APP 需要的精简字段。

### Response 200

```json
{
  "email": "user@example.com",
  "customer_id": 123,
  "orders": [
    {
      "id": 456,
      "number": "456",
      "status": "processing",
      "status_label": "Processing",
      "currency": "USD",
      "total": "29.90",
      "date_created": "2026-06-11T10:20:30",
      "payment_method_title": "Credit card",
      "items": [
        {
          "name": "ZenBelly Calming Probiotic Chews",
          "quantity": 1,
          "total": "29.90"
        }
      ],
      "order_url": "https://petotecolife.com/my-account/view-order/456/"
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "has_more": false
  }
}
```

### 状态码

```text
200 查询成功，可能 orders 为空
400 Firebase 用户没有 email
401 token 缺失或无效
502 WooCommerce API 调用失败
500 服务器内部错误
```

## 新增接口 2：查询订单详情

### Request

```http
GET /api/shop/orders/<order_id>
Authorization: Bearer <firebase_id_token>
```

### 服务器逻辑

1. 验证 Firebase token，取 email。
2. 查询 WooCommerce order。
3. 校验订单 billing email 或 customer email 必须等于 Firebase email。
4. 不匹配则返回 403。
5. 返回订单详情精简字段。

### Response 200

```json
{
  "id": 456,
  "number": "456",
  "status": "processing",
  "currency": "USD",
  "total": "29.90",
  "date_created": "2026-06-11T10:20:30",
  "billing_email": "user@example.com",
  "items": [
    {
      "name": "ZenBelly Calming Probiotic Chews",
      "quantity": 1,
      "subtotal": "29.90",
      "total": "29.90"
    }
  ],
  "shipping": {
    "method": "Free shipping",
    "total": "0.00"
  },
  "order_url": "https://petotecolife.com/my-account/view-order/456/"
}
```

## 新增接口 3：商城账号入口

用途：APP 需要一个按钮跳转 WordPress 账号/订单页。

### Request

```http
GET /api/shop/account-url
Authorization: Bearer <firebase_id_token>
```

### 第一阶段 Response

如果暂时不能做自动登录，只返回普通账号页：

```json
{
  "url": "https://petotecolife.com/my-account/",
  "auto_login": false,
  "message": "Please sign in on the website with the same email used in the app."
}
```

### 后续增强

如果 WordPress 侧支持安全的一次性登录链接，可以后续返回：

```json
{
  "url": "https://petotecolife.com/my-account/?login_token=one_time_token",
  "auto_login": true,
  "expires_in": 300
}
```

一次性登录必须满足：

1. token 短有效期，建议 5 分钟。
2. token 只能使用一次。
3. token 绑定 Firebase email。
4. 不在 URL 中暴露 WooCommerce key。

## 订阅状态

如果 WordPress 使用 WooCommerce Subscriptions 插件，请额外提供：

```http
GET /api/shop/subscriptions
Authorization: Bearer <firebase_id_token>
```

Response 示例：

```json
{
  "subscriptions": [
    {
      "id": 789,
      "status": "active",
      "status_label": "Active",
      "next_payment_date": "2026-07-11T00:00:00",
      "total": "29.90",
      "currency": "USD",
      "items": [
        {
          "name": "ZenBelly Monthly Subscription",
          "quantity": 1
        }
      ],
      "manage_url": "https://petotecolife.com/my-account/view-subscription/789/"
    }
  ]
}
```

如果没有安装 WooCommerce Subscriptions，先不用做这个接口，但请明确告诉 APP 侧。

## APP 侧依赖

服务器完成后，APP 会做以下工作：

1. 恢复“我的订单”入口，但只展示真实接口数据。
2. 商城页显示订单列表入口。
3. 无订单时显示“暂无订单，前往官网购买”。
4. 有订单时显示订单号、状态、金额、商品、日期。
5. 点击订单打开订单详情页或官网订单页。
6. 如果 `/api/shop/subscriptions` 可用，再恢复订阅状态展示。

在接口完成前，APP 不展示订单记录和订阅状态，避免假功能。

## 验收用例

### 用例 1：有订单用户

同一个邮箱：

1. Firebase 登录 APP。
2. WordPress / WooCommerce 存在该邮箱的订单。
3. 请求：

```http
GET /api/shop/orders
Authorization: Bearer <valid token>
```

期望：200，返回订单列表。

### 用例 2：无订单用户

Firebase 用户邮箱在 WooCommerce 没有 customer 或没有订单。

期望：200，`orders: []`。

### 用例 3：无效 token

期望：401。

### 用例 4：越权订单详情

用户 A 请求用户 B 的 order id。

期望：403。

### 用例 5：WooCommerce API 异常

WordPress 不通、key 错误、REST 被拦截。

期望：502，并记录安全日志，不泄露 secret。

## 日志建议

成功日志：

```text
shop.orders uid=<uid> email_hash=<hash> customer_id=<id> count=<n>
```

失败日志：

```text
shop.orders.failed reason=<reason> status=<wc_status>
```

不要记录：

1. Firebase token 原文。
2. WooCommerce consumer secret。
3. 完整地址、电话、支付卡信息。

## 需要 Claude 回传的信息

完成后请同步：

1. 已实现的接口列表。
2. WordPress 使用的是 WooCommerce 标准订单，还是有 Subscriptions 插件。
3. `/api/shop/orders` 测试结果。
4. 是否支持自动登录到 WordPress 账号页。
5. 如果有字段和本文档不同，请给最终 Response 示例。

