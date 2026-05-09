# Changelog

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本规范](https://semver.org/lang/zh-CN/)。

## [Unreleased]

## [0.1.0] - 2026-05-07

### Added

**Epic 1 - SDK 基础设施与协议层**
- 项目结构初始化（CocoaPods + Swift Package Manager 双分发）
- 协议常量定义：`FrameConstants`、`CommandCode`、`DPIDConstants`（17个DPID）
- `CRC8Calculator`：累加和对256求余算法，含6个协议帧验证测试
- `FrameBuilder`：构建符合 LX-PD02 协议格式的二进制帧
- `FrameParser`：解析设备上报帧，CRC校验失败静默丢弃（NFR12）
- `BlueError`：统一错误类型（9种），实现 `LocalizedError`
- 枚举类型：`ConnectionState`、`MedicationStatus`、`LogLevel`、`VolumeLevel`、`SoundType`、`TimeFormat`、`PermissionStatus`
- 数据模型：`AlarmInfo`、`MedicationRecord`（毫秒时间戳）、`DeviceInfo`、`ScannedDevice`
- `BlueLogger`：分级日志系统（5级），支持自定义处理器，密钥脱敏
- `CommandQueue`：FIFO 串行指令队列，5秒超时，最多重试3次
- `CallbackDispatcher`：确保所有公开回调在主线程派发
- SDK 生命周期管理：`initialize()` / `destroy()`

**Epic 2 - 设备发现与连接管理**
- `BLEScanner`：扫描广播名前缀为 `LX-PD02` 的设备
- `BLEConnector`：GATT 连接管理，服务/特征发现，Notify 订阅
- `ConnectionManager`：5状态连接状态机（DISCONNECTED/CONNECTING/CONNECTED/AUTHENTICATED/RECONNECTING）
- 断线自动重连：指数退避（2s/4s/8s），最多5次
- 公开 API：`startScan()`、`stopScan()`、`connect()`、`disconnect()`、`checkPermissions()`

**Epic 3 - 身份认证**
- `AuthManager`：密钥计算（手机MAC + 设备MAC逐字节累加），认证失败自动断开
- 状态守卫：未认证时调用业务API返回 `BlueError.notAuthenticated`

**Epic 4 - 设备信息与时间同步**
- `DeviceManager`：查询设备信息、下发系统时间
- ⚠️ 时间同步帧格式待硬件方确认

**Epic 5 - 闹钟管理**
- `AlarmManager`：设置/删除/清空闹钟（7个槽位），解析设备端上报

**Epic 6 - 用药事件与记录**
- `MedicationManager`：解析响铃/超时/用药结果/用药记录事件，下发用药通知

**Epic 7 - 音频与系统设置**
- `AudioManager`：音量/铃声类型/静音/持续时长/时间格式设置，解析设备端上报

**文档**
- iOS 集成指南、Android 集成指南、API 参考文档
- 协议参考文档、故障排查指南
- 隐私政策说明、权限清单（含合规检查清单）

### Fixed
- `AudioManager` DPID 常量名称混乱（`0x6E`/`0x6F`/`0x70` 以示例帧为准）
- `handleDeviceReport` 中 `alarm3` 死代码（用药事件路由逻辑修正）
- `MedicationManager` 解析逻辑 alarmDPID 字段偏移错误
- `didAlarmRinging` / `didAlarmTimeout` 未正确触发（byte10 状态值路由修正）
- `PermissionStatus` 移至 `Enums/` 目录，与 Android 对称
- `MedicationRecord.timestamp` 统一为毫秒（与 Android 一致）
- Example 工程 Deployment Target 从 9.3 升级至 13.0

### Known Issues
- BLE GATT 服务/特征 UUID 使用通用串口服务占位（`FFE0`/`FFE1`），待硬件方提供实际 UUID
- 时间同步帧格式待硬件方确认（当前实现为10字节数据段）
- DPID `0x6E`/`0x6F`/`0x70` 实际用途待最终确认
