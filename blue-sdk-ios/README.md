# BlueSDK iOS

LX-PD02 智能药盒蓝牙通信 SDK（iOS 原生 Swift）

## 系统要求

- iOS 13.0+
- Swift 5.7+
- Xcode 14.0+
- Bluetooth 5.0+ 硬件

## 集成方式

### Swift Package Manager（推荐）

在 Xcode 中：`File → Add Package Dependencies`，输入仓库地址：

```
https://github.com/your-org/blue-sdk-ios.git
```

或在 `Package.swift` 中添加：

```swift
dependencies: [
    .package(url: "https://github.com/your-org/blue-sdk-ios.git", from: "0.2.0")
]
```

### CocoaPods

```ruby
pod 'BlueSDK', '~> 0.2.0'
```

安装后运行 `pod install`，打开 `.xcworkspace`。

## 快速开始

### 1. 权限配置

在 `Info.plist` 中添加：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限以连接智能药盒设备</string>
```

### 2. 初始化 SDK

```swift
import BlueSDK

// AppDelegate 或 SceneDelegate 中调用一次
let config = BlueSDKConfig(
    fixedAuthKey: nil,         // 固定密钥，nil 则自动计算
    logLevel: .debug,          // 日志级别
    autoAuthEnabled: true      // 连接后自动认证
)
BlueSDK.shared.initialize(config: config)
BlueSDK.shared.delegate = self
```

### 3. 扫描并连接设备

```swift
// 扫描（10秒超时自动停止）
BlueSDK.shared.startScan(timeout: 10) { event in
    switch event {
    case .deviceFound(let device):
        BlueSDK.shared.connect(device)  // 连接后 SDK 自动完成密钥认证
        BlueSDK.shared.stopScan()
    case .error(let error):
        print("扫描错误：\(error)")
    case .stopped:
        print("扫描超时")
    }
}
```

### 4. 监听事件回调

```swift
extension ViewController: BlueSDKDelegate {
    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState) {
        // DISCONNECTED → CONNECTING → CONNECTED → AUTHENTICATED
    }
    func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?) {
        if success { /* 可以发送业务指令了 */ }
    }
    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo) {
        // 设备闹钟响铃
    }
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus) {
        // 用药结果（按时/超时/漏服/提前）
    }
}
```

### 5. 发送业务指令

```swift
// 所有业务指令需在 AUTHENTICATED 状态后调用

// 设置闹钟（类型安全）
BlueSDK.shared.setAlarm(index: 1, hour: 8, minute: 0, days: .weekdays) { result in
    switch result {
    case .success(let info): print("设置成功：\(info.hour):\(info.minute)")
    case .failure(let error): print("失败：\(error.recoverySuggestion)")
    }
}

// 批量设置闹钟
BlueSDK.shared.setAlarms([
    AlarmConfig(index: 1, hour: 8, minute: 0, days: .weekdays),
    AlarmConfig(index: 2, hour: 12, minute: 30, days: .all),
    AlarmConfig(index: 3, hour: 20, minute: 0, days: .weekend)
]) { result in }

// 音频设置
BlueSDK.shared.setSoundType(.typeA) { }
BlueSDK.shared.setVolume(.medium) { }
BlueSDK.shared.setTimeFormat(.hour24) { }
BlueSDK.shared.setSilence(true) { }
BlueSDK.shared.setAlertDuration(5) { }

// 设备控制
BlueSDK.shared.syncTime { }
BlueSDK.shared.queryDeviceInfo { result in }
BlueSDK.shared.restoreFactory { }
```

## 架构概览

```
┌─────────────────────────────────────────────────────┐
│                    集成方 App                         │
├─────────────────────────────────────────────────────┤
│  BlueSDK (公开 API 入口，单例)                        │
│  ├── BlueSDKConfig        配置                      │
│  ├── BlueSDKDelegate      事件回调协议               │
│  └── BlueError            错误类型                   │
├─────────────────────────────────────────────────────┤
│  Manager 层（业务逻辑）                               │
│  ├── AuthManager          密钥认证                   │
│  ├── AlarmManager         闹钟管理 (7槽位)           │
│  ├── MedicationManager    用药事件                   │
│  ├── AudioManager         音频/系统设置              │
│  ├── DeviceManager        设备信息/时间同步           │
│  ├── ConnectionManager    连接状态机                 │
│  └── PermissionManager    权限检查                   │
├─────────────────────────────────────────────────────┤
│  Internal 层（基础设施）                              │
│  ├── CommandQueue         FIFO 串行指令队列          │
│  ├── CallbackDispatcher   主线程回调派发             │
│  ├── BlueLogger           分级日志 + 脱敏            │
│  ├── KeychainHelper       phoneMac 持久化            │
│  └── LogFormatter         日志格式化                 │
├─────────────────────────────────────────────────────┤
│  Transport 层（协议通信）                             │
│  ├── BLECentralManager    CBCentralManager 单例      │
│  ├── BLEScanner           设备扫描                   │
│  ├── BLEConnector         GATT 连接/读写             │
│  ├── FrameBuilder         帧构建                    │
│  ├── FrameParser          帧解析 + CRC 校验          │
│  ├── StreamFrameParser    粘包/分包处理              │
│  └── CRC8Calculator       校验算法                   │
└─────────────────────────────────────────────────────┘
                        ↕ CoreBluetooth
