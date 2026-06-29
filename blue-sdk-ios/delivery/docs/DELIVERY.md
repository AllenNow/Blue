# BlueSDK iOS 交付包说明

## 交付物清单

| 文件 | 说明 |
|------|------|
| `BlueSDK.xcframework` 或 SPM 源码 | SDK 库（集成到项目中） |
| `README.md` | 接入文档（快速开始 + API 参考） |
| `CHANGELOG.md` | 版本变更记录 |
| `PRIVACY.md` | 隐私说明（合规审查用） |
| `DELIVERY.md` | 本文件 |
| `Example/` | Demo App 源码（全功能参考实现） |

## 集成 Checklist

按顺序完成以下步骤即可接入成功：

### 准备阶段

- [ ] 确认 iOS Deployment Target ≥ 13.0
- [ ] 确认 Swift 5.7+ / Xcode 14+
- [ ] 确认测试设备支持 Bluetooth 5.0

### 集成阶段

- [ ] 通过 SPM 或 CocoaPods 添加 BlueSDK 依赖
- [ ] 在 `Info.plist` 中添加 `NSBluetoothAlwaysUsageDescription`
- [ ] 在 AppDelegate 中调用 `BlueSDK.shared.initialize()`
- [ ] 设置 `BlueSDK.shared.delegate = self`

### 验证阶段

- [ ] 运行 APP，确认无崩溃
- [ ] 调用 `checkPermissions()` 返回 `.granted`
- [ ] 调用 `startScan()` 能发现 LX-PD02 设备
- [ ] 连接设备后 `didAuthenticateWithSuccess: true` 被回调
- [ ] 调用 `setAlarm()` 设备响应成功
- [ ] 调用 `queryDeviceInfo()` 能获取固件版本

### 发布阶段

- [ ] App Store 隐私标签中声明 "Data Not Collected"
- [ ] 隐私说明已同步给合规团队
- [ ] 如需后台保活，添加 `bluetooth-central` 到 UIBackgroundModes

## SDK 技术指标

| 指标 | 数值 |
|------|------|
| Framework 大小 | ~200 KB |
| 初始化耗时 | < 100ms |
| 运行时内存占用 | < 2 MB |
| 第三方依赖 | 零 |
| 最低系统版本 | iOS 13.0 |
| 支持架构 | arm64（真机）+ x86_64（模拟器，仅编译） |

## 技术支持

- 文档：参考 README.md 和 Demo App 源码
- FAQ：参考 Demo App 内「常见问题」页面
- 问题反馈：联系 SDK 提供方
