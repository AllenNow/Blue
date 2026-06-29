# BlueSDK 隐私说明

## 概述

BlueSDK 是一个纯本地蓝牙通信 SDK，**不进行任何网络通信、不上传任何数据到服务器**。

## 数据采集

| 数据类型 | 用途 | 存储位置 | 生命周期 |
|----------|------|----------|----------|
| phoneMac（6字节随机标识） | BLE 配对认证密钥计算 | SharedPreferences（应用私有目录） | 卸载 APP 时清除 |
| 设备 MAC 地址 | 密钥计算 + 设备识别 | 仅运行时内存，不持久化 | 断开连接后释放 |
| SDK 运行日志 | 调试排查（环形缓冲区最多1000条） | 仅运行时内存 | APP 关闭后丢失 |

## 不采集的数据

- ❌ 不采集用户个人信息（姓名、手机号、身份证等）
- ❌ 不采集地理位置（仅使用位置权限进行 BLE 扫描，不读取 GPS）
- ❌ 不采集设备标识符（IMEI、Android ID 等）
- ❌ 不进行网络请求
- ❌ 不使用第三方 SDK 或分析服务

## 权限说明

| 权限 | 用途 | 必要性 |
|------|------|--------|
| `BLUETOOTH` | BLE 通信 | 必须 |
| `BLUETOOTH_ADMIN` | BLE 扫描（Android 11 及以下） | 必须 |
| `ACCESS_FINE_LOCATION` | BLE 扫描（Android 6~11 系统要求） | Android 6~11 必须 |
| `BLUETOOTH_SCAN` | BLE 扫描（Android 12+） | Android 12+ 必须 |
| `BLUETOOTH_CONNECT` | BLE 连接（Android 12+） | Android 12+ 必须 |

> 注：`ACCESS_FINE_LOCATION` 仅用于满足系统 BLE 扫描要求，SDK 内部不读取任何位置信息。配置了 `usesPermissionFlags="neverForLocation"` 声明。

## 数据安全

- phoneMac 使用应用私有 SharedPreferences 存储，其他应用无法访问
- 日志输出经过脱敏处理，密钥值和 MAC 地址不会以明文出现在日志中
- SDK 不包含任何后门、远程控制或数据回传机制

## 合规声明

- 符合《个人信息保护法》最小必要原则
- 符合 Google Play 数据安全政策要求
- 符合 Apple App Store 隐私标签要求（iOS 版）
- SDK 不触发 Google Play 的 "Data collected" 声明（无网络、无用户数据）

## 联系方式

如有隐私相关疑问，请联系 SDK 提供方。
