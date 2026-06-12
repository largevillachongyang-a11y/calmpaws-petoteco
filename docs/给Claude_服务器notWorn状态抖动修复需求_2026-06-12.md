# CalmPaws 服务器未佩戴状态修复需求

日期：2026-06-12  
接收方：Claude / 服务器侧  
目标：修复 APP 中“项圈未佩戴 / 安心休息 / 长时间没有翻身”来回切换的问题，并明确三种长时间不动状态的服务器判断标准。

## 一、当前结论

这次问题不是单纯 APP 显示问题。APP 已经支持服务器返回：

- `sleep_state = notWorn`
- `sleep_state = not_worn`
- `sleep_state = sleepNormal`
- `sleep_state = sleepAbnormal`

但实测时，同一个设备会在不同状态之间反复跳变。结合服务器代码和日志看，主要有两个问题：

1. 服务器当前用 `gunicorn --workers 2`，但实时状态存在进程内存里，多个 worker 会各自维护一份 `devices` 状态，导致 `still_sec / sleep_state / continuous_calm_sec` 不一致。
2. 当前未佩戴逻辑只有“确认未佩戴”，没有“疑似未佩戴”阶段；进入阈值 30 分钟偏长，退出阈值又过于敏感，一次 `last_std >= 0.04` 就退出，容易抖动。

## 二、三种“长时间不动”状态定义

长时间不动不能统一显示为“平静”，也不能统一显示为“异常”。服务器和 APP 需要统一区分下面三种状态。

### 1. 安静睡眠 / 正常休息

含义：项圈确认佩戴在宠物身上，宠物处于平静休息或正常睡眠状态。

服务器判断建议：

- 未达到疑似未佩戴或确认未佩戴条件。
- AI 基础行为为 `calm`。
- `calm` 持续达到入睡阈值，例如 30 分钟。
- 尚未达到异常无翻身阈值，或期间检测到翻身/微动。

服务器返回：

```text
sleep_state = sleepNormal
```

APP 显示：

```text
安心休息 / 睡眠正常
焦虑分 0 / 100
```

### 2. 异常昏睡 / 长时间没有翻身

含义：项圈确认佩戴在宠物身上，但宠物长时间没有翻身或有效微动，需要主人关注。

服务器判断建议：

- 未达到疑似未佩戴或确认未佩戴条件。
- AI 基础行为为 `calm`。
- 已进入睡眠判断。
- 连续无翻身/有效微动超过异常阈值，例如 2 小时。

服务器返回：

```text
sleep_state = sleepAbnormal
```

APP 显示：

```text
长时间没有翻身
焦虑分 0 / 100，建议查看状态
```

顶部告警可显示：

```text
已连续 xxx 分钟没有翻身动作
```

### 3. 未佩戴

含义：设备仍然在线并上传数据，但项圈大概率没有佩戴在宠物身上，例如放在桌上。此时数据不能代表宠物状态。

服务器返回：

```text
sleep_state = notWorn
```

APP 显示：

```text
项圈未佩戴，请检查
当前数据不代表宠物状态
```

不应该显示：

- 安心休息
- 睡眠正常
- 长时间没有翻身
- 焦虑分 0 = 宠物很平静

## 三、未佩戴进入标准

当前代码标准是：

```python
NOT_WORN_STD_THRESHOLD = 0.04
NOT_WORN_TIME_THRESHOLD = 1800
```

也就是：

```text
last_std < 0.04 连续 30 分钟 -> notWorn
```

这个 30 分钟偏长。用户把项圈摘下来放桌上后，APP 还会继续显示“安心休息/睡眠正常”很久，体验不合理。

建议改成两阶段：

```text
疑似未佩戴：last_std < 0.04 连续 3 分钟
确认未佩戴：last_std < 0.04 连续 10 分钟
```

推荐参数：

```python
NOT_WORN_STD_THRESHOLD = 0.04
SUSPECT_NOT_WORN_TIME_THRESHOLD = 180    # 3 分钟
CONFIRMED_NOT_WORN_TIME_THRESHOLD = 600  # 10 分钟
```

服务器返回建议：

```text
0-3 分钟：
不返回未佩戴，继续按当前行为/睡眠状态返回。

3-10 分钟：
返回疑似未佩戴状态。

10 分钟以上：
返回确认未佩戴状态。
```

疑似未佩戴建议返回字段可以二选一：

方案 A，扩展 `sleep_state`：

```text
sleep_state = suspectedNotWorn
```

方案 B，保留 `sleep_state`，新增字段：

```json
{
  "sleep_state": "sleepNormal",
  "wear_state": "suspected_not_worn"
}
```

我更建议方案 B，长期更清晰：

```json
{
  "wear_state": "worn | suspected_not_worn | not_worn",
  "sleep_state": "unknown | sleepNormal | sleepAbnormal"
}
```

如果这次为了快速联调，也可以先用方案 A，APP 侧可以很快适配。

## 四、未佩戴退出标准

当前代码退出未佩戴的标准是：

```text
只要一次 last_std >= 0.04，就清零 still_sec，并退出 notWorn 判断。
```

当前代码：

```python
if last_std < NOT_WORN_STD_THRESHOLD:
    dev['still_sec'] = dev.get('still_sec', 0) + interval_sec
    if dev['still_sec'] >= NOT_WORN_TIME_THRESHOLD:
        dev['sleep_state'] = 'notWorn'
        return
else:
    dev['still_sec'] = 0
```

这个退出标准过于敏感。项圈放桌上时，轻微碰一下、传感器噪声、请求打到另一个 worker，都可能让 APP 从“未佩戴”跳回“安心休息”。

