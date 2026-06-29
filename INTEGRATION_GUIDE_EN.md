# BlueSDK Integration Guide

LX-PD02 Smart Pill Box Bluetooth Communication SDK — iOS & Android Dual-Platform Integration Documentation

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
- [Event Callbacks Reference](#event-callbacks-reference)
- [Error Handling](#error-handling)
- [Threading Model](#threading-model)
- [Best Practices](#best-practices)
- [FAQ](#faq)

---

## Overview

BlueSDK fully encapsulates the LX-PD02 proprietary Bluetooth 5.0 communication protocol. Integrators do not need to understand the underlying frame structure, CRC verification, key algorithms, or other low-level details. The SDK provides a unified high-level API with highly consistent interface design across both platforms (iOS/Android), reducing cross-platform maintenance costs.

**Core Capabilities:**

| Capability | Description |
|------|------|
| BLE Scanning & Connection | Auto-reconnect (exponential backoff, up to 5 attempts) |
| Key Authentication | Automatic calculation or fixed key, with clear recovery suggestions on auth failure |
| Alarm Management | 7-slot CRUD, supports recurring schedules |
| Medication Events | Real-time reception of ringing/timeout/taken/missed events |
| Medication Records | Device proactively reports complete records with millisecond timestamps |
| Audio System Settings | Volume/ringtone/mute/duration/12H-24H time format |
| Device Management | Device info query/time sync/factory reset/unbind |
| Logging System | Leveled logging, key value masking, supports export |

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
<string>Bluetooth permission is required to connect to the smart pill box device</string>

<!-- Optional: Receive medication events in background -->
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

---

## Initialization

### Android

```kotlin
// Call once in Application.onCreate()
val config = BlueSDKConfig(
    fixedAuthKey = null,        // Fixed key (4-digit hex), null = auto-calculate
    logLevel = LogLevel.DEBUG,  // Use LogLevel.NONE in production
    autoAuthEnabled = true      // Auto-authenticate after connection
)
BlueSDK.getInstance(this).initialize(config)
```

### iOS

```swift
// Call in AppDelegate didFinishLaunching
let config = BlueSDKConfig(
    fixedAuthKey: nil,
    logLevel: .debug,
    autoAuthEnabled: true
)
BlueSDK.shared.initialize(config: config)
```

---

## Scanning & Connection

### Android

```kotlin
val sdk = BlueSDK.getInstance(context)

sdk.startScan(timeoutMs = 10000L) { event ->
    when (event) {
        is ScanEvent.DeviceFound -> {
            // event.device contains deviceId, deviceName, rssi
            sdk.connect(event.device)  // SDK auto-completes authentication
            sdk.stopScan()
        }
        is ScanEvent.Error -> { /* error.message */ }
        is ScanEvent.Stopped -> { /* Timeout or manually stopped */ }
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

## Authentication Mechanism

The SDK supports two authentication modes:

| Mode | Configuration | Description |
|------|------|------|
| Auto Authentication | `fixedAuthKey = null` | SDK automatically calculates key based on phone MAC + device MAC |
| Fixed Key | `fixedAuthKey = "05FA"` | Uses a preset 4-digit hex key |

After a successful connection, the SDK **automatically initiates authentication** — no manual call is needed. Authentication results are delivered via callbacks:

```kotlin
// Android
override fun onAuthResult(success: Boolean, error: BlueError?) { }

// iOS
func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?) { }
```

---

## API Reference

All business APIs must be called after reaching the `AUTHENTICATED` state; otherwise, a `NotAuthenticated` error is returned.

### Lifecycle

| API | Android | iOS | Description |
|------|---------|-----|------|
| Initialize | `initialize(config)` | `initialize(config:)` | Call once at the Application level |
| Destroy | `destroy()` | `destroy()` | Release BLE resources |

### Connection Management

| API | Android | iOS | Description |
|------|---------|-----|------|
| Scan Devices | `startScan(timeoutMs, callback)` | `startScan(timeout:callback:)` | Unified ScanEvent callback |
| Stop Scan | `stopScan()` | `stopScan()` | |
| Connect Device | `connect(device)` | `connect(device)` | Auto-authenticates after connection |
| Disconnect | `disconnect()` | `disconnect()` | Manual disconnect does not trigger reconnection |
| Cancel Reconnection | `cancelReconnection()` | `cancelReconnection()` | |
| Unbind Device | `clearBinding(completion)` | `clearBinding(completion:)` | Sends unbind command + disconnects |
| Authenticate with Key | `authenticateWithKey(hi, lo, cb)` | `authenticateWithKey(keyHigh:keyLow:completion:)` | |
| Check Permissions | `checkPermissions()` | `checkPermissions()` | Returns PermissionStatus |
| Connection State | `connectionState` (property) | `connectionState` (property) | |
| Current Time Format | `currentTimeFormat` (property) | `currentTimeFormat` (property) | Follows device setting |

### Device Info & Time

| API | Android | iOS | Description |
|------|---------|-----|------|
| Query Device Info | `queryDeviceInfo(completion)` | `queryDeviceInfo(completion:)` | MAC + firmware version |
| Time Sync | `syncTime(completion)` | `syncTime(completion:)` | Sends current system time to device |

### Alarm Management (7 Slots)

| API | Android | iOS | Description |
|------|---------|-----|------|
| Set Alarm | `setAlarm(index, hour, minute, days, cb)` | `setAlarm(index:hour:minute:days:completion:)` | Type-safe version |
| Batch Set | `setAlarms(list, completion)` | `setAlarms(_:completion:)` | Sends serially |
| Query Alarm | `queryAlarm(index, completion)` | `queryAlarm(index:completion:)` | Query a single slot |
| Delete Alarm | `deleteAlarm(index, completion)` | `deleteAlarm(index:completion:)` | |
| Clear All | `clearAllAlarms(completion)` | `clearAllAlarms(completion:)` | |

**Parameter Constraints:**
- `index`: 1–7
- `hour`: 0–23
- `minute`: 0–59
- `days`: `WeekDays` enum (`.ALL` / `.WEEKDAYS` / `.WEEKEND` / custom combination)

### Audio & System Settings

| API | Android | iOS | Description |
|------|---------|-----|------|
| Set Volume | `setVolume(level, cb)` | `setVolume(_:completion:)` | LOW / MEDIUM / HIGH |
| Set Ringtone | `setSoundType(type, cb)` | `setSoundType(_:completion:)` | TYPE_A / TYPE_B |
| Set Mute | `setSilence(enabled, cb)` | `setSilence(_:completion:)` | true = muted |
| Alert Duration | `setAlertDuration(minutes, cb)` | `setAlertDuration(_:completion:)` | 1–5 minutes |
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

## Event Callbacks Reference

### Android — `BlueSDKListener` interface

```kotlin
interface BlueSDKListener {
    // Connection
    fun onConnectionStateChanged(state: ConnectionState) {}
    fun onAuthResult(success: Boolean, error: BlueError?) {}
    fun onReconnecting(attempt: Int, maxAttempts: Int) {}
    fun onReconnectFailed() {}
    fun onError(error: BlueError) {}

    // Device
    fun onDeviceInfoReceived(info: DeviceInfo) {}
    fun onTimeSyncRequested() {}

    // Alarm
    fun onAlarmUpdated(alarm: AlarmInfo) {}
    fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) {}
    fun onAlarmTimeout(alarmIndex: Int, alarmInfo: AlarmInfo) {}

    // Medication
    fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {}
    fun onMedicationRecordReported(record: MedicationRecord) {}
    fun onMedicationNotification(type: MedicationNotificationType) {}

    // System Settings
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
    // Connection
    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState)
    func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?)
    func blueSDK(_ sdk: BlueSDK, didStartReconnecting attempt: Int, maxAttempts: Int)
    func blueSDKDidFailReconnection(_ sdk: BlueSDK)
    func blueSDK(_ sdk: BlueSDK, didEncounterError error: BlueError)

    // Device
    func blueSDK(_ sdk: BlueSDK, didReceiveDeviceInfo info: DeviceInfo)
    func blueSDKDidRequestTimeSync(_ sdk: BlueSDK)

    // Alarm
    func blueSDK(_ sdk: BlueSDK, didUpdateAlarm alarm: AlarmInfo)
    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo)
    func blueSDK(_ sdk: BlueSDK, didAlarmTimeout alarmIndex: Int, alarmInfo: AlarmInfo)

    // Medication
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus)
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationRecord record: MedicationRecord)
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationNotification type: MedicationNotificationType)

    // System Settings
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
| `NotInitialized` | 1 | ❌ | initialize() was not called |
| `NotAuthenticated` | 2 | ❌ | Key authentication not completed |
| `AuthFailed` | 3 | ❌ | Key mismatch, factory reset required |
| `Timeout` | 4 | ✅ | Command timed out (SDK already retried internally 3 times) |
| `PermissionDenied` | 5 | ❌ | Bluetooth permission not granted |
| `InvalidParameter` | 6 | ❌ | Parameter out of range |
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
        // Safe to retry (e.g., timeout, protocolError)
    } else {
        // Requires user intervention (e.g., authFailed, permissionDenied)
        showError(blueError.message, blueError.recoverySuggestion)
    }
}
```

```swift
// iOS
case .failure(let error):
    if error.isRetryable {
        // Safe to retry
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
| Command Timeout | 5 seconds, auto-retries up to 3 times |

---

## Best Practices

### 1. Use the Observer Pattern Instead of a Single Listener

```kotlin
// Multiple screens can listen for events simultaneously
sdk.addObserver(alarmManagerObserver)
sdk.addObserver(medicationObserver)

// Remove when the screen is destroyed
sdk.removeObserver(alarmManagerObserver)
```

### 2. Only Send Commands After Successful Authentication

```kotlin
override fun onConnectionStateChanged(state: ConnectionState) {
    if (state == ConnectionState.AUTHENTICATED) {
        // Now it's safe to call business APIs
        sdk.syncTime { }
    }
}
```

### 3. Medication Event Handling

```kotlin
// onMedicationResult — Real-time event (no timestamp)
// onMedicationRecordReported — Complete record (includes scheduled time + actual time)
// Recommendation: Use onMedicationRecordReported for database storage,
//                 use onMedicationNotification for UI alerts
```

### 4. Time Format Follows Device

```kotlin
// Read current time format
val is24Hour = sdk.currentTimeFormat == TimeFormat.HOUR_24

// Listen for changes
override fun onTimeFormatChanged(format: TimeFormat) {
    // Refresh the time display in UI
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

### Q: Device not found on Huawei/Xiaomi phones?

On Android 6–11, **Location Services must be enabled** (system restriction). On Android 12+, using the `BLUETOOTH_SCAN` permission with `neverForLocation` configured eliminates the location requirement.

### Q: Will the connection drop in the background?

Custom ROMs such as MIUI/ColorOS may kill background Bluetooth connections. Recommendations:
1. Guide the user to disable "Battery Optimization"
2. Add the app to the auto-start whitelist
3. On iOS, configure the `bluetooth-central` background mode

### Q: What to do when authentication fails?

1. Verify that `fixedAuthKey` matches the device
2. If the device is already bound to another phone → long-press the device button to factory reset
3. After reset, call `clearBinding()` to clear the local stale key

### Q: Will sending multiple commands in succession cause conflicts?

No. The SDK's internal `CommandQueue` automatically serializes commands:

```kotlin
sdk.setAlarm(1, 8, 0) { }      // Sent immediately
sdk.setAlarm(2, 12, 30) { }    // Queued
sdk.setSoundType(TYPE_A) { }   // Queued
```

### Q: How do I receive data proactively reported by the device?

Implement the corresponding callback methods. The device proactively reports data in the following scenarios:
- After successful authentication: reports all alarm configurations + current audio settings
- When an alarm rings: `onMedicationNotification(.ringing)`
- When the user takes medication: `onMedicationNotification(.taken)` + `onMedicationRecordReported`
- When medication is not taken before timeout: `onMedicationNotification(.timeout)`
- Low battery: `onLowBattery()`

### Q: What third-party dependencies does the SDK use?

**Zero dependencies.** The SDK only uses the platform's native Bluetooth frameworks (Android BluetoothGatt / iOS CoreBluetooth) and does not introduce any third-party libraries.

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
