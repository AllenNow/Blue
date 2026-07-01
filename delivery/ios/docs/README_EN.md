# BlueSDK - iOS

LX-PD02 Smart Pill Box Bluetooth Communication SDK (iOS Native)

[![Platform](https://img.shields.io/badge/platform-iOS%2013.0%2B-blue)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.7%2B-orange)](https://swift.org)
[![Bluetooth](https://img.shields.io/badge/Bluetooth-5.0%2B-blue)](https://www.bluetooth.com)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## Introduction

BlueSDK fully encapsulates the LX-PD02 proprietary Bluetooth 5.0 communication protocol and provides a clean, type-safe high-level API. Third-party developers can quickly build mobile applications with complete medication reminder capabilities without needing to understand low-level frame structures, CRC verification, key authentication, or other protocol details.

**Core Capabilities:**
- 🔵 BLE device scanning and connection (automatic reconnection with exponential backoff)
- 🔐 Key authentication (phone MAC + device MAC accumulation algorithm)
- ⏰ Alarm management (7 slots)
- 💊 Medication event reception (ringing/timeout/pill taken/missed dose)
- 📋 Medication record reporting (with millisecond timestamps)
- 🔊 Audio and system settings
- 📝 Tiered logging (key value redaction)

---

## System Requirements

- iOS 13.0+
- Swift 5.7+
- Xcode 14.0+
- Device Bluetooth must support Bluetooth 5.0+

---

## Integration

### CocoaPods (Recommended)

```ruby
platform :ios, '13.0'
use_frameworks!

target 'YourApp' do
  pod 'BlueSDK', :path => '../blue-sdk-ios/BlueSDK'
end
```

```bash
pod install
```

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(path: "../blue-sdk-ios")
]
```

---

## Permission Configuration

Add the following to `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Bluetooth permission is required to connect to the LX-PD02 smart pill box device for setting medication reminders and receiving medication notifications.</string>
```

To receive medication events in the background (recommended):

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

---

## Quick Start

### 1. Initialization

```swift
// AppDelegate.swift
import BlueSDK

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    BlueSDK.shared.initialize()
    BlueSDK.shared.setLogLevel(.debug) // Development phase
    return true
}

func applicationWillTerminate(_ application: UIApplication) {
    BlueSDK.shared.destroy()
}
```

### 2. Register Event Listener

```swift
class MyViewController: UIViewController, BlueSDKDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        BlueSDK.shared.delegate = self
    }

    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState) {
        print("Connection state: \(state)")
    }

    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo) {
        print("Alarm \(alarmIndex) ringing: \(alarmInfo.hour):\(alarmInfo.minute)")
        // Push local notification
    }

    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus) {
        print("Medication result: \(status)")
    }

    // Automatically respond to time sync requests
    func blueSDKDidRequestTimeSync(_ sdk: BlueSDK) {
        sdk.syncTime { _ in }
    }
}
```

### 3. Scan and Connect Device

```swift
// Check permissions
let status = BlueSDK.shared.checkPermissions()
guard status == .granted else { /* Request permissions */ return }

// Scan for devices
BlueSDK.shared.startScan(
    onDeviceFound: { device in
        print("Found: \(device.deviceName), Signal: \(device.rssi) dBm")
        BlueSDK.shared.connect(device)
        BlueSDK.shared.stopScan()
    },
    onError: { error in
        print("Scan error: \(error.localizedDescription)")
    }
)
```

### 4. Authentication

```swift
// phoneMac and deviceMac are each 6 bytes
BlueSDK.shared.authenticate(phoneMac: phoneMac, deviceMac: deviceMac) { result in
    switch result {
    case .success:
        print("Authentication successful, business commands can now be executed")
    case .failure(let error):
        print("Authentication failed: \(error.localizedDescription)")
    }
}
```

### 5. Set Alarm

```swift
// Set Alarm 1: Daily at 08:00
BlueSDK.shared.setAlarm(index: 1, hour: 8, minute: 0, weekMask: 0x7F) { result in
    switch result {
    case .success(let alarm):
        print("Alarm \(alarm.index) set successfully")
    case .failure(let error):
        print("Setup failed: \(error.localizedDescription)")
    }
}
```

---

## Error Handling

```swift
switch error {
case .notInitialized:    // initialize() not called
case .notAuthenticated:  // Authentication not completed
case .authFailed:        // Key mismatch
case .timeout:           // Command timeout (5 seconds, auto-retry 3 times)
case .permissionDenied:  // Bluetooth permission not granted
case .invalidParameter:  // Invalid parameter (e.g., alarm index outside 1~7)
case .disconnected:      // Device disconnected
case .bleError:          // System BLE error
}
```

---

## Log Configuration

```swift
// Development phase
BlueSDK.shared.setLogLevel(.debug)

// Intercept logs (integrate with your own logging system)
BlueSDK.shared.setLogHandler { level, tag, message in
    MyLogger.log("[\(level)][\(tag)] \(message)")
}

// Disable in production
BlueSDK.shared.setLogLevel(.none)
```

> ⚠️ Key values are never output in plaintext at any log level.

---

## Privacy Statement

This SDK **does not collect, store, or upload** any user data:
- Medication records are passed to the app via callbacks; the SDK does not store them
- Device MAC addresses are only used in memory for key calculation and are not persisted
- No network requests are included

See [Privacy Policy](../../docs/BLE-888/implementation-artifacts/docs/privacy-policy.md) for details.

---

## Documentation

| Document | Description |
|----------|-------------|
| [API Reference](../../docs/BLE-888/implementation-artifacts/docs/api-reference.md) | Complete API listing |
| [Protocol Reference](../../docs/BLE-888/implementation-artifacts/docs/protocol-reference.md) | Frame format, DPID, CRC8 |
| [Permission Manifest](../../docs/BLE-888/implementation-artifacts/docs/permission-manifest.md) | Permission configuration and compliance |
| [Troubleshooting](../../docs/BLE-888/implementation-artifacts/docs/troubleshooting.md) | Common issue resolution |
| [Compatibility Matrix](compatibility-matrix.md) | Device and system compatibility |
| [Changelog](../../CHANGELOG.md) | Version history |

---

## Known Issues

- BLE GATT UUID uses generic serial service placeholder; pending confirmation from hardware team
- Time sync frame format pending confirmation from hardware team

---

## License

MIT License
