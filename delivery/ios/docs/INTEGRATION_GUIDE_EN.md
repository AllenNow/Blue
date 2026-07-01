# BlueSDK Integration Guide

LX-PD02 Smart Pill Box Bluetooth Communication SDK — iOS & Android Dual-Platform Integration Document

---

## Table of Contents

- [Overview](#overview)
- [System Requirements](#system-requirements)
- [Integration Steps](#integration-steps)
- [Permission Configuration](#permission-configuration)
- [Initialization](#initialization)
- [Scanning & Connection](#scanning--connection)
- [Authentication Mechanism](#authentication-mechanism)
- [API Reference](#api-reference)
- [Event Callbacks](#event-callbacks)
- [Error Handling](#error-handling)
- [Threading Model](#threading-model)
- [Best Practices](#best-practices)
- [FAQ](#faq)

---

## Overview

BlueSDK fully encapsulates the LX-PD02 proprietary Bluetooth 5.0 communication protocol. Integrators do not need to understand low-level frame structures, CRC verification, key algorithms, or other details. The SDK provides a unified high-level API with highly consistent interface design across both platforms (iOS/Android), reducing cross-platform maintenance costs.

**Core Capabilities:**

| Capability | Description |
|------|------|
| BLE Scanning & Connection | Auto-reconnect (exponential backoff, up to 5 attempts) |
| Key Authentication | Auto-calculated or fixed key, with clear recovery suggestions on auth failure |
| Alarm Management | 7-slot CRUD, supports recurring schedules |
| Medication Events | Real-time reception of ringing/timeout/taken/missed events |
| Medication Records | Device proactively reports complete records with millisecond timestamps |
| Audio System Settings | Volume/ringtone/mute/duration/12H-24H time format |
| Device Management | Device info query/time sync/factory reset/unbind |
| Logging System | Leveled logging, key value masking, export support |

---

## System Requirements

| Platform | Minimum Version | Language | Bluetooth |
|------|---------|------|------|
| Android | API 21 (5.0+) | Kotlin 1.9+ | BLE 5.0+ |
| iOS | 13.0+ | Swift 5.7+ | BLE 5.0+ |

---

## Integration Steps

### Android

**Option A: Local AAR**

```kotlin
// app/build.gradle.kts
dependencies {
    implementation(files("libs/blue-sdk-release.aar"))
}
```

**Option B: Module Dependency (Development Phase)**

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

## Permission Configuration

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

## Initialization

### Android

```kotlin
// Application.onCreate() 中调用一次
val config = BlueSDKConfig(
    fixedAuthKey = null,           // 固定密钥（4位hex），null=自动计算
    logLevel = LogLevel.DEBUG,     // 生产环境用 LogLevel.NONE
    autoAuthEnabled = true,        // 连接成功后自动认证
    autoReconnect = true,          // 断线后自动重连
    maxReconnectAttempts = 5,      // 最大重连次数
    language = BlueSDKLanguage.SYSTEM,  // 多语言：SYSTEM/ZH/EN/DE
    customPhoneMac = null,         // 自定义手机标识（12位hex），null=自动生成
    rawFrameLogEnabled = false     // 是否输出 BLE 收发帧原始数据
)
BlueSDKManager.getInstance(this).initialize(config)
```

### iOS

```swift
// AppDelegate didFinishLaunching 中调用
let config = BlueSDKConfig(
    fixedAuthKey: nil,
    logLevel: .debug,
    autoAuthEnabled: true,
    autoReconnect: true,
    maxReconnectAttempts: 5,
    language: .system,             // 多语言：.system/.zh/.en/.de
    customPhoneMac: nil,
    rawFrameLogEnabled: false      // true 时输出 TX/RX 帧数据
)
BlueSDKManager.shared.initialize(config: config)
```

### Configuration Parameters

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `fixedAuthKey` | String? | null | Fixed authentication key (4-digit hex e.g. "05FA"), null for auto-calculation |
| `logLevel` | LogLevel | DEBUG | Log level: DEBUG/INFO/WARN/ERROR/NONE |
| `autoAuthEnabled` | Boolean | true | Whether to automatically authenticate after connection |
| `autoReconnect` | Boolean | true | Whether to auto-reconnect after unexpected disconnection |
| `maxReconnectAttempts` | Int | 5 | Maximum auto-reconnect attempts |
| `language` | BlueSDKLanguage | SYSTEM | Error description language: SYSTEM/ZH/EN/DE |
| `customPhoneMac` | String? | null | Custom phone identifier (12-digit hex), used for key calculation |
| `rawFrameLogEnabled` | Boolean | false | Whether to output raw BLE frame hex data (for debugging) |

---

## Scanning & Connection

### Android

```kotlin
val sdk = BlueSDKManager.getInstance(context)

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
BlueSDKManager.shared.startScan(timeout: 10) { event in
    switch event {
    case .deviceFound(let device):
        BlueSDKManager.shared.connect(device)
        BlueSDKManager.shared.stopScan()
    case .error(let error):
        print(error.localizedDescription)
    case .stopped:
        break
    }
}
```

---

## Authentication Mechanism

The SDK supports two authentication modes:

| Mode | Configuration | Description |
|------|------|------|
| Auto Authentication | `fixedAuthKey = null` | SDK automatically calculates the key from phone MAC + device MAC |
| Fixed Key | `fixedAuthKey = "05FA"` | Uses a preset 4-digit hex key |

After successful connection, the SDK **automatically initiates authentication** — no manual call required. Authentication results are delivered via callback:

```kotlin
// Android
override fun onAuthResult(success: Boolean, error: BlueError?) { }

// iOS
func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?) { }
```

---

## API Reference

All business APIs must be called after the `AUTHENTICATED` state; otherwise a `NotAuthenticated` error is returned.

### Lifecycle

| API | Android | iOS | Description |
|------|---------|-----|------|
| Initialize | `initialize(config)` | `initialize(config:)` | Called once at Application level |
| Destroy | `destroy()` | `destroy()` | Release BLE resources |

### Connection Management

| API | Android | iOS | Description |
|------|---------|-----|------|
| Scan Devices | `startScan(timeoutMs, callback)` | `startScan(timeout:callback:)` | Unified ScanEvent callback |
| Stop Scan | `stopScan()` | `stopScan()` | |
| Connect Device | `connect(device)` | `connect(device)` | Auto-authenticates after connection |
| Disconnect | `disconnect()` | `disconnect()` | Manual disconnect does not trigger reconnect |
| Cancel Reconnection | `cancelReconnection()` | `cancelReconnection()` | |
| Unbind Device | `clearBinding(completion)` | `clearBinding(completion:)` | Sends unbind command + disconnects |
| Authenticate with Key | `authenticateWithKey(hi, lo, cb)` | `authenticateWithKey(keyHigh:keyLow:completion:)` | |
| Check Permissions | `checkPermissions()` | `checkPermissions()` | Returns PermissionStatus |
| Connection State | `connectionState` (property) | `connectionState` (property) | |
| Current Time Format | `currentTimeFormat` (property) | `currentTimeFormat` (property) | Follows device settings |
| Add Observer | `addObserver(observer)` | `addObserver(_:)` | Multiple pages can listen simultaneously |
| Remove Observer | `removeObserver(observer)` | `removeObserver(_:)` | |
| UUID Direct Connect | — | `connect(byIdentifier:completion:)` | iOS: Quick reconnect for bound devices |
| Switch Language | `setLanguage(language)` | `setLanguage(_:)` | Switch error description language at runtime |
| Key Display | `currentAuthKeyDisplay` (property) | `currentAuthKeyDisplay` (property) | Currently used authentication key |

### Device Info & Time

| API | Android | iOS | Description |
|------|---------|-----|------|
| Query Device Info | `queryDeviceInfo(completion)` | `queryDeviceInfo(completion:)` | MAC + firmware version |
| Time Sync | `syncTime(completion)` | `syncTime(completion:)` | Sends current system time |

### Alarm Management (7 Slots)

| API | Android | iOS | Description |
|------|---------|-----|------|
| Set Alarm | `setAlarm(index, hour, minute, days, cb)` | `setAlarm(index:hour:minute:days:completion:)` | Type-safe version |
| Batch Set | `setAlarms(list, completion)` | `setAlarms(_:completion:)` | Sent serially |
| Query Alarm | `queryAlarm(index, completion)` | `queryAlarm(index:completion:)` | Query single slot |
| Delete Alarm | `deleteAlarm(index, completion)` | `deleteAlarm(index:completion:)` | |
| Clear All | `clearAllAlarms(completion)` | `clearAllAlarms(completion:)` | |

**Parameter Constraints:**
- `index`: 1~7
- `hour`: 0~23
- `minute`: 0~59
- `days`: `WeekDays` enum (`.ALL` / `.WEEKDAYS` / `.WEEKEND` / custom combination)

### Audio & System Settings

| API | Android | iOS | Description |
|------|---------|-----|------|
| Set Volume | `setVolume(level, cb)` | `setVolume(_:completion:)` | LOW / MEDIUM / HIGH |
| Set Ringtone | `setSoundType(type, cb)` | `setSoundType(_:completion:)` | TYPE_A / TYPE_B |
| Set Silence | `setSilence(enabled, cb)` | `setSilence(_:completion:)` | true=mute |
| Alert Duration | `setAlertDuration(minutes, cb)` | `setAlertDuration(_:completion:)` | 1~5 minutes |
| Time Format | `setTimeFormat(format, cb)` | `setTimeFormat(_:completion:)` | HOUR_12 / HOUR_24 |
| Factory Reset | `restoreFactory(completion)` | `restoreFactory(completion:)` | Device restarts and disconnects |

### Medication Events

| API | Android | iOS | Description |
|------|---------|-----|------|
| Send Medication Notification | `sendMedicationNotification(status, cb)` | `sendMedicationNotification(status:completion:)` | |

### Logging

| API | Android | iOS | Description |
|------|---------|-----|------|
| Set Level | `setLogLevel(level)` | `setLogLevel(_:)` | DEBUG/INFO/WARN/ERROR/NONE |
| Custom Handler | `setLogHandler(handler)` | `setLogHandler(_:)` | Integrate with your own logging system |
| Export Log | `exportLog(maxLines)` | `exportLog(maxLines:)` | Last 1000 entries |
| Clear Buffer | `clearLogBuffer()` | `clearLogBuffer()` | |

---

## Event Callbacks

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

> All callback methods have default empty implementations; override only the ones you need.

---

## Error Handling

All asynchronous operations return results via `Result` callbacks — **no exceptions are thrown**.

### Error Types

| Error | Code | Retryable | Description |
|------|------|--------|------|
| `NotInitialized` | 1 | ❌ | initialize() not called |
| `NotAuthenticated` | 2 | ❌ | Key authentication not completed |
| `AuthFailed` | 3 | ❌ | Key mismatch, factory reset required |
| `Timeout` | 4 | ✅ | Command timeout (SDK already retried 3 times internally) |
| `PermissionDenied` | 5 | ❌ | Bluetooth permission not granted |
| `InvalidParameter` | 6 | ❌ | Parameter out of bounds |
| `ProtocolError` | 7 | ✅ | CRC verification failed, possible Bluetooth interference |
| `BleError` | 8 | ✅ | System Bluetooth exception |
| `Disconnected` | 9 | ✅ | Device disconnected, SDK will auto-reconnect |
| `DeviceNotFound` | 10 | ❌ | Device not found (iOS only) |

### Using `isRetryable`

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

## Threading Model

| Rule | Description |
|------|------|
| Callback Thread | **All event callbacks are dispatched on the main thread** — no manual switching needed |
| API Calls | All public methods are thread-safe and can be called from any thread |
| Command Queue | Internal FIFO serial queue — only one command awaits a response at a time |
| Command Interval | 200ms |
| Command Timeout | 5 seconds, auto-retry up to 3 times |

---

## Best Practices

### 1. Use Observer Pattern Instead of Single Listener

```kotlin
// 多个页面可同时监听事件
sdk.addObserver(alarmManagerObserver)
sdk.addObserver(medicationObserver)

// 页面销毁时移除
sdk.removeObserver(alarmManagerObserver)
```

### 2. Send Commands Only After Authentication

```kotlin
override fun onConnectionStateChanged(state: ConnectionState) {
    if (state == ConnectionState.AUTHENTICATED) {
        // 此时可安全调用业务接口
        sdk.syncTime { }
    }
}
```

### 3. Medication Event Handling

```kotlin
// onMedicationResult — 实时事件（无时间戳）
// onMedicationRecordReported — 完整记录（含设定时间 + 实际时间）
// 建议：用 onMedicationRecordReported 入库，用 onMedicationNotification 做 UI 提醒
```

### 4. Time Format Follows Device

```kotlin
// 读取当前时制
val is24Hour = sdk.currentTimeFormat == TimeFormat.HOUR_24

// 监听切换
override fun onTimeFormatChanged(format: TimeFormat) {
    // 刷新界面时间显示
}
```

### 5. Batch Alarm Setting

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

### Q: Cannot find the device on Huawei/Xiaomi phones?

Android 6–11 requires **location services to be enabled** (system restriction). Android 12+ uses the `BLUETOOTH_SCAN` permission with `neverForLocation` configured, so location is not needed.

### Q: Will background mode cause disconnections?

Custom ROMs like MIUI/ColorOS may kill background Bluetooth connections. Recommendations:
1. Guide users to disable "Battery Optimization"
2. Add the app to the auto-start whitelist
3. For iOS, configure `bluetooth-central` background mode

### Q: What to do if authentication fails?

1. Check whether `fixedAuthKey` matches the device
2. Device is already bound to another phone → long-press the device button to factory reset
3. After reset, call `clearBinding()` to clear local old keys

### Q: Will sending multiple commands in succession cause conflicts?

No. The SDK's internal `CommandQueue` automatically serializes commands:

```kotlin
sdk.setAlarm(1, 8, 0) { }      // 立即发送
sdk.setAlarm(2, 12, 30) { }    // 排队等待
sdk.setSoundType(TYPE_A) { }   // 继续排队
```

### Q: How to receive data proactively reported by the device?

Implement the corresponding callback methods. The device proactively reports in the following scenarios:
- After successful authentication: reports all alarm configurations + current audio settings
- When alarm rings: `onMedicationNotification(.ringing)`
- When user takes medication: `onMedicationNotification(.taken)` + `onMedicationRecordReported`
- Timeout without taking medication: `onMedicationNotification(.timeout)`
- Low battery: `onLowBattery()`

### Q: What third-party dependencies does the SDK use?

**Zero dependencies**. The SDK only uses platform-native Bluetooth frameworks (Android BluetoothGatt / iOS CoreBluetooth) and does not introduce any third-party libraries.

---

## Privacy Statement

This SDK **does not collect, store, or upload** any user data:
- Medication records are passed to the app via callbacks; the SDK does not store them
- Device MAC addresses are only used in memory for key calculation
- Key values are always masked in logs
- No network requests are included

---

## Version

Current version: 1.0.0

Both platform SDKs are released in sync with consistent API interfaces.
