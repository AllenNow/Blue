# BlueSDK 隐私说明

## 概述

BlueSDK 是一个纯本地蓝牙通信 SDK，**不进行任何网络通信、不上传任何数据到服务器**。

## 数据采集

| 数据类型 | 用途 | 存储位置 | 生命周期 |
|----------|------|----------|----------|
| phoneMac（6字节随机标识） | BLE 配对认证密钥计算 | Keychain（kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly） | 卸载 APP 后仍保留（iOS Keychain 特性） |
| 设备 MAC 地址 | 密钥计算 + 设备识别 | 仅运行时内存，不持久化 | 断开连接后释放 |
| SDK 运行日志 | 调试排查（环形缓冲区最多1000条） | 仅运行时内存 | APP 关闭后丢失 |

## 不采集的数据

- ❌ 不采集用户个人信息（姓名、手机号等）
- ❌ 不采集地理位置
- ❌ 不采集设备标识符（IDFA、IDFV 等）
- ❌ 不进行网络请求
- ❌ 不使用第三方 SDK 或分析服务
- ❌ 不使用 App Tracking Transparency（ATT）

## 权限说明

| 权限 | 用途 | 必要性 |
|------|------|--------|
| `NSBluetoothAlwaysUsageDescription` | BLE 通信 | 必须 |

## 数据安全

- phoneMac 存储在 iOS Keychain，硬件级加密保护
- 日志输出经过脱敏处理，密钥值和 MAC 地址不会以明文出现
- SDK 不包含任何后门、远程控制或数据回传机制

## Apple 隐私标签

集成 BlueSDK 后，App Store 隐私标签可声明：
- **Data Not Collected** — SDK 不收集任何关联到用户身份的数据
- **Data Not Linked to You** — phoneMac 是随机生成的设备标识，不关联用户

## 合规声明

- 符合《个人信息保护法》最小必要原则
- 符合 Apple App Store 隐私政策要求
- 不触发 ATT 弹窗（不追踪用户）

## 联系方式

如有隐私相关疑问，请联系 SDK 提供方。
