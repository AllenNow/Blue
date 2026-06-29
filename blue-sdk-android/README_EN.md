# BlueSDK Android

LX-PD02 Smart Pill Box Bluetooth Communication SDK (Android Native Kotlin)

## System Requirements

- Android 5.0+ (API 21+)
- Kotlin 1.9+
- Bluetooth 5.0+ hardware

## Integration

### Local AAR (Recommended)

Place `blue-sdk-release.aar` in the `app/libs/` directory and add to `build.gradle.kts`:

```kotlin
dependencies {
    implementation(files("libs/blue-sdk-release.aar"))
}
```

### Local Module Dependency (Development Phase)

```kotlin
// settings.gradle.kts
include(":blue-sdk")

// app/build.gradle.kts
dependencies {
    implementation(project(":blue-sdk"))
}
```

## Quick Start

### 1. Permission Configuration

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<!-- Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>
```

### 2. Initialize the SDK

```kotlin
// Call once in Application.onCreate()
val config = BlueSDKConfig(
    fixedAuthKey = null,        // Fixed key, null for automatic calculation
    logLevel = LogLevel.DEBUG,  // Log level
    autoAuthEnabled = true      // Auto-authenticate after connection
)
BlueSDK.getInstance(this).initialize(config)
```

### 3. Scan and Connect to a Device

```kotlin
val sdk = BlueSDK.getInstance(context)
sdk.listener = myListener

// Scan (auto-stops after 10 seconds)
sdk.startScan(timeoutMs = 10000L) { event ->
    when (event) {
        is ScanEvent.DeviceFound -> {
            sdk.connect(event.device)  // SDK auto-completes key authentication after connection
            sdk.stopScan()
        }
        is ScanEvent.Error -> { /* Handle error */ }
        is ScanEvent.Stopped -> { /* Scan timed out */ }
    }
}
```

### 4. Listen for Event Callbacks

```kotlin
sdk.listener = object : BlueSDKListener {
    override fun onConnectionStateChanged(state: ConnectionState) {
        // DISCONNECTED → CONNECTING → CONNECTED → AUTHENTICATED
    }
    override fun onAuthResult(success: Boolean, error: BlueError?) {
        if (success) { /* Ready to send business commands */ }
    }
    override fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) {
        // Device alarm is ringing
    }
    override fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {
        // Medication result (on-time / timeout / missed / early)
    }
}
```

### 5. Send Business Commands

```kotlin
// All business commands must be called after AUTHENTICATED state

// Set alarm (type-safe)
sdk.setAlarm(index = 1, hour = 8, minute = 0, days = WeekDays.WEEKDAYS) { result ->
    result.fold(
        onSuccess = { alarmInfo -> /* Success */ },
        onFailure = { error -> /* Handle error */ }
    )
}

// Batch set alarms
sdk.setAlarms(listOf(
    AlarmConfig(index = 1, hour = 8, minute = 0, days = WeekDays.WEEKDAYS),
    AlarmConfig(index = 2, hour = 12, minute = 30, days = WeekDays.ALL),
    AlarmConfig(index = 3, hour = 20, minute = 0, days = WeekDays.WEEKEND)
)) { result -> }

// Audio settings
sdk.setSoundType(SoundType.TYPE_A) { }
sdk.setVolume(VolumeLevel.MEDIUM) { }
sdk.setTimeFormat(TimeFormat.HOUR_24) { }
sdk.setSilence(true) { }
sdk.setAlertDuration(5) { }  // 5 minutes

