# BlueSDK Android 交付包说明

## 交付物清单

| 文件 | 说明 |
|------|------|
| `blue-sdk-release.aar` | SDK 库文件（集成到项目中） |
| `README.md` | 接入文档（快速开始 + API 参考 + 协议参考） |
| `CHANGELOG.md` | 版本变更记录 |
| `PRIVACY.md` | 隐私说明（合规审查用） |
| `DELIVERY.md` | 本文件 |
| `consumer-rules.pro` | 混淆规则（已内嵌 AAR，无需手动配置） |
| `app/` | Demo App 源码（全功能参考实现） |

## 集成 Checklist

按顺序完成以下步骤即可接入成功：

### 准备阶段

- [ ] 确认 Android minSdk ≥ 21（Android 5.0）
- [ ] 确认 Kotlin 1.9+ 或 Java 8+
- [ ] 确认测试设备支持 Bluetooth 5.0

### 集成阶段

- [ ] 将 `blue-sdk-release.aar` 放入 `app/libs/` 目录
- [ ] 在 `build.gradle` 中添加 `implementation(files("libs/blue-sdk-release.aar"))`
- [ ] 在 `AndroidManifest.xml` 中添加蓝牙权限（参考 README）
- [ ] 在 `Application.onCreate()` 中调用 `BlueSDK.getInstance(this).initialize()`

### 验证阶段

- [ ] 运行 APP，确认无崩溃
- [ ] 调用 `checkPermissions()` 返回 `GRANTED`
- [ ] 调用 `startScan()` 能发现 LX-PD02 设备
- [ ] 连接设备后 `onAuthResult(success=true)` 被回调
- [ ] 调用 `setAlarm()` 设备响应成功
- [ ] 调用 `queryDeviceInfo()` 能获取固件版本

### 发布阶段

- [ ] 确认混淆后 SDK 功能正常（consumer-rules.pro 已自动生效）
- [ ] 隐私说明已同步给合规团队
- [ ] 确认 APP 权限说明中包含蓝牙权限用途描述

## SDK 技术指标

| 指标 | 数值 |
|------|------|
| AAR 大小 | ~120 KB |
| 初始化耗时 | < 100ms |
| 运行时内存占用 | < 2 MB |
| 第三方依赖 | 零 |
| 最低系统版本 | Android 5.0 (API 21) |
| 目标系统版本 | Android 14 (API 34) |

## 技术支持

- 文档：参考 README.md 和 Demo App 源码
- FAQ：参考 Demo App 内「常见问题」页面
- 问题反馈：联系 SDK 提供方
