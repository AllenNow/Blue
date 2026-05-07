# BlueSDK iOS 集成指南

**版本**: 0.1.0  
**最低系统**: iOS 13.0  
**最低蓝牙**: Bluetooth 5.0  
**语言**: Swift 5.7+（支持 Objective-C 调用）

---

## 1. 集成方式

### CocoaPods

在 `Podfile` 中添加：

```ruby
platform :ios, '13.0'
use_frameworks!

target 'YourApp' do
  pod 'BlueSDK', :path => '../blue-sdk-ios/BlueSDK'
end
```

执行：
```bash
pod install
```

### Swift Package Manager

在 `Package.swift` 中添加：

```swift
dependencies: [
    .package(path: "../blue-sdk-ios")
]
```

---

## 2. 权限配置

在 `Info.plist` 中添加：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限以连接 LX-PD02 智能药盒设备</string>
```

---

## 3. 初始化

在 `AppDelegate` 中：

```swift
import BlueSDK

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // 初始化 SDK
    BlueSDK.shared.initialize()
    // 开发阶段开启调试日志
    BlueSDK.shared.setLogLevel(.debug)
    return true
}

func applicationWillTerminate(_ application: UIApplication) {
    BlueSDK.shared.destroy()
}
```

---

## 4. 注册事件监听

```swift
class MyViewController: UIViewController, BlueSDKDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        BlueSDK.shared.delegate = self
    }

    // 连接状态变化
    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState) {
        switch state {
        case .disconnected:  print("已断开")
        case .connecting:    print("连接中")
        case .connected:     print("已连接（未认证）")
        case .authenticated: print("已认证，可执行业务指令")
        case .reconnecting:  print("重连中")
        }
    }

    // 认证结果
    func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError) {
        if success { print("认证成功") }
        else { print("认证失败：\(error.localizedDescription ?? "")") }
    }

    // 闹钟响铃
    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo) {
        print("闹钟\(alarmIndex)响铃：\(alarmInfo.hour):\(alarmInfo.minute)")
    }

    // 用药结果
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus) {
        switch status {
        case .taken:   print("按时取药")
        case .timeout: print("超时取药")
        case .missed:  print("漏服")
        case .early:   print("提前取药")
        }
    }

    // 时间同步请求（自动响应）
    func blueSDKDidRequestTimeSync(_ sdk: BlueSDK) {
        sdk.syncTime { result in
            print("时间同步：\(result)")
        }
    }
}
```

---

## 5. 完整集成流程

### 步骤1：检查权限

```swift
let status = BlueSDK.shared.checkPermissions()
if status != .granted {
    // 引导用户授权
}
```

### 步骤2：扫描设备

```swift
// 扫描功能需通过 ConnectionManager 实现（需传入 CBCentralManager）
// 详见 Demo 工程：blue-sdk-ios/BlueSDK/Example/
```

### 步骤3：认证

```swift
// phoneMac 和 deviceMac 各 6 字节
let phoneMac: [UInt8] = [0xC7, 0x50, 0xB2, 0xAA, 0xC3, 0xF3]
let deviceMac: [UInt8] = [0xA6, 0xC0, 0x82, 0x00, 0xA1, 0xC2]

BlueSDK.shared.authenticate(phoneMac: phoneMac, deviceMac: deviceMac) { result in
    switch result {
    case .success: print("认证成功")
    case .failure(let error): print("认证失败：\(error)")
    }
}
```

### 步骤4：设置闹钟

```swift
// 设置闹钟1：每天 08:00
BlueSDK.shared.setAlarm(index: 1, hour: 8, minute: 0, weekMask: 0x7F) { result in
    switch result {
    case .success(let alarm): print("闹钟\(alarm.index)设置成功")
    case .failure(let error): print("设置失败：\(error)")
    }
}
```

### 步骤5：接收用药事件

通过 `BlueSDKDelegate` 回调自动接收，无需主动轮询。

---

## 6. 错误处理

```swift
switch error {
case .notInitialized:   // 未调用 initialize()
case .notAuthenticated: // 未完成认证
case .authFailed:       // 密钥不匹配
case .timeout:          // 指令超时（5秒）
case .permissionDenied: // 蓝牙权限未授权
case .invalidParameter: // 参数无效（如闹钟索引超出1~7）
case .disconnected:     // 设备已断开
case .bleError:         // 系统 BLE 错误
}
```

---

## 7. iOS 后台限制说明

iOS 系统对后台 BLE 连接有严格限制：

- APP 进入后台后，BLE 连接可能被系统终止
- 建议结合 APNs 推送通知作为用药事件的补偿通知机制
- 在 `Info.plist` 中添加后台模式（如需）：

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

---

## 8. 日志配置

```swift
// 开发阶段
BlueSDK.shared.setLogLevel(.debug)

// 接管日志输出
BlueSDK.shared.setLogHandler { level, tag, message in
    MyLogger.log("[\(level)] [\(tag)] \(message)")
}

// 生产环境关闭日志
BlueSDK.shared.setLogLevel(.none)
```

> ⚠️ 密钥值在任何日志级别下均不输出明文。
