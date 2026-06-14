---
stepsCompleted: ["step-01-validate-prerequisites", "step-02-design-epics", "step-03-create-stories", "step-04-final-validation"]
inputDocuments: ["_bmad-output/planning-artifacts/prd.md", "_bmad-output/planning-artifacts/architecture.md"]
---

# Blue - Epic Breakdown

## Overview

本文档提供 Blue SDK 项目的完整 Epic 和 Story 拆解，基于 PRD 功能需求（FR01~FR36）、非功能需求（NFR01~NFR22）和架构文档，将所有需求分解为可执行的开发故事。

---

## Requirements Inventory

### Functional Requirements

- **FR01**：开发者可发起 BLE 扫描，SDK 自动过滤并返回广播名前缀为 `LX-PD02` 的设备列表
- **FR02**：开发者可指定设备 ID 发起连接请求
- **FR03**：开发者可主动断开当前连接
- **FR04**：上层应用可订阅连接状态变化事件（已连接 / 重连中 / 已断开 / 连接失败）
- **FR05**：SDK 在连接意外断开后自动执行重连，重连结果通过回调通知上层
- **FR06**：开发者可查询当前连接状态（同步方法）
- **FR07**：开发者可查询当前蓝牙权限状态，SDK 返回权限枚举值
- **FR08**：SDK 可基于手机 MAC 地址与设备 MAC 地址自动计算并发送密钥包
- **FR09**：上层应用可订阅认证结果事件（认证成功 / 认证失败）
- **FR10**：SDK 在认证失败时自动断开连接，并通过回调通知上层
- **FR11**：SDK 在未完成认证的状态下拒绝执行业务指令，并返回明确错误码
- **FR12**：开发者可主动查询设备基础信息（固件版本等）
- **FR13**：上层应用可订阅设备时间同步请求事件
- **FR14**：开发者可向设备下发当前系统时间完成时间同步
- **FR15**：开发者可设置指定槽位（1~7）的闹钟，包含时、分、星期周期掩码
- **FR16**：开发者可删除指定槽位的闹钟
- **FR17**：开发者可清空设备上所有闹钟
- **FR18**：上层应用可订阅设备端闹钟变更上报事件，获取最新闹钟配置
- **FR19**：SDK 返回的闹钟数据包含完整字段：时间、周期掩码、提前取药状态
- **FR20**：上层应用可订阅闹钟开始响铃事件，事件携带对应闹钟槽位信息
- **FR21**：上层应用可订阅闹钟超时未取药事件
- **FR22**：上层应用可订阅用药结果事件，结果包含语义化状态枚举（按时取药 / 超时取药 / 漏服 / 提前取药）
- **FR23**：上层应用可订阅用药记录上报事件，记录包含时间戳、闹钟槽位、用药状态
- **FR24**：开发者可向设备下发用药结果通知指令（等待 / 响铃开始 / 错过 / 成功）
- **FR25**：开发者可设置设备提醒音量（低 / 中 / 高三档）
- **FR26**：开发者可设置设备铃声类型（类型 A / B / C）
- **FR27**：上层应用可订阅设备端铃声类型变更上报事件
- **FR28**：开发者可设置当前闹钟静音状态（开 / 关）
- **FR29**：开发者可设置闹钟提醒持续时长
- **FR30**：开发者可设置设备时间显示格式（12 小时制 / 24 小时制）
- **FR31**：上层应用可订阅设备端时间格式变更上报事件
- **FR32**：开发者可初始化 SDK 并绑定应用上下文
- **FR33**：开发者可销毁 SDK 实例，释放所有 BLE 资源
- **FR34**：开发者可设置 SDK 日志级别（NONE / ERROR / WARN / INFO / DEBUG）
- **FR35**：开发者可注册自定义日志处理器，接管 SDK 日志输出
- **FR36**：SDK 在任何日志级别下均不输出密钥明文

### NonFunctional Requirements

- **NFR01**：指令端到端延迟 ≤ 3 秒（正常 BLE 信号环境）
- **NFR02**：指令超时 5 秒触发回调，自动重试最多 3 次
- **NFR03**：BLE 扫描首次返回延迟 ≤ 2 秒
- **NFR04**：SDK 初始化耗时 ≤ 100ms，不阻塞主线程
- **NFR05**：SDK 运行时内存占用 ≤ 5MB
- **NFR06**：密钥计算仅在内存中执行，不写入日志或持久化存储
- **NFR07**：任何日志级别下不输出密钥明文、MAC 地址原始值
- **NFR08**：SDK 不收集、不上传任何用户数据至远程服务器
- **NFR09**：SDK 不包含任何网络请求能力
- **NFR10**：BLE 连接成功率 ≥ 95%
- **NFR11**：断线后自动重连成功率（5 次重试内）≥ 90%
- **NFR12**：CRC 校验失败或帧格式异常时内部静默丢弃，崩溃率为 0
- **NFR13**：SDK 内部状态机在任意异常输入下不进入死锁
- **NFR14**：用药事件上报不丢失，回调触发前完成帧完整性校验
- **NFR15**：Android 兼容 API Level 21~最新，设备蓝牙须支持 BT 5.0+
- **NFR16**：iOS 兼容 iOS 13.0~最新，设备蓝牙须支持 BT 5.0+
- **NFR17**：Android SDK 同时提供 Kotlin 和 Java 调用接口
- **NFR18**：iOS SDK 同时提供 Swift 和 Objective-C 调用接口
- **NFR19**：SDK 零第三方运行时依赖，仅依赖系统 BLE 框架
- **NFR20**：遵循 SemVer，主版本变更提供迁移指南
- **NFR21**：公开 API 向后兼容，小版本升级无需修改业务代码
- **NFR22**：每次发布附带 CHANGELOG

