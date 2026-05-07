# BlueSDK 故障排查指南

---

## 1. 连接问题

### 问题：扫描不到设备

**可能原因：**
- 蓝牙权限未授权
- 设备未开机或超出信号范围
- 设备广播名称不以 `LX-PD02` 开头

**排查步骤：**
1. 调用 `checkPermissions()` 确认权限状态为 `GRANTED`
2. 确认设备已开机，距离在 10 米以内
3. 开启 DEBUG 日志，查看扫描过滤日志

```swift
// iOS
BlueSDK.shared.setLogLevel(.debug)
```

---

### 问题：连接成功但立即断开

**可能原因：**
- GATT 服务/特征 UUID 不匹配（当前使用占位 UUID）
- 设备固件版本不兼容

**排查步骤：**
1. 确认 `BLEConnector` 中的 UUID 与实际硬件一致
2. 查看 DEBUG 日志中的 GATT 服务发现过程

> ⚠️ 当前 SDK 使用通用串口服务 UUID（`FFE0`/`FFE1`）作为占位，需替换为实际 UUID。

---

### 问题：连接后无法认证

**可能原因：**
- 手机 MAC 地址获取错误
- 设备 MAC 地址不正确
- 密钥计算错误

**排查步骤：**
1. 开启 DEBUG 日志，查看认证帧发送记录
2. 验证密钥计算：`key[i] = (phoneMac[i] + deviceMac[i]) & 0xFF`
3. 确认设备 MAC 地址来源正确（通常从扫描结果获取）

```swift
// 验证密钥计算（iOS）
// 手机 MAC: C7 50 B2 AA C3 F3
// 设备 MAC: A6 C0 82 00 A1 C2
// 期望密钥: 6D 10 34 AA 64 B5
```

---

## 2. 指令超时

### 问题：所有指令都超时

**可能原因：**
- 设备未完成认证（状态未到 `AUTHENTICATED`）
- BLE 连接已断开但未触发断开回调

**排查步骤：**
1. 检查 `connectionState` 是否为 `AUTHENTICATED`
2. 调用业务 API 前确认认证已完成

```swift
// iOS
guard BlueSDK.shared.connectionState == .authenticated else {
    print("请先完成认证")
    return
}
```

---

### 问题：偶发指令超时

**可能原因：**
- BLE 信号干扰
- 设备处理繁忙

**说明：**
SDK 内置超时重试机制（5秒超时，最多重试3次），偶发超时会自动重试，无需上层处理。

---

## 3. 用药事件问题

### 问题：收不到用药事件回调

**可能原因：**
- 未注册 Delegate/Listener
- 设备未触发闹钟（时间未到）
- 连接已断开

**排查步骤：**
1. 确认已设置 `BlueSDK.shared.delegate = self`（iOS）或 `sdk.listener = this`（Android）
2. 确认设备连接状态为 `AUTHENTICATED`
3. 开启 DEBUG 日志，查看设备上报帧

---

### 问题：用药事件状态不正确

**可能原因：**
- DPID 0x68 的 byte10 解析错误

**说明：**
用药事件通过 DPID=0x68（alarm3）上报，byte10 为状态值：
- `0x01` = TAKEN（按时取药）
- `0x02` = TIMEOUT（超时取药）
- `0x03` = MISSED（漏服）
- `0x04` = EARLY（提前取药）

---

## 4. 平台特定问题

### iOS：后台收不到用药事件

**原因：** iOS 系统限制后台 BLE 连接。

**解决方案：**
1. 在 `Info.plist` 添加 `bluetooth-central` 后台模式
2. 结合 APNs 推送通知作为补偿机制

---

### Android：部分机型连接失败

**已知兼容性问题：**
- 华为 EMUI 部分版本需要开启"位置服务"才能扫描 BLE
- 小米 MIUI 需要在"自启动管理"中允许 APP

**排查步骤：**
1. 确认 `ACCESS_FINE_LOCATION` 权限已授权（Android 6~11）
2. 确认位置服务已开启
3. 查看 DEBUG 日志中的扫描和连接过程

---

### Android：`MissingPluginException`

**原因：** 模拟器不支持 BLE 硬件。

**解决方案：** 使用真实 Android 设备进行测试。

---

## 5. 调试技巧

### 开启完整调试日志

```swift
// iOS
BlueSDK.shared.setLogLevel(.debug)
BlueSDK.shared.setLogHandler { level, tag, message in
    print("[\(level)][\(tag)] \(message)")
}
```

```kotlin
// Android
sdk.setLogLevel(LogLevel.DEBUG)
sdk.setLogHandler { level, tag, message ->
    Log.d(tag, "[$level] $message")
}
```

DEBUG 级别日志包含：
- 原始帧数据（十六进制）
- CRC8 计算过程
- 认证流程（密钥值已脱敏）
- 状态机转换

---

### 验证 CRC8 计算

```python
# Python 验证脚本
def crc8(data):
    return sum(b & 0xFF for b in data) % 256

# 验证密钥包帧
payload = [0x55, 0xAA, 0x00, 0x00, 0x00, 0x02, 0x07, 0x74]
print(hex(crc8(payload)))  # 应输出 0x7c
```

---

## 6. 已知问题

| # | 问题 | 状态 | 说明 |
|---|------|------|------|
| 1 | 时间同步帧格式 | ⏳ 待确认 | 协议文档示例帧与预期不符 |
| 2 | DPID 0x6E/0x6F/0x70 用途 | ⏳ 待确认 | 文档注释与示例帧不一致 |
| 3 | BLE GATT UUID | ⏳ 待确认 | 当前使用通用串口服务 UUID 占位 |

---

## 7. Issue 报告模板

提交 Bug 时请包含以下信息：

```
**环境**
- 平台: iOS / Android
- 系统版本: 
- 设备型号: 
- SDK 版本: 0.1.0

**问题描述**
[简要描述问题]

**复现步骤**
1. 
2. 
3. 

**期望行为**
[描述期望的结果]

**实际行为**
[描述实际发生的情况]

**DEBUG 日志**
[粘贴相关日志，注意脱敏处理]
```