┌─────────────────────────────────────────────────────┐
│              LX-PD02 智能药盒硬件                     │
└─────────────────────────────────────────────────────┘
```

## 连接状态机

```
                    connect()
 DISCONNECTED ──────────────────→ CONNECTING
      ↑                                │
      │ disconnect()                   │ GATT 连接成功
      │ 重连失败(5次)                    ↓
      ←──────────────────────── CONNECTED
      ↑                                │
      │                                │ 自动密钥认证
      │        意外断线                  ↓
 RECONNECTING ←──────────────── AUTHENTICATED
      │                                │
      │     2s/4s/8s 指数退避            │ disconnect()
      └────────→ CONNECTING ←──────────┘ (不触发重连)
```

## 线程模型

- **所有 `BlueSDKDelegate` 回调在主线程派发**，集成方无需手动切换线程
- 内部 BLE 操作在 CoreBluetooth 默认队列执行
- `CommandQueue` 保证同一时刻只有一条指令在等待应答（FIFO 串行）
- 指令间隔 200ms，超时 5 秒自动重试，最多重试 3 次

## 错误处理

所有异步操作通过 `Result<T, BlueError>` 回调返回，不抛出异常。

```swift
BlueSDK.shared.setAlarm(index: 1, hour: 8, minute: 0) { result in
    switch result {
    case .success(let info):
        print("设置成功")
    case .failure(let error):
        print("\(error.localizedDescription)")
        print("建议：\(error.recoverySuggestion)")
    }
}
```

### 错误类型

| 错误 | Code | 说明 | 恢复建议 |
|------|------|------|----------|
| `.notInitialized` | 1 | SDK 未初始化 | 先调用 `initialize()` |
| `.notAuthenticated` | 2 | 未完成认证 | 等待自动认证或检查密钥 |
| `.authFailed` | 3 | 密钥不匹配 | 设备恢复出厂后重试 |
| `.timeout` | 4 | 指令超时 | 确认设备在 3 米内 |
| `.permissionDenied` | 5 | 蓝牙权限未授权 | 引导用户授权 |
| `.invalidParameter` | 6 | 参数无效 | 检查参数范围 |
| `.protocolError` | 7 | CRC 校验失败 | 断开重连后重试 |
| `.bleError` | 8 | 系统蓝牙异常 | 确认蓝牙已开启 |
| `.disconnected` | 9 | 连接已断开 | SDK 自动重连或手动 connect |

## 常见问题 FAQ

### 蓝牙权限弹窗不出现

确保 `Info.plist` 中包含 `NSBluetoothAlwaysUsageDescription`。iOS 13+ 必须声明此 key。

### 认证失败

1. 检查 `BlueSDKConfig.fixedAuthKey` 是否为 4 位十六进制（如 "05FA"）
2. 设备已被其他手机绑定时，需对设备长按按键恢复出厂
3. 恢复后调用 `clearBinding()` 清除本地旧密钥

### 后台保活

iOS 不支持无限后台 BLE。如需后台保持连接：
1. 在 `Info.plist` 添加 `UIBackgroundModes` → `bluetooth-central`
2. 系统仍可能在内存压力时终止连接

### 指令并发

无需手动管理并发，SDK 内部 `CommandQueue` 自动串行排队：

```swift
BlueSDK.shared.setAlarm(index: 1, hour: 8, minute: 0) { }
BlueSDK.shared.setAlarm(index: 2, hour: 12, minute: 30) { }  // 自动排队
BlueSDK.shared.setSoundType(.typeB) { }  // 继续排队
```

## 公开 API 参考

### 生命周期

| 方法 | 说明 |
|------|------|
| `initialize(config:)` | 初始化 SDK |
| `destroy()` | 释放所有 BLE 资源 |

### 连接管理

| 方法 | 说明 |
|------|------|
| `startScan(timeout:callback:)` | 扫描 BLE 设备（ScanEvent 回调） |
| `stopScan()` | 停止扫描 |
| `connect(_:)` | 连接设备（自动认证） |
| `disconnect()` | 主动断开 |
| `cancelReconnection()` | 取消自动重连 |
| `clearBinding()` | 清除本地绑定密钥 |
| `authenticateWithKey(keyHigh:keyLow:)` | 指定密钥认证 |
| `checkPermissions()` | 查询蓝牙权限状态 |
| `connectionState` | 当前连接状态（属性） |

### 设备信息

| 方法 | 前置条件 |
|------|----------|
| `queryDeviceInfo(completion:)` | 已初始化 |
| `syncTime(date:completion:)` | 已认证 |

### 闹钟管理

| 方法 | 前置条件 |
|------|----------|
| `setAlarm(index:hour:minute:days:completion:)` | 已认证 |
| `setAlarms(_:completion:)` | 已认证 |
| `deleteAlarm(index:completion:)` | 已认证 |
| `clearAllAlarms(completion:)` | 已认证 |

### 音频与系统

| 方法 | 前置条件 |
|------|----------|
| `setVolume(_:completion:)` | 已认证 |
| `setSoundType(_:completion:)` | 已认证 |
| `setSilence(_:completion:)` | 已认证 |
| `setAlertDuration(_:completion:)` | 已认证 |
| `setTimeFormat(_:completion:)` | 已认证 |
| `restoreFactory(completion:)` | 已认证 |
| `sendMedicationNotification(status:completion:)` | 已认证 |

### 日志

| 方法 | 说明 |
|------|------|
| `setLogLevel(_:)` | 设置日志级别 |
| `setLogHandler(_:)` | 自定义日志处理器 |
| `exportLog(maxLines:)` | 导出最近日志 |
| `clearLogBuffer()` | 清空缓冲区 |

## 项目结构

```
blue-sdk-ios/
├── BlueSDK/
│   └── BlueSDK/Classes/
│       ├── BlueSDK.swift            # 公开 API 入口（单例）
│       ├── BlueSDKConfig.swift      # 初始化配置
│       ├── BlueSDKDelegate.swift    # 事件回调协议
│       ├── Enums/                   # 枚举类型
│       ├── Error/                   # BlueError
│       ├── Internal/                # 内部组件
│       ├── Manager/                 # 业务管理器
│       ├── Model/                   # 数据模型
│       └── Transport/               # BLE 传输协议层
├── Tests/                           # 单元测试
├── BlueSDK/Example/                 # Demo App
│   ├── ViewController.swift         # 主控台
│   ├── AlarmManagerViewController.swift
│   ├── AlarmEditorViewController.swift
│   ├── MedicationRecordsViewController.swift
│   ├── ProtocolTestViewController.swift
│   ├── DebugViewController.swift
│   └── MedicationDatabase.swift
└── Package.swift
```

## Demo App

Example 应用演示了 SDK 全部功能：

- **主页**：扫描连接 + Loading 遮罩 + 密钥输入 + 全指令面板 + SDK 日志
- **闹钟管理**：7 个槽位列表，UIDatePicker 编辑，周选择，侧滑删除
- **用药记录**：UIDatePicker 按日期查询，SQLite 持久化
- **协议验证**：15 条测试用例自动化执行，TableView 实时状态

运行 Demo：
```bash
cd blue-sdk-ios
open BlueSDK/Example/BlueSDK.xcworkspace
# 选择真机 Target → Run
```

> ⚠️ CoreBluetooth 不支持模拟器 BLE，必须真机测试

## 跨平台对齐

BlueSDK iOS 与 Android 端保持完全的 API 和协议对齐：

- 错误码 1~9 一一对应
- DPID 常量值相同
- 帧格式和 CRC 算法相同
- 回调事件覆盖范围相同
- 时间戳统一使用毫秒

## 版本历史

参见 [CHANGELOG.md](./CHANGELOG.md)

## License

MIT