### Additional Requirements

来自架构文档的技术实现要求：

- **ARCH-01**：三层架构强制执行——Public API Layer / Business Logic Layer / BLE Transport Layer，不得跨层直接调用
- **ARCH-02**：所有协议常量定义在 `FrameConstants` / `CommandCode` / `DPIDConstants`，禁止魔法数字
- **ARCH-03**：CRC8 计算：从帧头第一字节累加和对 256 求余，唯一实现，不允许变体
- **ARCH-04**：指令串行队列，同一时刻只允许一条指令等待应答
- **ARCH-05**：设备主动上报帧（CMD=0x07）不经过指令队列，直接路由到事件分发器
- **ARCH-06**：所有回调通过 `CallbackDispatcher` 派发到主线程，禁止直接调用
- **ARCH-07**：所有状态变更通过状态机入口，禁止直接赋值状态字段
- **ARCH-08**：所有异常转换为 `BlueError` 通过回调返回，不向上层抛出
- **ARCH-09**：日志脱敏在 `LogFormatter` 层统一处理，密钥/MAC 替换为 `***`
- **ARCH-10**：双平台 API 命名对称（见架构文档对称性约定表）

### UX Design Requirements

本项目为纯 SDK，无 UI 组件，不适用 UX 设计需求。

### FR Coverage Map

| FR | Epic |
|---|---|
| FR01~07 | Epic 2 — 设备发现与连接管理 |
| FR08~11 | Epic 3 — 身份认证与安全绑定 |
| FR12~14 | Epic 4 — 设备信息与时间同步 |
| FR15~19 | Epic 5 — 闹钟管理 |
| FR20~24 | Epic 6 — 用药事件与记录 |
| FR25~31 | Epic 7 — 音频与系统设置 |
| FR32~36 | Epic 1 — SDK 基础设施与协议层 |

**覆盖率：36/36 FR，100%**

## Epic List

### Epic 1：SDK 基础设施与协议层
建立 SDK 项目骨架、协议编解码能力、日志系统和错误处理基础设施，为所有上层功能提供基础。
**FRs covered:** FR32, FR33, FR34, FR35, FR36
**ARCH covered:** ARCH-01~10
**NFRs covered:** NFR04, NFR06, NFR07, NFR09, NFR12, NFR13, NFR17, NFR18, NFR19

### Epic 2：设备发现与连接管理
开发者可扫描、连接、断开 LX-PD02 设备，并接收连接状态变化事件，SDK 自动处理断线重连。
**FRs covered:** FR01, FR02, FR03, FR04, FR05, FR06, FR07
**NFRs covered:** NFR03, NFR04, NFR10, NFR11, NFR15, NFR16

### Epic 3：身份认证与安全绑定
开发者可完成设备绑定认证，SDK 自动计算密钥包并处理认证失败断开，未认证时拒绝业务指令。
**FRs covered:** FR08, FR09, FR10, FR11
**NFRs covered:** NFR06, NFR07

### Epic 4：设备信息与时间同步
开发者可查询设备基础信息，SDK 自动响应设备时间同步请求并下发当前系统时间。
**FRs covered:** FR12, FR13, FR14
**NFRs covered:** NFR01, NFR02

### Epic 5：闹钟管理
开发者可完整管理设备上的 7 个闹钟槽位（设置/删除/清空），并接收设备端闹钟变更上报。
**FRs covered:** FR15, FR16, FR17, FR18, FR19
**NFRs covered:** NFR01, NFR02, NFR14

### Epic 6：用药事件与记录
上层应用可接收完整的用药事件流（响铃→取药/超时/漏服），获取语义化用药状态和带时间戳的用药记录。
**FRs covered:** FR20, FR21, FR22, FR23, FR24
**NFRs covered:** NFR14

### Epic 7：音频与系统设置
开发者可配置设备音量、铃声类型、静音、提醒持续时长、时间格式等系统参数，并接收设备端变更上报。
**FRs covered:** FR25, FR26, FR27, FR28, FR29, FR30, FR31
**NFRs covered:** NFR01, NFR02