建议改成：

```text
退出未佩戴：last_std >= 0.04 连续 30-60 秒
或检测到明确佩戴/有效活动信号后退出。
```

推荐参数：

```python
WORN_STD_THRESHOLD = 0.04
WORN_CONFIRM_TIME_THRESHOLD = 60
```

如果能结合更多信号，优先级建议：

1. 明显运动或翻身计数 `roll_c` 增加。
2. 连续 30-60 秒 `last_std >= 0.04`。
3. 如果后续硬件有心率/接触/佩戴检测信号，以硬件佩戴信号为最高可信来源。

退出后建议不要立刻显示 `sleepNormal`，而是先回到：

```text
sleep_state = unknown
wear_state = worn
```

再由后续行为数据重新进入 `sleepNormal / sleepAbnormal`。

## 五、状态优先级

注意：不是“只要静止就未佩戴优先”。

准确规则应该是：

```text
确认未佩戴后，notWorn 优先级最高。
未确认之前，继续按正常宠物行为/睡眠状态显示。
```

建议服务器判断顺序：

```text
1. 计算 last_std。

2. 如果 last_std < 0.04：
   累加 still_sec。

3. 如果 still_sec >= 600 秒：
   返回确认未佩戴。
   不再返回 sleepNormal / sleepAbnormal。

4. 如果 still_sec >= 180 秒且 < 600 秒：
   返回疑似未佩戴。
   APP 不应显示“安心休息”，应提示用户检查项圈。

5. 如果未达到疑似未佩戴：
   正常判断 calm / sleepNormal / sleepAbnormal / anxious 等状态。

6. 如果处于 notWorn，但检测到连续有效运动 30-60 秒：
   退出 notWorn，回到 unknown 或正常行为状态。
```

## 六、当前日志证据

服务器日志中出现：

```text
[未佩戴探针] collar_001 三轴std合=0.015x ~ 0.030x
```

这些值低于当前 `0.04` 阈值，说明设备放置不动时，传感器数据确实符合“极低波动”条件。

另外，用户实测 APP 中状态会交替出现：

- 项圈未佩戴
- 安心休息
- 长时间没有翻身

这说明服务器状态不是稳定单一来源，和当前 `gunicorn --workers 2` 加内存态 `devices = {}` 的结构高度吻合。

## 七、必须先修的服务器运行问题

当前 systemd / gunicorn 配置里使用了：

```text
--workers 2
```

而服务器代码里实时状态存在进程内存：

```python
devices = {}
```

这些字段都会被拆到不同 worker：

- `sleep_state`
- `still_sec`
- `continuous_calm_sec`
- `sleep_no_roll_sec`
- `_last_std`
- `_prev_roll_c`
- `app_last_seen`

短期必须改成：

```text
--workers 1
```

否则同一个设备的上传请求、APP status 请求可能命中不同 worker，APP 看到的状态就会抖动。

长期如果必须多 worker，需要把实时状态放到共享存储，例如 Redis 或数据库，不能继续存在进程内存里。

## 八、建议服务器返回字段

短期兼容方案：

```json
{
  "sleep_state": "unknown | sleepNormal | sleepAbnormal | suspectedNotWorn | notWorn"
}
```

长期推荐方案：

```json
{
  "wear_state": "worn | suspected_not_worn | not_worn",
  "sleep_state": "unknown | sleepNormal | sleepAbnormal",
  "still_sec": 245,
  "last_std": 0.018
}
```

这样 APP 可以清楚区分：

- 佩戴状态：是否戴着
- 睡眠状态：戴着时睡得是否正常

## 九、验收标准

### 1. 放桌上不动

操作：

```text
项圈放桌上，保持不动。
```

期望：

```text
0-3 分钟：APP 不显示未佩戴，可正常显示当前状态。
3-10 分钟：APP 显示疑似未佩戴。
10 分钟后：APP 稳定显示项圈未佩戴。
```

不能出现：

```text
项圈未佩戴 / 安心休息 / 长时间没有翻身 来回切换
```

### 2. 确认未佩戴后轻微噪声

操作：

```text
项圈已进入 notWorn 后，桌面轻微震动或偶发一次 last_std >= 0.04。
```

期望：

```text
不应立刻退出 notWorn。
需要连续有效运动 30-60 秒后才退出。
```

### 3. 重新佩戴或持续活动

操作：

```text
拿起项圈，持续晃动或佩戴到宠物身上。
```

期望：

```text
连续有效运动 30-60 秒后退出 notWorn。
先回到 unknown 或正常行为状态。
后续再按真实数据进入 sleepNormal / sleepAbnormal / anxious 等。
```

### 4. API 连续请求

操作：

```bash
for i in {1..10}; do
  curl -s "https://api.petoteco.com/api/status/collar_001" \
    -H "X-Device-Key: <device_key>" | jq '{sleep_state, wear_state, still_sec, last_std}'
  sleep 2
done
```

期望：

```text
同一阶段内状态稳定，不应在 notWorn / sleepNormal / sleepAbnormal / unknown 之间随机跳。
```

## 十、请 Claude 修改后同步

请修改完成后同步下面信息，方便 APP 侧适配：

1. 最终采用的返回字段：
   - 只用 `sleep_state`
   - 还是新增 `wear_state`
2. 疑似未佩戴的返回值名称。
3. 确认未佩戴的返回值名称。
4. 进入疑似未佩戴阈值。
5. 进入确认未佩戴阈值。
6. 退出未佩戴阈值。
7. gunicorn 是否已改为单 worker，或是否已使用共享状态存储。

APP 侧会根据最终字段做展示适配。