// Device control
sdk.syncTime { }
sdk.queryDeviceInfo { result -> }
sdk.restoreFactory { }
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                  Integrator App                       │
├─────────────────────────────────────────────────────┤
│  BlueSDK (Public API Entry Point)                    │
│  ├── BlueSDKConfig        Configuration             │
│  ├── BlueSDKListener      Event Callbacks           │
│  └── BlueError            Error Types               │
├─────────────────────────────────────────────────────┤
│  Manager Layer (Business Logic)                      │
│  ├── AuthManager          Key Authentication        │
│  ├── AlarmManager         Alarm Management (7 slots)│
│  ├── MedicationManager    Medication Events         │
│  ├── AudioManager         Audio/System Settings     │
│  ├── DeviceManager        Device Info/Time Sync     │
│  ├── ConnectionManager    Connection State Machine  │
│  └── PermissionManager    Permission Checks         │
├─────────────────────────────────────────────────────┤
│  Internal Layer (Infrastructure)                     │
│  ├── CommandQueue         FIFO Serial Command Queue │
│  ├── CallbackDispatcher   Main Thread Dispatching   │
│  ├── BlueLogger           Leveled Logging + Redact  │
│  ├── KeystoreHelper       phoneMac Persistence      │
│  └── LogFormatter         Log Formatting            │
├─────────────────────────────────────────────────────┤
│  Transport Layer (Protocol Communication)            │
│  ├── BLEScanner           Device Scanning           │
│  ├── BLEConnector         GATT Connection/R&W       │
│  ├── FrameBuilder         Frame Building (55 AA…CRC8)│
│  ├── FrameParser          Frame Parsing + CRC Check │
│  ├── StreamFrameParser    Packet Reassembly         │
│  ├── CRC8Calculator       Checksum Algorithm        │
│  ├── CommandCode          CMD Command Constants     │
│  ├── DPIDConstants        DPID Function Byte Consts │
│  └── FrameConstants       Frame Format Constants    │
└─────────────────────────────────────────────────────┘
                        ↕ BLE
┌─────────────────────────────────────────────────────┐
│            LX-PD02 Smart Pill Box Hardware           │
└─────────────────────────────────────────────────────┘
```

## Connection State Machine

```
                    connect()
 DISCONNECTED ──────────────────→ CONNECTING
      ↑                                │
      │ disconnect()                   │ GATT connection success
      │ Reconnect failed (5 attempts)  ↓
      ←──────────────────────── CONNECTED
      ↑                                │
      │                                │ Auto key authentication
      │     Unexpected disconnect      ↓
 RECONNECTING ←──────────────── AUTHENTICATED
      │                                │
      │   2s/4s/8s exponential backoff │ disconnect()
      └────────→ CONNECTING ←──────────┘ (no reconnect triggered)