---

## Epic 1：SDK 基础设施与协议层

建立 SDK 项目骨架、协议编解码能力、日志系统和错误处理基础设施，为所有上层功能提供基础。

### Story 1.1：项目结构初始化（双平台）

As a SDK 开发工程师，
I want 按照架构文档初始化 Android 和 iOS 两个 SDK 项目的目录结构，
So that 后续所有模块有明确的文件归属位置，双平台结构对称一致。

**Acceptance Criteria:**

**Given** 开发环境已配置（Android Studio / Xcode）
**When** 按架构文档创建项目结构
**Then** Android 项目包含 `blue-sdk/` 模块和 `app/` Demo 模块，目录结构与架构文档完全一致
**And** iOS 项目包含 `Sources/BlueSDK/`、`Tests/BlueSDKTests/`、`BlueSDKDemo/` 目录，结构与架构文档完全一致
**And** Android 配置 Kotlin DSL Gradle，最低 SDK API Level 21
**And** iOS 配置 Package.swift 和 BlueSDK.podspec，最低版本 iOS 13.0
**And** 两个项目均可成功编译（空项目）

---

### Story 1.2：协议常量定义

As a SDK 开发工程师，
I want 定义所有协议帧格式常量、CMD 命令码和 DPID 功能字节常量，
So that 后续所有模块引用常量而非魔法数字，保证协议实现一致性。

**Acceptance Criteria:**

**Given** Story 1.1 项目结构已建立
**When** 实现 `FrameConstants`、`CommandCode`、`DPIDConstants` 三个常量文件
**Then** `FrameConstants` 包含：`HEADER_BYTE1=0x55`、`HEADER_BYTE2=0xAA`、`PROTOCOL_VERSION=0x00`、`MIN_FRAME_LENGTH=7`
**And** `CommandCode` 包含：`QUERY_DEVICE_INFO=0x01`、`TIME_SYNC=0xE1`、`SEND_COMMAND=0x06`、`DEVICE_REPORT=0x07`
**And** `DPIDConstants` 包含 DPID_ALARMRECORD(0x65) 至 DPID_LOWBAT(0x75) 全部 17 个 DPID 常量
**And** 双平台常量值完全一致，Android 使用 `object`，iOS 使用 `enum`
**And** 所有常量有中文注释说明用途

---

### Story 1.3：CRC8 计算器实现

As a SDK 开发工程师，
I want 实现 CRC8 校验计算模块，
So that 帧构建和帧解析时可以准确计算和验证帧校验值。

**Acceptance Criteria:**

**Given** Story 1.2 常量已定义
**When** 实现 `CRC8Calculator`
**Then** 计算规则：从帧头第一字节（0x55）开始，所有字节累加和对 256 求余
**And** 验证：输入 `[0x55, 0xAA, 0x00, 0x00, 0x00, 0x01, 0x00]`，CRC8 结果为 `0x00`
**And** 验证：密钥包示例 `55 AA 00 00 00 02 07 74` 的 CRC8 结果为 `0x7C`
**And** 单元测试覆盖至少 5 个协议示例帧的 CRC8 验证
**And** 双平台实现结果完全一致

---

### Story 1.4：帧构建器实现

As a SDK 开发工程师，
I want 实现帧构建器，将业务数据封装为符合协议格式的二进制帧，
So that 所有下行指令可以统一通过帧构建器生成，保证格式正确。

**Acceptance Criteria:**

**Given** Story 1.2 常量和 Story 1.3 CRC8 已实现
**When** 实现 `FrameBuilder.build(cmd, data)`
**Then** 输出帧格式：`0x55 0xAA 0x00 [cmd] [lenHigh] [lenLow] [data...] [crc8]`
**And** 验证：`build(0x01, ByteArray(0))` 输出 `55 AA 00 01 00 00 00`
**And** 验证：`build(0xE1, byteArrayOf(0x00))` 输出 `55 AA 00 E1 00 01 00 E1`
**And** 数据长度超过 255 字节时，Len 高字节正确填充
**And** 单元测试覆盖协议文档中所有示例帧的构建验证

---

### Story 1.5：帧解析器实现

As a SDK 开发工程师，
I want 实现帧解析器，从 BLE notify 数据流中识别并解析完整的协议帧，
So that 设备上报的所有数据可以被正确解析为结构化帧对象。

**Acceptance Criteria:**

**Given** Story 1.2 常量和 Story 1.3 CRC8 已实现
**When** 实现 `FrameParser`
**Then** 能识别帧头 `0x55 0xAA`，解析版本、CMD、Len、Data、CRC8 字段
**And** CRC8 校验失败时静默丢弃该帧，记录 WARN 级别日志，不抛出异常（NFR12）
**And** 帧头不匹配时静默丢弃，不抛出异常
**And** 解析成功返回包含 `cmd`、`data` 字段的帧对象
**And** 单元测试覆盖：正常帧解析、CRC 错误帧、帧头错误帧、空数据帧

