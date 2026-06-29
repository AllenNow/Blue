# BlueSDK 接入指南

LX-PD02 智能药盒蓝牙通信 SDK — iOS & Android 双端接入文档

---

## 目录

- [概述](#概述)
- [系统要求](#系统要求)
- [集成步骤](#集成步骤)
- [权限配置](#权限配置)
- [初始化](#初始化)
- [扫描与连接](#扫描与连接)
- [认证机制](#认证机制)
- [功能接口一览](#功能接口一览)
- [事件回调一览](#事件回调一览)
- [错误处理](#错误处理)
- [线程模型](#线程模型)
- [最佳实践](#最佳实践)
- [FAQ](#faq)

---

## 概述

BlueSDK 完整封装 LX-PD02 私有蓝牙 5.0 通信协议，接入方无需了解底层帧结构、CRC 校验、密钥算法等细节。SDK 提供统一的高层 API，两端（iOS/Android）接口设计高度一致，降低跨平台维护成本。

**核心能力：**

| 能力 | 说明 |
|------|------|
| BLE 扫描与连接 | 自动重连（指数退避，最多 5 次） |
| 密钥认证 | 自动计算或固定密钥，认证失败有明确恢复建议 |
| 闹钟管理 | 7 个槽位 CRUD，支持周期设置 |
| 用药事件 | 实时接收响铃/超时/取药/漏服事件 |
| 用药记录 | 设备主动上报含毫秒时间戳的完整记录 |
| 音频系统设置 | 音量/铃声/静音/时长/12H-24H时制 |
| 设备管理 | 设备信息查询/时间同步/恢复出厂/解绑 |
| 日志系统 | 分级日志，密钥脱敏，支持导出 |

---

## 系统要求

| 平台 | 最低版本 | 语言 | 蓝牙 |
|------|---------|------|------|
| Android | API 21 (5.0+) | Kotlin 1.9+ | BLE 5.0+ |
| iOS | 13.0+ | Swift 5.7+ | BLE 5.0+ |

---

## 集成步骤

### Android

**方式 A：本地 AAR**

```kotlin
// app/build.gradle.kts
dependencies {
    implementation(files("libs/blue-sdk-release.aar"))
}
```

**方式 B：模块依赖（开发阶段）**

```kotlin
// settings.gradle.kts
include(":blue-sdk")

// app/build.gradle.kts
dependencies {
    implementation(project(":blue-sdk"))
}
```

### iOS

**CocoaPods**

```ruby
pod 'BlueSDK', :path => '../blue-sdk-ios/BlueSDK'
```

**SPM**

```swift
.package(path: "../blue-sdk-ios")
```

---

## 权限配置

### Android — AndroidManifest.xml

```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<!-- Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>
```

### iOS — Info.plist

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限以连接智能药盒设备</string>

<!-- 可选：后台接收用药事件 -->
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

---

## 初始化

### Android

```kotlin
// Application.onCreate() 中调用一次
val config = BlueSDKConfig(
    fixedAuthKey = null,        // 固定密钥（4位hex），null=自动计算
    logLevel = LogLevel.DEBUG,  // 生产环境用 LogLevel.NONE
    autoAuthEnabled = true      // 连接成功后自动认证
)
BlueSDK.getInstance(this).initialize(config)
```

### iOS

```swift
// AppDelegate didFinishLaunching 中调用
let config = BlueSDKConfig(
    fixedAuthKey: nil,
    logLevel: .debug,
    autoAuthEnabled: true
)
BlueSDK.shared.initialize(config: config)
```

---

## 扫描与连接

### Android

```kotlin
val sdk = BlueSDK.getInstance(context)

sdk.startScan(timeoutMs = 10000L) { event ->
    when (event) {
        is ScanEvent.DeviceFound -> {
            // event.device 包含 deviceId, deviceName, rssi
            sdk.connect(event.device)  // SDK 自动完成认证
            sdk.stopScan()
        }
        is ScanEvent.Error -> { /* error.message */ }
        is ScanEvent.Stopped -> { /* 超时或手动停止 */ }
    }
}
```

### iOS

```swift
BlueSDK.shared.startScan(timeout: 10) { event in
    switch event {
    case .deviceFound(let device):
        BlueSDK.shared.connect(device)
        BlueSDK.shared.stopScan()
    case .error(let error):
        print(error.localizedDescription)
    case .stopped:
        break
    }
}
```

---

## 认证机制

SDK 支持两种认证模式：

| 模式 | 配置 | 说明 |
|------|------|------|
| 自动认证 | `fixedAuthKey = null` | SDK 根据手机 MAC + 设备 MAC 自动计算密钥 |
| 固定密钥 | `fixedAuthKey = "05FA"` | 使用预设的 4 位 hex 密钥 |

连接成功后 SDK **自动发起认证**，无需手动调用。认证结果通过回调通知：

```kotlin
// Android
override fun onAuthResult(success: Boolean, error: BlueError?) { }

// iOS
func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?) { }
```

---

## 功能接口一览

所有业务接口需在 `AUTHENTICATED` 状态后调用，否则返回 `NotAuthenticated` 错误。

### 生命周期

| 接口 | Android | iOS | 说明 |
|------|---------|-----|------|
| 初始化 | `initialize(config)` | `initialize(config:)` | Application 层调用一次 |
| 销毁 | `destroy()` | `destroy()` | 释放 BLE 资源 |

### 连接管理

| 接口 | Android | iOS | 说明 |
|------|---------|-----|------|
| 扫描设备 | `startScan(timeoutMs, callback)` | `startScan(timeout:callback:)` | 统一 ScanEvent 回调 |
| 停止扫描 | `stopScan()` | `stopScan()` | |
| 连接设备 | `connect(device)` | `connect(device)` | 连接后自动认证 |
| 断开连接 | `disconnect()` | `disconnect()` | 主动断开不触发重连 |
| 取消重连 | `cancelReconnection()` | `cancelReconnection()` | |
| 解绑设备 | `clearBinding(completion)` | `clearBinding(completion:)` | 发送解绑指令+断开 |
| 指定密钥认证 | `authenticateWithKey(hi, lo, cb)` | `authenticateWithKey(keyHigh:keyLow:completion:)` | |
| 查询权限 | `checkPermissions()` | `checkPermissions()` | 返回 PermissionStatus |
| 连接状态 | `connectionState` (属性) | `connectionState` (属性) | |
| 当前时制 | `currentTimeFormat` (属性) | `currentTimeFormat` (属性) | 跟随设备设置 |

### 设备信息与时间

| 接口 | Android | iOS | 说明 |
|------|---------|-----|------|
| 查询设备信息 | `queryDeviceInfo(completion)` | `queryDeviceInfo(completion:)` | MAC + 固件版本 |
| 时间同步 | `syncTime(completion)` | `syncTime(completion:)` | 下发当前系统时间 |

### 闹钟管理（7 槽位）

| 接口 | Android | iOS | 说明 |
|------|---------|-----|------|
| 设置闹钟 | `setAlarm(index, hour, minute, days, cb)` | `setAlarm(index:hour:minute:days:completion:)` | 类型安全版本 |
| 批量设置 | `setAlarms(list, completion)` | `setAlarms(_:completion:)` | 串行发送 |
| 查询闹钟 | `queryAlarm(index, completion)` | `queryAlarm(index:completion:)` | 查询单个槽位 |
| 删除闹钟 | `deleteAlarm(index, completion)` | `deleteAlarm(index:completion:)` | |
| 清空所有 | `clearAllAlarms(completion)` | `clearAllAlarms(completion:)` | |

**参数约束：**
- `index`: 1~7
- `hour`: 0~23
- `minute`: 0~59
- `days`: `WeekDays` 枚举（`.ALL` / `.WEEKDAYS` / `.WEEKEND` / 自定义组合）

### 音频与系统设置

| 接口 | Android | iOS | 说明 |
|------|---------|-----|------|
| 设置音量 | `setVolume(level, cb)` | `setVolume(_:completion:)` | LOW / MEDIUM / HIGH |
| 设置铃声 | `setSoundType(type, cb)` | `setSoundType(_:completion:)` | TYPE_A / TYPE_B |
| 设置静音 | `setSilence(enabled, cb)` | `setSilence(_:completion:)` | true=静音 |
| 提醒时长 | `setAlertDuration(minutes, cb)` | `setAlertDuration(_:completion:)` | 1~5 分钟 |
| 时间格式 | `setTimeFormat(format, cb)` | `setTimeFormat(_:completion:)` | HOUR_12 / HOUR_24 |
| 恢复出厂 | `restoreFactory(completion)` | `restoreFactory(completion:)` | 设备重启断开 |

### 用药事件

| 接口 | Android | iOS | 说明 |
|------|---------|-----|------|
| 下发用药通知 | `sendMedicationNotification(status, cb)` | `sendMedicationNotification(status:completion:)` | |

### 日志

| 接口 | Android | iOS | 说明 |
|------|---------|-----|------|
| 设置级别 | `setLogLevel(level)` | `setLogLevel(_:)` | DEBUG/INFO/WARN/ERROR/NONE |
| 自定义Handler | `setLogHandler(handler)` | `setLogHandler(_:)` | 接入自有日志系统 |
| 导出日志 | `exportLog(maxLines)` | `exportLog(maxLines:)` | 最近 1000 条 |
| 清空缓冲 | `clearLogBuffer()` | `clearLogBuffer()` | |

---

## 事件回调一览

### Android — `BlueSDKListener` interface

```kotlin
interface BlueSDKListener {
    // 连接
    fun onConnectionStateChanged(state: ConnectionState) {}
    fun onAuthResult(success: Boolean, error: BlueError?) {}
    fun onReconnecting(attempt: Int, maxAttempts: Int) {}
    fun onReconnectFailed() {}
    fun onError(error: BlueError) {}

    // 设备
    fun onDeviceInfoReceived(info: DeviceInfo) {}
    fun onTimeSyncRequested() {}

    // 闹钟
    fun onAlarmUpdated(alarm: AlarmInfo) {}
    fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) {}
    fun onAlarmTimeout(alarmIndex: Int, alarmInfo: AlarmInfo) {}

    // 用药
    fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {}
    fun onMedicationRecordReported(record: MedicationRecord) {}
    fun onMedicationNotification(type: MedicationNotificationType) {}

    // 系统设置
    fun onSoundTypeChanged(type: SoundType) {}
    fun onAlertDurationChanged(minutes: Int) {}
    fun onTimeFormatChanged(format: TimeFormat) {}
    fun onLowBattery() {}
    fun onDeviceUnbound() {}
}
```

### iOS — `BlueSDKDelegate` protocol

```swift
protocol BlueSDKDelegate {
    // 连接
    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState)
    func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?)
    func blueSDK(_ sdk: BlueSDK, didStartReconnecting attempt: Int, maxAttempts: Int)
    func blueSDKDidFailReconnection(_ sdk: BlueSDK)
    func blueSDK(_ sdk: BlueSDK, didEncounterError error: BlueError)

    // 设备
    func blueSDK(_ sdk: BlueSDK, didReceiveDeviceInfo info: DeviceInfo)
    func blueSDKDidRequestTimeSync(_ sdk: BlueSDK)

    // 闹钟
    func blueSDK(_ sdk: BlueSDK, didUpdateAlarm alarm: AlarmInfo)
    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo)
    func blueSDK(_ sdk: BlueSDK, didAlarmTimeout alarmIndex: Int, alarmInfo: AlarmInfo)

    // 用药
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus)
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationRecord record: MedicationRecord)
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationNotification type: MedicationNotificationType)

    // 系统设置
    func blueSDK(_ sdk: BlueSDK, didChangeSoundType type: SoundType)
    func blueSDK(_ sdk: BlueSDK, didChangeAlertDuration minutes: Int)
    func blueSDK(_ sdk: BlueSDK, didChangeTimeFormat format: TimeFormat)
    func blueSDKDidReportLowBattery(_ sdk: BlueSDK)
    func blueSDKDidReportDeviceUnbound(_ sdk: BlueSDK)
}
```

> 所有回调方法均有默认空实现，按需覆写即可。

---

## 错误处理

所有异步操作通过 `Result` 回调返回，**不抛异常**。

### 错误类型

| 错误 | Code | 可重试 | 说明 |
|------|------|--------|------|
| `NotInitialized` | 1 | ❌ | 未调用 initialize() |
| `NotAuthenticated` | 2 | ❌ | 未完成密钥认证 |
| `AuthFailed` | 3 | ❌ | 密钥不匹配，需恢复出厂 |
| `Timeout` | 4 | ✅ | 指令超时（SDK 已内部重试 3 次） |
| `PermissionDenied` | 5 | ❌ | 蓝牙权限未授权 |
| `InvalidParameter` | 6 | ❌ | 参数越界 |
| `ProtocolError` | 7 | ✅ | CRC 校验失败，可能蓝牙干扰 |
| `BleError` | 8 | ✅ | 系统蓝牙异常 |
| `Disconnected` | 9 | ✅ | 设备断开，SDK 会自动重连 |
| `DeviceNotFound` | 10 | ❌ | 未找到设备 (iOS only) |

### 使用 `isRetryable`

```kotlin
// Android
result.onFailure { error ->
    val blueError = error as BlueError
    if (blueError.isRetryable) {
        // 可安全重试（如 timeout、protocolError）
    } else {
        // 需用户干预（如 authFailed、permissionDenied）
        showError(blueError.message, blueError.recoverySuggestion)
    }
}
```

```swift
// iOS
case .failure(let error):
    if error.isRetryable {
        // 可安全重试
    } else {
        showAlert(error.localizedDescription, suggestion: error.recoverySuggestion)
    }
```

---

## 线程模型

| 规则 | 说明 |
|------|------|
| 回调线程 | **所有事件回调在主线程派发**，无需手动切换 |
| API 调用 | 所有公开方法线程安全，可在任意线程调用 |
| 指令队列 | 内部 FIFO 串行，同一时刻只有一条指令等待应答 |
| 指令间隔 | 200ms |
| 指令超时 | 5 秒，自动重试最多 3 次 |

---

## 最佳实践

### 1. 使用 Observer 模式替代单 Listener

```kotlin
// 多个页面可同时监听事件
sdk.addObserver(alarmManagerObserver)
sdk.addObserver(medicationObserver)

// 页面销毁时移除
sdk.removeObserver(alarmManagerObserver)
```

### 2. 认证成功后再发指令

```kotlin
override fun onConnectionStateChanged(state: ConnectionState) {
    if (state == ConnectionState.AUTHENTICATED) {
        // 此时可安全调用业务接口
        sdk.syncTime { }
    }
}
```

### 3. 用药事件处理

```kotlin
// onMedicationResult — 实时事件（无时间戳）
// onMedicationRecordReported — 完整记录（含设定时间 + 实际时间）
// 建议：用 onMedicationRecordReported 入库，用 onMedicationNotification 做 UI 提醒
```

### 4. 时间格式跟随设备

```kotlin
// 读取当前时制
val is24Hour = sdk.currentTimeFormat == TimeFormat.HOUR_24

// 监听切换
override fun onTimeFormatChanged(format: TimeFormat) {
    // 刷新界面时间显示
}
```

### 5. 批量闹钟设置

```kotlin
val alarms = listOf(
    AlarmConfig(1, 8, 0, WeekDays.WEEKDAYS),
    AlarmConfig(2, 12, 30, WeekDays.ALL),
    AlarmConfig(3, 20, 0, WeekDays.WEEKEND)
)
sdk.setAlarms(alarms) { result ->
    // result: Result<List<AlarmInfo>>
}
```

---

## FAQ

### Q: 华为/小米手机扫描不到设备？

Android 6~11 需要**开启位置服务**（系统限制）。Android 12+ 使用 `BLUETOOTH_SCAN` 权限且配置 `neverForLocation` 则无需位置。

### Q: 后台会断连吗？

MIUI/ColorOS 等定制 ROM 可能杀后台蓝牙连接。建议：
1. 引导用户关闭"电池优化"
2. 将 APP 加入自启动白名单
3. iOS 配置 `bluetooth-central` 后台模式

### Q: 认证失败怎么办？

1. 检查 `fixedAuthKey` 是否与设备匹配
2. 设备已被其他手机绑定 → 长按设备按键恢复出厂
3. 恢复后调用 `clearBinding()` 清除本地旧密钥

### Q: 连续发送多条指令会冲突吗？

不会。SDK 内部 `CommandQueue` 自动串行排队：

```kotlin
sdk.setAlarm(1, 8, 0) { }      // 立即发送
sdk.setAlarm(2, 12, 30) { }    // 排队等待
sdk.setSoundType(TYPE_A) { }   // 继续排队
```

### Q: 设备主动上报的数据如何接收？

实现对应的回调方法即可。设备会在以下场景主动上报：
- 认证成功后：上报所有闹钟配置 + 当前音频设置
- 闹钟响铃时：`onMedicationNotification(.ringing)`
- 用户取药时：`onMedicationNotification(.taken)` + `onMedicationRecordReported`
- 超时未取药：`onMedicationNotification(.timeout)`
- 低电量：`onLowBattery()`

### Q: SDK 使用了哪些第三方依赖？

**零依赖**。SDK 仅使用平台原生蓝牙框架（Android BluetoothGatt / iOS CoreBluetooth），不引入任何第三方库。

---

## 隐私声明

本 SDK **不收集、不存储、不上传**任何用户数据：
- 用药记录通过回调传递给 APP，SDK 不做存储
- 设备 MAC 地址仅在内存中用于密钥计算
- 日志中密钥值始终脱敏
- 不包含任何网络请求

---

## 版本

当前版本：1.0.0

两端 SDK 保持同步发版，API 接口一致。
