# APP 独立收尾验收说明

> **预览**：https://largevillachongyang-a11y.github.io/calmpaws-petoteco/  
> **原则**：**不依赖服务器的就做**；依赖服务器的（P2 头像/FCM）仍待服务器。

---

## 本阶段做了什么

| 项 | 说明 |
|----|------|
| **文档修正** | 差距清单 §十一 明确「不依赖服务器的就做 / 依赖服务器则不做」 |
| **`/api/alerts` Dashboard** | `ServerAlertsBanner`：连接后拉取 + 60s 轮询；有告警显示在设备栏下方 |
| **代码清理** | 删 `firestore` 喂食/压力读写；删 `mock_ble` 的 `generateDailyStressChart`（喂食 widget P1 已删） |
| **焦虑分 i18n** | 行为卡圆环底部标签走 `AppStrings.anxietyScoreLabel` |

---

## 验收步骤

### 1. alerts 接口（Network）

1. 打开预览 → 连接设备。
2. DevTools → Network，应看到：
   - `GET /api/alerts/collar_001?key=calmpaws_secret` → 200
   - 响应形如 `{"alerts":[]}` 或含告警对象数组
3. **空数组**：Dashboard **不显示**告警横幅（正常）。
4. **有告警**（需服务器配置）：设备栏下方出现「设备告警」横幅，文案来自 `message` 或按 `type` 本地化（如 `low_battery`）。

### 2. 焦虑分 i18n

- 切换 APP 语言（中/英），行为卡圆环底部应显示 **焦虑分** / **Anxiety**。

### 3. 代码清理回归

- Dashboard 仍无喂食卡、无 Time-to-Calm。
- 历史图、行为卡、204 等待 UI 行为与 P0 收尾一致。

---

## 服务器配合（alerts 有数据时）

建议在 `alerts` 数组元素中包含：

```json
{
  "type": "low_battery",
  "message": "项圈电量 15%，请充电",
  "battery": 15,
  "severity": "warning"
}
```

`message` 非空时 APP 直接展示；仅 `type` + `battery` 时 APP 用本地化模板。

---

*完整差距与待办见 `docs/APP_差距清单_对照全景对接v2.md` §十一、§十三。*