---

### Story 1.6：错误类型与枚举定义

As a 第三方开发者，
I want SDK 提供统一的错误类型和所有业务枚举，
So that 我可以通过类型安全的方式处理所有 SDK 错误和状态值。

**Acceptance Criteria:**

**Given** Story 1.1 项目结构已建立
**When** 实现 `BlueError`、`ConnectionState`、`MedicationStatus`、`LogLevel`、`VolumeLevel`、`SoundType`、`TimeFormat` 及数据模型 `AlarmInfo`、`MedicationRecord`、`DeviceInfo`
**Then** `BlueError` 包含：`notInitialized`、`notAuthenticated`、`authFailed`、`timeout`、`protocolError(code, message)`、`bleError(cause)`
**And** `ConnectionState` 包含：`DISCONNECTED`、`CONNECTING`、`CONNECTED`、`AUTHENTICATED`、`RECONNECTING`
**And** `MedicationStatus` 包含：`TAKEN`、`TIMEOUT`、`MISSED`、`EARLY`
**And** Android 使用 sealed class（BlueError）和 enum class，iOS 使用 enum
**And** iOS 所有公开类型通过 `@objc` 标注支持 Objective-C 调用（NFR18）
**And** Android 所有公开类型提供 Java 友好的调用方式（NFR17）

---

### Story 1.7：日志系统实现

As a 第三方开发者，
I want SDK 提供可配置的日志系统，支持日志级别控制和自定义日志处理器，
So that 我可以在调试时查看详细日志，在生产环境关闭日志，并将日志接入自己的日志系统。

**Acceptance Criteria:**

**Given** Story 1.6 枚举已定义
**When** 实现 `BlueLogger` 和 `LogFormatter`
**Then** 支持日志级别：NONE / ERROR / WARN / INFO / DEBUG，默认级别为 NONE
**And** `BlueSDK.setLogLevel(LogLevel.DEBUG)` 可动态修改日志级别（FR34）
**And** `BlueSDK.setLogHandler { level, tag, message -> }` 可注册自定义处理器（FR35）
**And** `LogFormatter` 在输出前将密钥值和 MAC 地址替换为 `***`（FR36、NFR07）
**And** 未注册自定义处理器时，Android 默认输出到 Logcat，iOS 默认输出到 os_log
**And** 单元测试验证：密钥值在任何日志级别下均不出现在日志输出中

---

### Story 1.8：SDK 生命周期管理

As a 第三方开发者，
I want 通过简单的初始化和销毁 API 管理 SDK 生命周期，
So that 我可以在应用启动时初始化 SDK，在应用退出时释放所有资源。

**Acceptance Criteria:**

**Given** Story 1.6 和 Story 1.7 已实现
**When** 实现 `BlueSDK` 单例入口、`initialize()` 和 `destroy()` 方法
**Then** Android：`BlueSDK.getInstance(context).initialize()` 完成初始化，耗时 ≤ 100ms（NFR04）
**And** iOS：`BlueSDK.shared.initialize()` 完成初始化，耗时 ≤ 100ms（NFR04）
**And** `destroy()` 释放所有内部资源，重置状态为初始值（FR33）
**And** 未调用 `initialize()` 时调用任何业务 API 返回 `BlueError.notInitialized`（FR32）
**And** SDK 不包含任何网络请求代码（NFR09）
**And** SDK 运行时内存占用 ≤ 5MB（NFR05）

---

## Epic 2：设备发现与连接管理

开发者可扫描、连接、断开 LX-PD02 设备，并接收连接状态变化事件，SDK 自动处理断线重连。

### Story 2.1：BLE 权限检查

As a 第三方开发者，
I want 在发起扫描前查询当前蓝牙权限状态，
So that 我可以在权限不足时引导用户授权，避免扫描失败。

**Acceptance Criteria:**

**Given** SDK 已初始化
**When** 调用 `BlueSDK.checkPermissions()`
**Then** 返回权限状态枚举：`GRANTED` / `DENIED` / `NOT_DETERMINED`（FR07）
**And** Android 12+ 检查 `BLUETOOTH_SCAN` 和 `BLUETOOTH_CONNECT` 权限
**And** Android 6~11 检查 `BLUETOOTH` 和 `ACCESS_FINE_LOCATION` 权限
**And** iOS 检查 `CBManagerAuthorization` 状态
**And** 该方法为同步调用，不触发系统权限弹窗

---

### Story 2.2：BLE 设备扫描

As a 第三方开发者，
I want 发起 BLE 扫描并接收过滤后的 LX-PD02 设备列表，
So that 我可以展示附近可连接的智能药盒设备供用户选择。

**Acceptance Criteria:**

