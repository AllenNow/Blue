# Changelog

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本规范](https://semver.org/lang/zh-CN/)。

## [Unreleased]

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
