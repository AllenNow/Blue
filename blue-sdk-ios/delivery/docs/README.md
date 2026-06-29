# BlueSDK iOS 集成指南

LX-PD02 智能药盒蓝牙通信 SDK（iOS 原生 Swift）

## 系统要求

- iOS 13.0+
- Swift 5.7+ / Xcode 14+
- Bluetooth 5.0+ 硬件

## 集成方式

### Swift Package Manager

```
File → Add Package Dependencies → 输入仓库地址
```

### CocoaPods

```ruby
pod 'BlueSDK', '~> 0.2.0'
```

### XCFramework（手动集成）

将 `BlueSDK.xcframework` 拖入项目 → Embed & Sign。

## 权限配置

Info.plist 中添加：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限以连接智能药盒设备</string>
```

## 快速开始

### 1. 初始化

```swift
// AppDelegate 中调用一次
BlueSDK.shared.initialize(config: BlueSDKConfig(logLevel: .debug))
BlueSDK.shared.delegate = self
```

### 2. 扫描连接

```swift
BlueSDK.shared.startScan(timeout: 10) { event in
    switch event {
    case .deviceFound(let device):
        BlueSDK.shared.connect(device)
        BlueSDK.shared.stopScan()
    case .error(let error):
        print("扫描错误：\(error)")
    case .stopped:
        print("扫描超时")
    }
}
```

### 3. 连接流程（SDK 自动完成）

连接设备后，SDK 内部自动执行以下步骤，无需集成方干预：

```
扫描发现设备
    ↓
建立 BLE 连接（15秒超时）
    ↓
GATT 服务发现 + Notify 订阅
    ↓
自动密钥认证（计算+发送+验证）
    ↓
认证成功 → 状态变为 AUTHENTICATED
    ↓
自动同步系统时间到设备
    ↓
可以发送业务指令
```

集成方只需关注 `didChangeConnectionState` 和 `didAuthenticateWithSuccess` 回调。

### 4. 监听事件

```swift
extension ViewController: BlueSDKDelegate {
    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState) { }
    func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?) { }
    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo) { }
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus) { }
}
```

### 5. 业务操作

```swift
// 设置闹钟
BlueSDK.shared.setAlarm(index: 1, hour: 8, minute: 0, days: .weekdays) { result in }

// 音频设置
BlueSDK.shared.setSoundType(.typeA) { }
BlueSDK.shared.setVolume(.medium) { }
BlueSDK.shared.setTimeFormat(.hour24) { }

// 设备控制
BlueSDK.shared.queryDeviceInfo { result in }
BlueSDK.shared.restoreFactory { }
BlueSDK.shared.clearBinding { }
```

## 连接状态机

```
 DISCONNECTED ────→ CONNECTING ────→ CONNECTED ────→ AUTHENTICATED
      ↑                                                    │
      │         RECONNECTING ←─────────────────────────────┘
      │              │                                 意外断线
      └──────────────┘ 重连失败（5次）
```

## 公开 API

### 连接管理

| 方法 | 说明 |
|------|------|
| `startScan(timeout:callback:)` | 扫描设备 |
| `connect(_:)` | 连接（自动认证+时间同步） |
| `disconnect()` | 断开 |
| `clearBinding()` | 解绑设备 |
| `cancelReconnection()` | 取消重连 |

### 闹钟管理（需认证后）

| 方法 | 说明 |
|------|------|
| `setAlarm(index:hour:minute:days:)` | 设置闹钟 |
| `setAlarms(_:)` | 批量设置 |
| `deleteAlarm(index:)` | 删除 |
| `clearAllAlarms()` | 清空 |
| `queryAlarm(index:)` | 查询 |

### 音频与系统（需认证后）

| 方法 | 说明 |
|------|------|
| `setVolume(_:)` | 音量 |
| `setSoundType(_:)` | 铃声 |
| `setSilence(_:)` | 静音 |
| `setAlertDuration(_:)` | 持续时间 |
| `setTimeFormat(_:)` | 时制 |
| `restoreFactory()` | 恢复出厂 |

## 错误处理

```swift
BlueSDK.shared.setAlarm(index: 1, hour: 8, minute: 0) { result in
    switch result {
    case .success(let info): break
    case .failure(let error):
        print(error.localizedDescription)
        print(error.recoverySuggestion)
    }
}
```

## 线程模型

- **BlueSDKDelegate 回调在主线程派发**
- completion 闭包可能在 BLE 线程，操作 UI 需 `DispatchQueue.main.async`
- SDK 线程安全，多条指令可连续调用

## SDK 技术指标

| 指标 | 数值 |
|------|------|
| Framework 大小 | ~200 KB |
| 初始化耗时 | < 100ms |
| 第三方依赖 | 零 |
| 最低系统 | iOS 13.0 |