**Given** SDK 已初始化且蓝牙权限已授权
**When** 调用 `BlueSDK.startScan(callback)` 发起扫描
**Then** SDK 自动过滤广播名前缀为 `LX-PD02` 的设备（FR01）
**And** 发现设备时通过回调返回设备信息（deviceId、deviceName、rssi）
**And** 首次发现设备的回调延迟 ≤ 2 秒（NFR03，设备在有效信号范围内）
**And** 调用 `BlueSDK.stopScan()` 可停止扫描
**And** 权限未授权时调用 `startScan()` 立即回调 `BlueError.permissionDenied`
**And** 重复调用 `startScan()` 不会启动多个扫描实例

---

### Story 2.3：BLE 设备连接

As a 第三方开发者，
I want 指定设备 ID 发起连接请求，并接收连接结果回调，
So that 我可以与用户选择的智能药盒建立通信连接。

**Acceptance Criteria:**

**Given** SDK 已初始化且已扫描到目标设备
**When** 调用 `BlueSDK.connect(deviceId, listener)` 发起连接
**Then** 连接成功时回调 `onConnectionStateChanged(ConnectionState.CONNECTED)`（FR04）
**And** 连接失败时回调 `onConnectionStateChanged(ConnectionState.DISCONNECTED)` 并附带 `BlueError`
**And** 连接过程中状态为 `CONNECTING`，通过 `getConnectionState()` 可同步查询（FR06）
**And** 正常信号环境下连接成功率 ≥ 95%（NFR10）
**And** 所有回调在主线程派发（ARCH-06）

---

### Story 2.4：连接状态机与主动断开

As a 第三方开发者，
I want 主动断开设备连接，并在任意时刻查询当前连接状态，
So that 我可以在用户退出页面时释放连接，并根据连接状态更新 UI。

**Acceptance Criteria:**

**Given** 设备已连接（`ConnectionState.CONNECTED` 或 `AUTHENTICATED`）
**When** 调用 `BlueSDK.disconnect()`
**Then** 连接断开，状态变为 `DISCONNECTED`，触发 `onConnectionStateChanged` 回调（FR03、FR04）
**And** `BlueSDK.getConnectionState()` 同步返回当前状态枚举值（FR06）
**And** 状态机包含 5 个状态：`DISCONNECTED`、`CONNECTING`、`CONNECTED`、`AUTHENTICATED`、`RECONNECTING`
**And** 状态转换通过统一入口执行，不允许直接赋值（ARCH-07）

---

### Story 2.5：断线自动重连

As a 第三方开发者，
I want SDK 在连接意外断开后自动尝试重连，
So that 我无需自己实现重连逻辑，用户体验更稳定。

**Acceptance Criteria:**

**Given** 设备已认证连接（`ConnectionState.AUTHENTICATED`）
**When** 连接意外断开（非主动调用 `disconnect()`）
**Then** SDK 自动进入 `RECONNECTING` 状态，触发 `onConnectionStateChanged(RECONNECTING)` 回调（FR04、FR05）
**And** 重连采用指数退避策略：第 1 次 2s、第 2 次 4s、第 3 次 8s 后重试
**And** 最多重试 5 次，超限后状态变为 `DISCONNECTED`，回调通知上层（FR05）
**And** 重连成功后状态恢复为 `CONNECTED`（需重新认证），触发 `onConnectionStateChanged(CONNECTED)`
**And** 5 次重试内重连成功率 ≥ 90%（NFR11）
**And** 主动调用 `disconnect()` 不触发自动重连

---

## Epic 3：身份认证与安全绑定

开发者可完成设备绑定认证，SDK 自动计算密钥包并处理认证失败断开，未认证时拒绝业务指令。

### Story 3.1：密钥包计算与发送

As a 第三方开发者，
I want SDK 自动基于手机 MAC 和设备 MAC 计算密钥包并发送给设备，
So that 我无需了解密钥算法细节，直接调用认证 API 即可完成设备绑定。

**Acceptance Criteria:**

**Given** 设备已连接（`ConnectionState.CONNECTED`）
**When** 调用 `BlueSDK.authenticate(phoneMac, deviceMac, callback)`
**Then** SDK 内部计算密钥：手机 MAC 6 字节 + 设备 MAC 6 字节逐字节累加，取低字节（FR08）
**And** 验证：手机 MAC `C7 50 B2 AA C3 F3` + 设备 MAC `A6 C0 82 00 A1 C2`，密钥包数据为 `07 74`
**And** SDK 构建并发送密钥帧：`55 AA 00 00 00 02 [key_high] [key_low] [crc8]`
**And** 密钥值在任何日志级别下均不输出明文（FR36、NFR06、NFR07）
**And** 所有密钥计算仅在内存中执行，不写入任何持久化存储（NFR06）

---

### Story 3.2：认证结果处理与状态守卫

