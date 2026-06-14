# BlueSDK - iOS

LX-PD02 智能药盒蓝牙通信 SDK（iOS 原生）

## 简介

BlueSDK 是专为 LX-PD02 智能药盒硬件设计的 iOS 原生蓝牙通信与控制 SDK。完整封装 LX-PD02 私有蓝牙 5.0 通信协议，向上提供简洁、类型安全的高层 API。

## 系统要求

- iOS 13.0+
- Swift 5.7+
- Xcode 14.0+
- 设备蓝牙硬件须支持 Bluetooth 5.0 及以上

## 集成方式

### Swift Package Manager

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/your-org/blue-sdk-ios.git", from: "0.1.0")
]
```

### CocoaPods

在 `Podfile` 中添加：

```ruby
pod 'BlueSDK', '~> 0.1.0'
```

## 快速开始

```swift
import BlueSDK

// 初始化
BlueSDK.shared.initialize()

// 扫描设备（Story 2.2 实现后可用）
// BlueSDK.shared.startScan { device in ... }
```

## 权限配置

在 `Info.plist` 中添加：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限以连接智能药盒设备</string>
```

## 文档

- [API 参考](./docs/api-reference.md)（待补充）
- [集成指南](./docs/integration-guide.md)（待补充）
- [变更日志](./CHANGELOG.md)

## 许可证

MIT License
