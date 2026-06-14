# BlueSDK - iOS

LX-PD02 智能药盒蓝牙通信 SDK（iOS 原生）

[![Platform](https://img.shields.io/badge/platform-iOS%2013.0%2B-blue)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.7%2B-orange)](https://swift.org)
[![Bluetooth](https://img.shields.io/badge/Bluetooth-5.0%2B-blue)](https://www.bluetooth.com)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## 简介

BlueSDK 完整封装 LX-PD02 私有蓝牙 5.0 通信协议，向上提供简洁、类型安全的高层 API。第三方开发者无需了解底层帧结构、CRC 校验、密钥认证等协议细节，即可快速构建具备完整用药提醒闭环能力的移动应用。

**核心能力：**
- 🔵 BLE 设备扫描与连接（自动重连、指数退避）
- 🔐 密钥认证（手机 MAC + 设备 MAC 累加算法）
- ⏰ 闹钟管理（7 个槽位）
- 💊 用药事件接收（响铃/超时/取药/漏服）
- 📋 用药记录上报（含毫秒时间戳）
- 🔊 音频与系统设置
- 📝 分级日志（密钥脱敏）

---

## 系统要求

- iOS 13.0+
- Swift 5.7+
- Xcode 14.0+
- 设备蓝牙须支持 Bluetooth 5.0+

---

## 集成

### CocoaPods（推荐）

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

## 权限配置

在 `Info.plist` 中添加：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限以连接 LX-PD02 智能药盒设备，用于设置用药提醒和接收服药通知。</string>
```

如需后台接收用药事件（推荐）：

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

---

## 快速开始

### 1. 初始化

```swift
// AppDelegate.swift
import BlueSDK

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    BlueSDK.shared.initialize()
    BlueSDK.shared.setLogLevel(.debug) // 开发阶段
    return true
}

func applicationWillTerminate(_ application: UIApplication) {
    BlueSDK.shared.destroy()
}
```

### 2. 注册事件监听

```swift
class MyViewController: UIViewController, BlueSDKDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        BlueSDK.shared.delegate = self
    }

    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState) {
        print("连接状态：\(state)")
    }

    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo) {
        print("闹钟\(alarmIndex)响铃：\(alarmInfo.hour):\(alarmInfo.minute)")
        // 推送本地通知
    }

    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus) {
        print("用药结果：\(status)")
    }

    // 自动响应时间同步请求
    func blueSDKDidRequestTimeSync(_ sdk: BlueSDK) {
        sdk.syncTime { _ in }
    }
}
```

### 3. 扫描并连接设备

```swift
// 检查权限
let status = BlueSDK.shared.checkPermissions()
guard status == .granted else { /* 申请权限 */ return }

// 扫描设备
BlueSDK.shared.startScan(
    onDeviceFound: { device in
        print("发现：\(device.deviceName)，信号：\(device.rssi) dBm")
        BlueSDK.shared.connect(device)
        BlueSDK.shared.stopScan()
    },
    onError: { error in
        print("扫描错误：\(error.localizedDescription)")
    }
)
```

### 4. 认证

```swift
// phoneMac 和 deviceMac 各 6 字节
BlueSDK.shared.authenticate(phoneMac: phoneMac, deviceMac: deviceMac) { result in
    switch result {
    case .success:
        print("认证成功，可执行业务指令")
    case .failure(let error):
        print("认证失败：\(error.localizedDescription)")
    }
}
```

### 5. 设置闹钟

```swift
// 设置闹钟1：每天 08:00
BlueSDK.shared.setAlarm(index: 1, hour: 8, minute: 0, weekMask: 0x7F) { result in
    switch result {
    case .success(let alarm):
        print("闹钟\(alarm.index)设置成功")
    case .failure(let error):
        print("设置失败：\(error.localizedDescription)")
    }
}
```

---

## 错误处理

```swift
switch error {
case .notInitialized:    // 未调用 initialize()
case .notAuthenticated:  // 未完成认证
case .authFailed:        // 密钥不匹配
case .timeout:           // 指令超时（5秒，自动重试3次）
case .permissionDenied:  // 蓝牙权限未授权
case .invalidParameter:  // 参数无效（如闹钟索引超出1~7）
case .disconnected:      // 设备已断开
case .bleError:          // 系统 BLE 错误
}
```

---

## 日志配置

```swift
// 开发阶段
BlueSDK.shared.setLogLevel(.debug)

// 接管日志（接入自有日志系统）
BlueSDK.shared.setLogHandler { level, tag, message in
    MyLogger.log("[\(level)][\(tag)] \(message)")
}

// 生产环境关闭
BlueSDK.shared.setLogLevel(.none)
```

> ⚠️ 密钥值在任何日志级别下均不输出明文。

---

## 隐私说明

本 SDK **不收集、不存储、不上传**任何用户数据：
- 用药记录通过回调传递给 APP，SDK 不做存储
- 设备 MAC 地址仅在内存中用于密钥计算，不持久化
- 不包含任何网络请求

详见 [隐私政策](../../docs/BLE-888/implementation-artifacts/docs/privacy-policy.md)

---

## 文档

| 文档 | 说明 |
|------|------|
| [API 参考](../../docs/BLE-888/implementation-artifacts/docs/api-reference.md) | 完整 API 列表 |
| [协议参考](../../docs/BLE-888/implementation-artifacts/docs/protocol-reference.md) | 帧格式、DPID、CRC8 |
| [权限清单](../../docs/BLE-888/implementation-artifacts/docs/permission-manifest.md) | 权限配置与合规 |
| [故障排查](../../docs/BLE-888/implementation-artifacts/docs/troubleshooting.md) | 常见问题解决 |
| [兼容性矩阵](compatibility-matrix.md) | 设备与系统兼容性 |
| [变更日志](../../CHANGELOG.md) | 版本历史 |

---

## 已知问题

- BLE GATT UUID 使用通用串口服务占位，待硬件方确认后更新
- 时间同步帧格式待硬件方确认

---

## 许可证

MIT License