As a 第三方开发者，
I want 接收认证结果回调，并在认证失败时 SDK 自动断开连接，
So that 我可以根据认证结果决定后续操作，无需手动处理认证失败的断开逻辑。

**Acceptance Criteria:**

**Given** 密钥包已发送（Story 3.1 完成）
**When** 设备返回认证应答帧
**Then** 认证成功（设备返回 `55 AA 00 00 00 01 01 01`）时：状态变为 `AUTHENTICATED`，触发 `onAuthResult(success=true)` 回调（FR09）
**And** 认证失败（设备返回 `55 AA 00 00 00 01 00 00`）时：SDK 自动断开连接，触发 `onAuthResult(success=false)` 并附带 `BlueError.authFailed`（FR10）
**And** 认证失败后状态变为 `DISCONNECTED`，触发 `onConnectionStateChanged(DISCONNECTED)`
**And** 未完成认证（状态非 `AUTHENTICATED`）时调用任何业务 API（如 `setAlarm`）立即返回 `BlueError.notAuthenticated`（FR11）
**And** 认证超时（5 秒内无应答）触发 `BlueError.timeout` 回调（NFR02）

---

## Epic 4：设备信息与时间同步

开发者可查询设备基础信息，SDK 自动响应设备时间同步请求并下发当前系统时间。

### Story 4.1：查询设备信息

As a 第三方开发者，
I want 查询已连接设备的基础信息（如固件版本），
So that 我可以在 APP 中展示设备信息或进行版本兼容性判断。

**Acceptance Criteria:**

**Given** 设备已认证（`ConnectionState.AUTHENTICATED`）
**When** 调用 `BlueSDK.queryDeviceInfo(callback)`
**Then** SDK 发送查询帧：`55 AA 00 01 00 00 00`（FR12）
**And** 设备应答后回调返回 `DeviceInfo` 对象，包含固件版本字符串（如 `1.0.0`）
**And** 5 秒内无应答触发 `BlueError.timeout` 回调（NFR02）
**And** 指令端到端延迟 ≤ 3 秒（NFR01，正常信号环境）

---

### Story 4.2：时间同步响应

As a 第三方开发者，
I want 订阅设备时间同步请求事件，并在收到请求时下发当前系统时间，
So that 设备时钟与手机时钟保持同步，闹钟提醒时间准确。

**Acceptance Criteria:**

**Given** 设备已认证（`ConnectionState.AUTHENTICATED`）且已注册监听器
**When** 设备发送时间同步请求帧（`55 AA 00 E1 00 01 00 E1`）
**Then** SDK 触发 `onTimeSyncRequested()` 回调通知上层（FR13）
**And** 调用 `BlueSDK.syncTime(date)` 下发当前系统时间（FR14）
**And** 下发帧格式：`55 AA 00 E1 00 0B [年高] [年低] [月] [日] [时] [分] [秒] [星期] [时区高] [时区低] [crc8]`
**And** 验证：2024 年 12 月 30 日 15:52:31 星期一 UTC+8，帧数据为 `55 AA 00 E1 00 0B 00 00 01 0C 1E 0F 34 1F 01 03 20 9C`

---

## Epic 5：闹钟管理

开发者可完整管理设备上的 7 个闹钟槽位（设置/删除/清空），并接收设备端闹钟变更上报。

### Story 5.1：设置闹钟

As a 第三方开发者，
I want 设置指定槽位的闹钟（时间、周期、星期掩码），
So that 用户可以在 APP 上配置每天的用药提醒时间。

**Acceptance Criteria:**

**Given** 设备已认证（`ConnectionState.AUTHENTICATED`）
**When** 调用 `BlueSDK.setAlarm(index, hour, minute, weekMask, callback)`，index 范围 1~7
**Then** SDK 构建并发送设置闹钟帧，DPID 为 `0x66 + (index-1)`（FR15）
**And** 验证：设置闹钟 1 为 12:00 每天，发送帧 `55 AA 00 06 00 0B 66 00 00 07 01 0C 00 7F 00 00 00 09`
**And** 验证：设置闹钟 2 为 15:30 每天，发送帧 `55 AA 00 06 00 0B 67 00 00 07 01 0F 1E 7F 00 00 00 2B`
**And** 设备应答成功后触发 `onAlarmSet(index, alarmInfo)` 回调
**And** index 超出 1~7 范围时立即返回 `BlueError.invalidParameter`
**And** 5 秒内无应答触发 `BlueError.timeout`（NFR02）

---

### Story 5.2：删除闹钟

As a 第三方开发者，
I want 删除指定槽位的闹钟，
So that 用户可以取消不再需要的用药提醒。

**Acceptance Criteria:**