```

**State Descriptions:**
- `DISCONNECTED` — Initial state, `connect()` can be called
- `CONNECTING` — Establishing GATT connection (15-second timeout)
- `CONNECTED` — GATT ready, SDK automatically initiates authentication
- `AUTHENTICATED` — Authentication passed, all business commands can be executed
- `RECONNECTING` — Auto-reconnecting after unexpected disconnect (max 5 attempts)

## Threading Model

- **All `BlueSDKListener` callbacks are dispatched on the main thread** — integrators do not need to switch threads manually
- **`completion` callbacks from API methods may be triggered on the BLE thread** — use `runOnUiThread` if UI operations are needed
- Internal BLE operations run on the system Bluetooth thread
- `CommandQueue` ensures only one command awaits a response at any time (FIFO serial)
- 200ms interval between commands, 5-second timeout with auto-retry, max 3 retries
- The SDK itself is thread-safe; all public methods can be called from any thread

## Public API Reference

### Lifecycle

| Method | Description |
|--------|-------------|
| `initialize(config)` | Initialize the SDK (call once in Application) |
| `destroy()` | Release all BLE resources |

### Connection Management

| Method | Description |
|--------|-------------|
| `startScan(timeoutMs, callback)` | Scan for BLE devices (unified ScanEvent callback) |
| `stopScan()` | Stop scanning |
| `connect(device)` | Connect to a device (auto-authenticates) |
| `disconnect()` | Disconnect manually (does not trigger reconnection) |
| `cancelReconnection()` | Cancel automatic reconnection |
| `clearBinding()` | Clear local binding key |
| `authenticateWithKey(high, low)` | Authenticate with a specified key |
| `checkPermissions()` | Query Bluetooth permission status |
| `connectionState` | Current connection state (property) |

### Device Information

| Method | Description | Precondition |
|--------|-------------|--------------|
| `queryDeviceInfo(completion)` | Query MAC + firmware version | Initialized |
| `syncTime(completion)` | Send system time to device | Authenticated |

### Alarm Management

| Method | Description | Precondition |
|--------|-------------|--------------|
| `setAlarm(index, hour, minute, days, completion)` | Set alarm (1–7) | Authenticated |
| `setAlarms(list, completion)` | Batch set alarms | Authenticated |
| `deleteAlarm(index, completion)` | Delete an alarm | Authenticated |
| `clearAllAlarms(completion)` | Clear all alarms | Authenticated |

### Audio & System

| Method | Description | Precondition |
|--------|-------------|--------------|
| `setVolume(level, completion)` | Volume (LOW/MEDIUM/HIGH) | Authenticated |
| `setSoundType(type, completion)` | Ringtone (TYPE_A/B/C/MUTE) | Authenticated |
| `setSilence(enabled, completion)` | Mute toggle | Authenticated |
| `setAlertDuration(minutes, completion)` | Alert duration | Authenticated |
| `setTimeFormat(format, completion)` | Time format (HOUR_12/HOUR_24) | Authenticated |
| `restoreFactory(completion)` | Factory reset | Authenticated |

### Medication Events

| Method | Description | Precondition |
|--------|-------------|--------------|
| `sendMedicationNotification(status, completion)` | Send medication result notification | Authenticated |

### Logging

| Method | Description |
|--------|-------------|
| `setLogLevel(level)` | Set log level |
| `setLogHandler(handler)` | Custom log handler |
| `exportLog(maxLines)` | Export recent logs (max 1000 entries) |
| `clearLogBuffer()` | Clear log buffer |

## Error Handling

All asynchronous operations return results via `Result<T>` callbacks; no exceptions are thrown.

```kotlin
sdk.setAlarm(1, 8, 0) { result ->
    result.fold(
        onSuccess = { info -> /* Success */ },
        onFailure = { error ->
            val blueError = error as BlueError
            Log.e("SDK", "${blueError.message} | Suggestion: ${blueError.recoverySuggestion}")
        }
    )
}
```

### Error Types

| Error | Code | Description | Recovery Suggestion |
|-------|------|-------------|---------------------|
| `NotInitialized` | 1 | SDK not initialized | Call `initialize()` first |
| `NotAuthenticated` | 2 | Authentication not completed | Wait for auto-authentication or check key configuration |
| `AuthFailed` | 3 | Key mismatch | Check fixedAuthKey or factory-reset the device |
| `Timeout` | 4 | Command timeout (5s × 3 retries) | Ensure device is within 3 meters with sufficient battery |
| `PermissionDenied` | 5 | Bluetooth permission not granted | Android 12+ requires BLUETOOTH_SCAN + CONNECT |
| `InvalidParameter` | 6 | Invalid parameter | Check alarm index 1–7, hour 0–23, minute 0–59 |
| `ProtocolError` | 7 | Frame CRC check failed | Possible Bluetooth interference; disconnect and reconnect |
| `BleError` | 8 | System Bluetooth error | Confirm Bluetooth is enabled; try restarting Bluetooth |
| `Disconnected` | 9 | Connection lost | SDK will auto-reconnect, or manually call connect() |

## FAQ

### Huawei phones cannot find the device during scan

Android 6–11 requires **Location Services to be enabled** for BLE scanning (this is a system limitation, not an SDK issue). Prompt the user to enable GPS before scanning.

### Xiaomi phones disconnect in background

MIUI's "Battery Saver" may kill background Bluetooth connections. Solutions:
1. Allow the app in "AutoStart Management"
2. Disable "Battery Saver" for the app in "Battery & Performance"
3. Lock the app in the recent tasks list

### Authentication failure troubleshooting

1. Check if `BlueSDKConfig.fixedAuthKey` is correct (4-digit hexadecimal, e.g., "05FA")
2. If the device is already bound to another phone, **long-press the device button to factory reset**
3. After reset, call `clearBinding()` in the app to clear the old local key

### How to send multiple commands

The SDK's internal `CommandQueue` automatically serializes commands. Integrators can call multiple commands consecutively without waiting for each to complete:

```kotlin
sdk.setAlarm(1, 8, 0) { }
sdk.setAlarm(2, 12, 30) { }   // Automatically queued, sent after the first completes
sdk.setSoundType(SoundType.TYPE_A) { }  // Continues queuing
```

### Device-initiated time sync request

The device may actively request a time sync (e.g., after a power loss restart). The SDK handles this automatically (30-second throttle), requiring no action from integrators. To be notified of this event, implement the `onTimeSyncRequested()` callback.

## Protocol Reference

### Frame Format

```
[0x55][0xAA][Version=0x00][CMD][LenHigh][LenLow][Data...][CRC8]
```

- **CRC8**: Sum all bytes from the first byte to the last data byte, modulo 256
- **Minimum frame**: 7 bytes (Len=0x0000 when no data)

### CMD Command Codes

| CMD | Direction | Purpose |
|-----|-----------|---------|
| 0x00 | APP→Device | Key authentication |
| 0x01 | APP→Device | Query device info |
| 0x06 | APP→Device | Send configuration commands |
| 0x07 | Device→APP | Device active report |
| 0xE1 | Bidirectional | Time sync |

### DPID Function Bytes

| DPID | Purpose | Data Format |
|------|---------|-------------|
| 0x65 | Medication record report | 15 bytes (Alarm DP + YMDHm + Status) |
| 0x66~0x6C | Alarm 1–7 | `XX 00 00 07 01 HH MM WW 00 00 00` |
| 0x6D | Sound type report | Device→APP (1=A, 2=B) |
| 0x6E | Volume/Duration | type=04 volume / type=02 duration |
| 0x6F | Ringtone setting | `6F 04 00 01 XX` (01=A/02=B/03=C) |
| 0x70 | Clear alarms | `70 01 00 01 01` |
| 0x73 | Time format | `73 04 00 01 XX` (00=12H/01=24H) |
| 0x74 | Mute | `74 04 00 01 XX` (00=off/01=on) |
| 0x75 | Low battery report | Device→APP (report only) |
| 0x71 | Factory reset | `71 01 00 01 01` |

## Project Structure

```
blue-sdk-android/
├── blue-sdk/                    # SDK Library Module
│   └── src/main/kotlin/com/blue/sdk/
│       ├── BlueSDK.kt           # Public API Entry (Singleton)
│       ├── BlueSDKConfig.kt     # Initialization Config
│       ├── BlueSDKListener.kt   # Event Callback Interface
│       ├── enums/               # Enum Types
│       ├── error/               # BlueError
│       ├── internal/            # Internal Components
│       ├── manager/             # Business Managers
│       ├── model/               # Data Models
│       └── transport/           # BLE Transport Protocol Layer
└── app/                         # Demo App
    └── src/main/kotlin/com/blue/demo/
        ├── MainActivity.kt              # Main Console
        ├── AlarmManagerActivity.kt      # Alarm Management (7-slot editor)
        ├── MedicationRecordsActivity.kt # Medication Records (Calendar+SQLite)
        ├── ProtocolTestActivity.kt      # Protocol Automated Tests (15 cases)
        ├── MedicationDatabase.kt        # SQLite Persistence
        └── DemoApplication.kt           # SDK Initialization
```

## Demo App

The demo app demonstrates all SDK features and serves as an integration reference:

- **Home**: Scan & connect + full command panel + real-time log
- **Alarm Management**: 7-slot list, TimePicker for time setting, multi-select weekdays
- **Medication Records**: DatePicker for date-based queries, SQLite persistence, supports all/daily view
- **Protocol Testing**: 15 test cases with automated execution, real-time frame send/receive log

Running the Demo:
```bash
# Open the blue-sdk-android/ directory in Android Studio
# Select the app module → Connect a physical device → Run
```

> ⚠️ BLE is not supported on emulators; a physical device with Bluetooth 5.0 is required for testing

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

## License

MIT
