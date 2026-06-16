# Changelog

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本规范](https://semver.org/lang/zh-CN/)。

## [Unreleased]

## [0.2.0] - 2026-06-16

### Added — iOS 功能对齐

**配置与生命周期**
- `BlueSDKConfig` 配置类：支持 fixedAuthKey、logLevel、autoAuthEnabled、autoReconnect、maxReconnectAttempts
- `initialize(config)` 接受配置参数（向后兼容无参调用）
- `fixedAuthKey` 运行时可修改属性

**自动认证（连接后自动完成密钥认证）**
- 连接成功后 SDK 自动发起密钥认证（固定密钥模式 / phoneMac+deviceMac 自动计算模式）
- `KeystoreHelper`：phoneMac 持久化存储（SharedPreferences，零第三方依赖）
- `authenticateWithKey(keyHigh, keyLow)`：直接使用指定密钥认证
- `clearBinding()`：清除本地绑定密钥

**扫描增强**
- `startScan(timeoutMs, callback)`：统一 ScanEvent 回调模式（DeviceFound / Error / Stopped）
- `ScanEvent` sealed class 模型
- 扫描超时自动停止

**闹钟增强**
- `WeekDays` value class（OptionSet 语义，类型安全的星期配置）
- `AlarmConfig` 数据模型（批量设置用）
- `setAlarm(index, hour, minute, days)` 类型安全版本
- `setAlarms(List<AlarmConfig>)` 批量设置便利方法

**日志导出**
- `BlueLogger` 环形缓冲区（最近 1000 条）
- `exportLog(maxLines)` / `clearLogBuffer()` 公开 API

**连接管理**
- `cancelReconnection()` 公开 API
- 时间同步自动响应 + 30秒节流

**用药通知类型安全**
- `sendMedicationNotification(status: MedicationStatus)` 使用枚举参数

### Fixed

- `DeviceInfo` 解析：正确提取前 6 字节 MAC 地址 + 正则提取版本号（原实现仅做 ASCII 转换）
- `MedicationManager.parseMedicationRecord`：字段偏移修正（与 iOS 协议对齐，data[11-12] 为响铃时间，data[13] 为状态）
- `handleDeviceReport`：所有闹钟槽位（1~7）均正确处理响铃/超时/取药事件（原仅处理 ALARM_3）
- 时间同步帧自动响应（原仅回调 listener，不自动下发）

## [0.1.0] - 2026-05-07

### Added

**Epic 1 - SDK 基础设施与协议层**
- 项目结构初始化（Android Library 模块，AAR 分发）
- 协议常量定义：`FrameConstants`、`CommandCode`、`DPIDConstants`（17个DPID）
- `CRC8Calculator`：累加和对256求余算法
- `FrameBuilder`：构建符合 LX-PD02 协议格式的二进制帧
- `FrameParser`：解析设备上报帧，CRC校验失败静默丢弃（NFR12）
- `BlueError`：统一错误类型（sealed class，9种）
- 枚举类型：`ConnectionState`、`MedicationStatus`、`LogLevel`、`VolumeLevel`、`SoundType`、`TimeFormat`、`PermissionStatus`
- 数据模型：`AlarmInfo`、`MedicationRecord`（毫秒时间戳）、`DeviceInfo`、`ScannedDevice`
- `BlueLogger`：分级日志系统（5级），支持自定义处理器，密钥脱敏
- `CommandQueue`：FIFO 串行指令队列，5秒超时，最多重试3次
- `CallbackDispatcher`：确保所有公开回调在主线程派发（Handler + Looper.getMainLooper）
- SDK 生命周期管理：`initialize()` / `destroy()`

**Epic 2~7 - 业务功能层**（与 iOS 完全对称）
- `BLEScanner`、`BLEConnector`、`ConnectionManager`（5状态机 + 自动重连）
- `PermissionManager`：独立权限检查模块
- `AuthManager`：密钥认证
- `DeviceManager`：设备信息 + 时间同步
- `AlarmManager`：闹钟管理（7槽位）
- `MedicationManager`：用药事件与记录
- `AudioManager`：音频与系统设置
- 公开 API：`startScan()`、`stopScan()`、`connect()`、`disconnect()` 等

### Fixed
- `AudioManager` DPID 常量名称混乱（以示例帧为准）
- `handleDeviceReport` 中 `alarm3` 死代码修正
- `MedicationManager` 解析逻辑 alarmDPID 字段偏移错误
- `didAlarmRinging` / `didAlarmTimeout` 路由逻辑修正（byte10 状态值区分）

### Known Issues
- BLE GATT 服务/特征 UUID 使用通用串口服务占位（`FFE0`/`FFE1`），待硬件方提供实际 UUID
- 时间同步帧格式待硬件方确认
- DPID `0x6E`/`0x6F`/`0x70` 实际用途待最终确认
- 编译验证待 Android Studio 执行