**Given** 设备已认证（`ConnectionState.AUTHENTICATED`）
**When** 调用 `BlueSDK.deleteAlarm(index, callback)`
**Then** SDK 发送删除帧，数据字段全填 `0xFF`（FR16）
**And** 验证：删除闹钟 7，发送帧 `55 AA 00 06 00 0B 6C 00 00 07 FF FF FF FF FF FF FF 7C`
**And** 设备应答成功后触发 `onAlarmDeleted(index)` 回调
**And** 5 秒内无应答触发 `BlueError.timeout`

---

### Story 5.3：清空所有闹钟

As a 第三方开发者，
I want 一次性清空设备上所有闹钟，
So that 用户可以重置设备的所有提醒配置。

**Acceptance Criteria:**

**Given** 设备已认证（`ConnectionState.AUTHENTICATED`）
**When** 调用 `BlueSDK.clearAllAlarms(callback)`
**Then** SDK 发送清空指令，DPID 为 `0x70`，数据值为 `0x01`（FR17）
**And** 设备应答成功后触发 `onAllAlarmsCleared()` 回调
**And** 5 秒内无应答触发 `BlueError.timeout`

---

### Story 5.4：接收设备端闹钟上报

As a 第三方开发者，
I want 接收设备端主动上报的闹钟变更事件，
So that 当用户在设备上直接修改闹钟时，APP 可以同步最新配置。

**Acceptance Criteria:**

**Given** 设备已认证且已注册监听器
**When** 设备主动上报闹钟变更帧（CMD=0x07，DPID=0x66~0x6C）
**Then** SDK 解析上报帧并触发 `onAlarmUpdated(index, alarmInfo)` 回调（FR18）
**And** 回调中的 `AlarmInfo` 包含完整字段：hour、minute、weekMask、advanceStatus（FR19）
**And** 验证：设备上报 `55 AA 00 07 00 0B 66 00 00 07 01 07 00 7F 00 00 00 05`，解析为闹钟 1，07:00，每天
**And** 上报帧不经过指令队列，直接路由到事件分发器（ARCH-05）
**And** 回调在主线程派发（ARCH-06）

---

## Epic 6：用药事件与记录

上层应用可接收完整的用药事件流（响铃→取药/超时/漏服），获取语义化用药状态和带时间戳的用药记录。

### Story 6.1：闹钟响铃与超时事件

As a 第三方开发者，
I want 接收闹钟开始响铃和超时未取药事件，
So that APP 可以在适当时机推送通知提醒用户取药。

**Acceptance Criteria:**

**Given** 设备已认证且已注册监听器
**When** 设备上报闹钟响铃帧（CMD=0x07，DPID=0x68，byte9=0x01）
**Then** SDK 触发 `onAlarmRinging(alarmIndex, alarmInfo)` 回调（FR20）
**And** 当设备上报超时帧（byte9=0x02）时，SDK 触发 `onAlarmTimeout(alarmIndex, alarmInfo)` 回调（FR21）
**And** 验证：`55 AA 00 07 00 0B 68 00 00 07 01 00 12 7F 01 00 01 14` 解析为闹钟 3 开始响铃
**And** 回调携带完整的 `AlarmInfo` 对象，包含闹钟槽位信息
**And** 用药事件上报不丢失，回调触发前完成帧完整性校验（NFR14）

---

### Story 6.2：用药结果事件

As a 第三方开发者，
I want 接收语义化的用药结果事件（按时取药/超时取药/漏服/提前取药），
So that APP 可以准确记录用户的用药依从性数据。

**Acceptance Criteria:**

**Given** 设备已认证且已注册监听器
**When** 设备上报用药结果帧（CMD=0x07，DPID=0x68，byte9 为状态值）
**Then** SDK 解析并触发 `onMedicationResult(alarmIndex, status)` 回调（FR22）
**And** `MedicationStatus` 枚举映射：`0x01` → `TAKEN`（按时取药）、`0x02` → `TIMEOUT`（超时取药）、`0x03` → `MISSED`（漏服）、`0x04` → `EARLY`（提前取药）
**And** 回调携带语义化状态枚举，不暴露原始字节值
**And** 所有异常帧静默丢弃，不触发崩溃（NFR12）

---

### Story 6.3：用药记录上报

As a 第三方开发者，
I want 接收带时间戳的完整用药记录上报，
So that APP 可以构建用户的历史用药记录。

**Acceptance Criteria:**

**Given** 设备已认证且已注册监听器
**When** 设备上报用药记录帧（CMD=0x07，DPID=0x65）
**Then** SDK 解析并触发 `onMedicationRecordReported(record)` 回调（FR23）
**And** `MedicationRecord` 包含：timestamp（年月日时分）、alarmIndex、status（`MedicationStatus` 枚举）
**And** 验证：`55 AA 00 07 00 0F 65 00 00 0B 68 07 E9 0B 01 00 12 00 12 01 00 0A` 解析为 2025年11月1日 00:18，闹钟3，按时取药
**And** 用药记录上报不丢失（NFR14）

---

### Story 6.4：下发用药结果通知

As a 第三方开发者，
I want 向设备下发用药结果通知指令，
So that APP 可以通知设备当前用药状态（如通知设备停止响铃）。

**Acceptance Criteria:**

**Given** 设备已认证（`ConnectionState.AUTHENTICATED`）
**When** 调用 `BlueSDK.sendMedicationNotification(status, callback)`
**Then** SDK 构建并发送通知帧，DPID 为 `0x6F`（FR24）
**And** 状态映射：`0` 等待响铃、`1` 通知开始响铃、`2` 通知错过服药、`3` 通知服药成功
**And** 设备应答后触发成功回调
**And** 5 秒内无应答触发 `BlueError.timeout`

---

## Epic 7：音频与系统设置

开发者可配置设备音量、铃声类型、静音、提醒持续时长、时间格式等系统参数，并接收设备端变更上报。

### Story 7.1：音量设置

As a 第三方开发者，
I want 设置设备提醒音量（低/中/高），
So that 用户可以根据环境调整药盒的提醒音量。

**Acceptance Criteria:**

**Given** 设备已认证（`ConnectionState.AUTHENTICATED`）
**When** 调用 `BlueSDK.setVolume(level, callback)`，level 为 `VolumeLevel` 枚举
**Then** SDK 发送音量设置帧，DPID 为 `0x6E`（FR25）
**And** 验证：低音量发送 `55 AA 00 06 00 05 6E 04 00 01 01 7E`，设备应答 `55 AA 03 07 00 05 6E 04 00 01 01 82`
**And** 验证：中音量发送 `55 AA 00 06 00 05 6E 04 00 01 02 7F`
**And** 验证：高音量发送 `55 AA 00 06 00 05 6E 04 00 01 03 80`
**And** 设备应答成功后触发 `onVolumeSet(level)` 回调
**And** 5 秒内无应答触发 `BlueError.timeout`

---

### Story 7.2：铃声类型设置与上报

As a 第三方开发者，
I want 设置设备铃声类型，并接收设备端铃声类型变更上报，
So that 用户可以选择喜欢的提醒铃声，且设备端修改也能同步到 APP。

**Acceptance Criteria:**

**Given** 设备已认证且已注册监听器
**When** 调用 `BlueSDK.setSoundType(type, callback)`，type 为 `SoundType` 枚举
**Then** SDK 发送铃声设置帧，DPID 为 `0x6F`（FR26）
**And** 验证：类型 A 发送 `55 AA 00 06 00 05 6F 04 00 01 01 7E`
**And** 当设备端主动上报铃声变更（CMD=0x07，DPID=0x6D）时，触发 `onSoundTypeChanged(type)` 回调（FR27）
**And** 验证：设备上报 `55 AA 00 07 00 05 6D 04 00 01 01 7E` 解析为铃声类型 A
**And** 静音上报（byte=0x00）映射为 `SoundType.MUTE`

---

### Story 7.3：静音与提醒持续时长设置

As a 第三方开发者，
I want 设置当前闹钟静音状态和提醒持续时长，
So that 用户可以临时静音当前提醒，并自定义提醒持续时间。

**Acceptance Criteria:**

**Given** 设备已认证（`ConnectionState.AUTHENTICATED`）
**When** 调用 `BlueSDK.setSilence(enabled, callback)` 设置静音
**Then** SDK 发送静音帧，DPID 为 `0x74`，`enabled=true` 值为 `0x01`，`false` 为 `0x00`（FR28）
**And** 调用 `BlueSDK.setAlertDuration(minutes, callback)` 设置持续时长
**Then** SDK 发送持续时长帧，DPID 为 `0x70`（FR29）
**And** 验证：设置 2 分钟，发送帧 `55 AA 00 06 00 08 70 02 00 04 00 00 00 05 88`
**And** 两个指令均在 5 秒内无应答时触发 `BlueError.timeout`

---

### Story 7.4：时间格式设置与上报

As a 第三方开发者，
I want 设置设备时间显示格式（12/24 小时制），并接收设备端格式变更上报，
So that 用户可以选择习惯的时间显示方式，且设备端修改也能同步到 APP。

**Acceptance Criteria:**

**Given** 设备已认证且已注册监听器
**When** 调用 `BlueSDK.setTimeFormat(format, callback)`，format 为 `TimeFormat` 枚举
**Then** SDK 发送时间格式帧，DPID 为 `0x73`（FR30）
**And** 验证：24 小时制发送 `55 AA 00 06 00 05 73 04 00 01 01 84`
**And** 验证：12 小时制发送 `55 AA 00 06 00 05 73 04 00 01 00 83`
**And** 当设备端主动上报时间格式变更（CMD=0x07，DPID=0x73）时，触发 `onTimeFormatChanged(format)` 回调（FR31）
**And** 5 秒内无应答触发 `BlueError.timeout`
