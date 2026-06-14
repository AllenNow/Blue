---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments: ["_bmad-output/planning-artifacts/prd.md"]
workflowType: 'architecture'
project_name: 'Blue'
user_name: 'Allen'
date: '2026-05-06'
lastStep: 8
status: 'complete'
completedAt: '2026-05-07'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**功能需求（FR01~FR36，8 个能力域）：**

| 能力域 | FR 数量 | 架构含义 |
|---|---|---|
| 设备发现与连接管理 | 7 | BLE 扫描器、连接状态机、自动重连调度器 |
| 身份认证与安全绑定 | 4 | 密钥计算模块、认证状态守卫 |
| 设备信息与时间同步 | 3 | 请求-响应指令处理器 |
| 闹钟管理 | 5 | 双向指令（下发+上报）、7槽位数据模型 |
| 用药事件与记录 | 5 | 事件状态机（4种用药状态）、上报解析器 |
| 音频与提醒设置 | 5 | 设备配置指令集 |
| 系统设置 | 2 | 设备配置指令集 |
| SDK 生命周期与开发者工具 | 5 | 单例管理、日志系统、线程调度 |

**非功能需求的架构驱动力：**
- **性能（NFR01~05）**：指令超时 5s、重连退避、初始化 ≤100ms → 异步指令队列 + 超时调度器
- **安全（NFR06~09）**：密钥不落盘、无网络请求 → 内存态密钥管理，零网络依赖
- **可靠性（NFR10~14）**：连接成功率 ≥95%、崩溃率 0 → 状态机守卫、异常隔离层
- **兼容性（NFR15~19）**：双平台、零第三方依赖、Kotlin/Java + Swift/ObjC 双接口 → 纯系统 API 实现
- **可维护性（NFR20~22）**：SemVer、向后兼容 → 公开 API 稳定层设计

**规模与复杂度：**
- 主要技术域：移动端原生 SDK（双平台）
- 复杂度级别：高
- 核心复杂性来源：私有二进制协议解析、双向通信状态机、双平台镜像实现、零依赖约束
- 预估架构组件数：~10 个核心模块（双平台各自独立实现）

### 技术约束与依赖

- **协议层**：固定的私有帧格式（0x55 0xAA + 版本 + CMD + Len高/低 + Data + CRC8），不可变更
- **认证机制**：手机 MAC + 设备 MAC 字节累加，算法固定
- **平台约束**：Android 仅用 BluetoothLE API，iOS 仅用 CoreBluetooth，零第三方 BLE 库
- **线程约束**：回调必须主线程派发（默认），支持可选线程配置
- **内存约束**：运行时 ≤5MB，所有状态内存态，无持久化

### 跨切面关注点

1. **错误处理与异常隔离**：所有层级的异常必须被捕获并转换为 `BlueError`，不允许向上层抛出未处理异常
2. **线程安全**：BLE 回调来自系统线程，业务回调需派发到主线程，内部状态需线程安全访问
3. **状态一致性**：连接状态、认证状态、指令队列状态必须保持一致，任何状态转换需原子操作
4. **日志脱敏**：贯穿所有模块，密钥/MAC 值在任何日志路径上均不输出明文
5. **双平台镜像**：Android 和 iOS 的模块划分、API 命名、状态枚举必须保持对称一致

---

## Starter Template Evaluation

### 主要技术域

原生移动端 SDK（双平台独立实现），不适用通用脚手架工具。

### Android SDK 项目起点

**初始化方式：** Android Studio → New Project → Android Library

```
blue-sdk-android/
├── blue-sdk/                    # SDK 主模块（AAR 产物）
│   ├── src/main/kotlin/
│   │   └── com/blue/sdk/
│   └── build.gradle.kts
├── app/                         # Demo 工程（集成验证）
│   └── src/main/kotlin/
└── build.gradle.kts
```

**已确定的技术决策：**
- 语言：Kotlin（主）/ Java 兼容
- 构建工具：Gradle（Kotlin DSL）
- 最低 SDK：API Level 21
- 分发格式：AAR
- 文档生成：KDoc + Dokka
- 代码风格：ktlint

### iOS SDK 项目起点

**初始化方式：** Xcode → New Project → Framework

```
blue-sdk-ios/
├── BlueSDK/                     # SDK 主模块（XCFramework 产物）
│   ├── Sources/BlueSDK/
│   └── BlueSDK.podspec
├── BlueSDKDemo/                 # Demo 工程（集成验证）
│   └── BlueSDKDemo/
├── Package.swift                # Swift Package Manager 支持
└── BlueSDK.xcworkspace
```

**已确定的技术决策：**
- 语言：Swift（主）/ Objective-C 兼容
- 构建工具：Xcode + xcodebuild
- 最低版本：iOS 13.0
- 分发格式：XCFramework
- 文档生成：DocC
- 代码风格：SwiftLint

---

## Core Architectural Decisions

### 决策优先级分析

**阻塞实现的关键决策（已确定）：**
- 整体分层架构：三层（Public API → Business Logic → BLE Transport）
- BLE 通信层：指令队列 + 请求-响应匹配
- 协议帧编解码：FrameBuilder + FrameParser + CRC8Calculator
- 状态机：5 状态显式状态机
- 线程模型：内部多线程，回调主线程派发

**影响架构形态的重要决策（已确定）：**
- 公开 API 风格：Listener/Delegate 回调主 + 可选响应式扩展
- 错误处理：BlueError 枚举统一模型
- 日志系统：分级日志 + 可插拔处理器

**语言决策（已确定）：**
- Android：Kotlin 主 / Java 兼容
- iOS：Swift 主 / Objective-C 兼容（通过 `@objc` 标注暴露）

### 分层架构模式

**决策：三层架构（Public API → Business Logic → BLE Transport）**

```
┌─────────────────────────────────────┐
│         Public API Layer            │  ← 开发者直接调用，稳定不变
│  BlueSDK / BlueSDKDelegate          │
├─────────────────────────────────────┤
│       Business Logic Layer          │  ← 状态机、认证、闹钟管理
│  ConnectionManager / AuthManager    │
│  AlarmManager / MedicationManager   │
├─────────────────────────────────────┤
│       BLE Transport Layer           │  ← 协议编解码、帧收发
│  BLEScanner / BLEConnector          │
│  FrameBuilder / FrameParser / CRC8  │
└─────────────────────────────────────┘
         ↕ 系统 BLE 框架
   Android: BluetoothLE API
   iOS: CoreBluetooth
```

**理由：** 公开 API 层与传输层解耦，协议变更只影响传输层，不影响上层业务逻辑和开发者 API。

### BLE 通信层设计

**决策：指令队列 + 请求-响应匹配**

- 所有下行指令进入串行队列，保证顺序执行
- 每条指令携带 CMD 标识，等待设备应答帧匹配
- 超时 5 秒未收到应答触发 `BlueError.timeout`，自动重试最多 3 次
- 上行上报帧（设备主动发送）走独立的事件分发路径，不经过指令队列

```
下行：[指令队列] → BLE Write → 等待应答(5s超时) → 回调
上行：BLE Notify → [帧解析] → [CMD路由] → 事件回调
```

### 协议帧编解码

**决策：FrameBuilder + FrameParser + CRC8Calculator 三个独立模块**

```kotlin
// Android 示例
object FrameBuilder {
    fun build(cmd: Byte, data: ByteArray): ByteArray {
        // 0x55 0xAA + version + cmd + lenHigh + lenLow + data + crc8
    }
}

object CRC8Calculator {
    fun calculate(data: ByteArray): Byte {
        // 从帧头第一字节累加和对256求余
    }
}
```

- `FrameParser` 负责从 BLE notify 数据流中识别完整帧（处理粘包/分包）
- `CRC8Calculator` 独立可测试
- `FrameBuilder` 构建下行帧，`FrameParser` 解析上行帧

### 连接状态机

**决策：显式状态机，5 个状态**

```
DISCONNECTED
    ↓ startScan() + connect()
CONNECTING
    ↓ 连接成功
CONNECTED（未认证）
    ↓ sendAuthKey() 认证成功
AUTHENTICATED（可执行业务指令）
    ↓ 断线
RECONNECTING（自动重连，指数退避 2s/4s/8s，最多5次）
    ↓ 重连失败超限
DISCONNECTED
```

- 状态转换原子操作，线程安全
- 未到达 `AUTHENTICATED` 状态时调用业务 API 返回 `BlueError.notAuthenticated`
- 状态变化通过 `onConnectionStateChanged` 回调通知上层

### 线程模型

**决策：内部多线程，回调主线程派发**

| 线程 | 职责 |
|---|---|
| BLE 系统线程 | 接收系统 BLE 回调（不可控） |
| SDK 内部工作线程 | 帧解析、状态机处理、指令队列调度 |
| 主线程（UI 线程） | 所有公开回调派发（默认） |

- Android：`Handler(Looper.getMainLooper())` 派发回调
- iOS：`DispatchQueue.main.async` 派发回调
- 提供可选 `callbackQueue` 参数供开发者自定义

### 公开 API 设计风格

**决策：Listener/Delegate 回调（主）+ 可选响应式扩展（次）**

- Android：`BlueSDKListener` 接口 + 可选 `Flow` 扩展（独立扩展模块）
- iOS：`BlueSDKDelegate` 协议 + 可选 `Combine` 扩展（独立扩展模块）
- 核心 SDK 零响应式框架依赖，扩展模块按需引入

### 错误处理统一模型

**决策：BlueError 枚举，覆盖所有错误场景**

```kotlin
// Android
sealed class BlueError {
    object NotInitialized : BlueError()
    object NotAuthenticated : BlueError()
    object AuthFailed : BlueError()
    object Timeout : BlueError()
    data class ProtocolError(val code: Int, val message: String) : BlueError()
    data class BleError(val cause: Throwable) : BlueError()
}
```

```swift
// iOS
public enum BlueError: Error {
    case notInitialized
    case notAuthenticated
    case authFailed
    case timeout
    case protocolError(code: Int, message: String)
    case bleError(Error)
}
```

### 日志系统

**决策：分级日志 + 可插拔处理器**

- 内置默认处理器（Android Logcat / iOS os_log）
- 支持自定义 `LogHandler` 接口接管日志
- 日志脱敏在 `LogFormatter` 层统一处理，密钥/MAC 替换为 `***`

### 双平台 API 对称性约定

| 概念 | Android | iOS |
|---|---|---|
| SDK 入口 | `BlueSDK.getInstance(context)` | `BlueSDK.shared` |
| 事件监听 | `BlueSDKListener` 接口 | `BlueSDKDelegate` 协议 |
| 错误类型 | `BlueError` sealed class | `BlueError` enum |
| 连接状态 | `ConnectionState` enum | `ConnectionState` enum |
| 用药状态 | `MedicationStatus` enum | `MedicationStatus` enum |
| 闹钟模型 | `AlarmInfo` data class | `AlarmInfo` struct |

---

## Implementation Patterns & Consistency Rules

### 潜在冲突点识别

识别出 **6 个** AI Agent 可能产生不一致实现的区域：命名约定、模块结构、帧协议实现、状态机实现、回调派发、错误处理。

### 命名约定

**模块命名（双平台对称）：**

| 模块职责 | Android 类名 | iOS 类名 |
|---|---|---|
| SDK 入口 | `BlueSDK` | `BlueSDK` |
| BLE 扫描 | `BLEScanner` | `BLEScanner` |
| BLE 连接 | `BLEConnector` | `BLEConnector` |
| 帧构建 | `FrameBuilder` | `FrameBuilder` |
| 帧解析 | `FrameParser` | `FrameParser` |
| CRC 计算 | `CRC8Calculator` | `CRC8Calculator` |
| 连接管理 | `ConnectionManager` | `ConnectionManager` |
| 认证管理 | `AuthManager` | `AuthManager` |
| 闹钟管理 | `AlarmManager` | `AlarmManager` |
| 用药事件管理 | `MedicationManager` | `MedicationManager` |
| 日志系统 | `BlueLogger` | `BlueLogger` |

**枚举命名（双平台对称）：**

```kotlin
// Android - Kotlin
enum class ConnectionState { DISCONNECTED, CONNECTING, CONNECTED, AUTHENTICATED, RECONNECTING }
enum class MedicationStatus { TAKEN, TIMEOUT, MISSED, EARLY }
enum class LogLevel { NONE, ERROR, WARN, INFO, DEBUG }
enum class VolumeLevel { LOW, MEDIUM, HIGH }
enum class SoundType { TYPE_A, TYPE_B, TYPE_C }
enum class TimeFormat { HOUR_12, HOUR_24 }
```

```swift
// iOS - Swift
public enum ConnectionState { case disconnected, connecting, connected, authenticated, reconnecting }
public enum MedicationStatus { case taken, timeout, missed, early }
public enum LogLevel { case none, error, warn, info, debug }
public enum VolumeLevel { case low, medium, high }
public enum SoundType { case typeA, typeB, typeC }
public enum TimeFormat { case hour12, hour24 }
```

**数据模型命名：**

```kotlin
// Android
data class AlarmInfo(val index: Int, val hour: Int, val minute: Int, val weekMask: Int, val advanceStatus: Int)
data class MedicationRecord(val timestamp: Long, val alarmIndex: Int, val status: MedicationStatus)
data class DeviceInfo(val firmwareVersion: String)
```

```swift
// iOS
public struct AlarmInfo { let index: Int; let hour: Int; let minute: Int; let weekMask: Int; let advanceStatus: Int }
public struct MedicationRecord { let timestamp: TimeInterval; let alarmIndex: Int; let status: MedicationStatus }
public struct DeviceInfo { let firmwareVersion: String }
```

### 帧协议实现规则

**帧格式常量（所有 Agent 必须使用，禁止魔法数字）：**

```kotlin
// Android
object FrameConstants {
    const val HEADER_BYTE1: Byte = 0x55.toByte()
    const val HEADER_BYTE2: Byte = 0xAA.toByte()
    const val PROTOCOL_VERSION: Byte = 0x00
    const val MIN_FRAME_LENGTH = 7
}

object CommandCode {
    const val QUERY_DEVICE_INFO: Byte = 0x01
    const val TIME_SYNC: Byte = 0xE1.toByte()
    const val SEND_COMMAND: Byte = 0x06
    const val DEVICE_REPORT: Byte = 0x07
}

object DPIDConstants {
    const val ALARM_RECORD: Byte = 0x65.toByte()
    const val ALARM_1: Byte = 0x66.toByte()
    // ... 0x67~0x75
}
```

**CRC8 计算规则（唯一实现，不允许变体）：**
- 从帧头第一字节（0x55）开始，到数据最后一字节，所有字节累加和对 256 求余
- 公式：`crc = (sum of bytes[0..6+Len-1]) % 256`

### 状态机实现规则

**状态转换必须通过统一入口，禁止直接修改状态字段：**

```kotlin
// 正确
connectionManager.transitionTo(ConnectionState.AUTHENTICATED)
// 禁止 ❌
_connectionState = ConnectionState.AUTHENTICATED
```

**状态守卫模式（所有业务 API 必须检查）：**

```kotlin
// Android
private fun requireAuthenticated(): BlueError? =
    if (connectionState != ConnectionState.AUTHENTICATED) BlueError.NotAuthenticated else null

fun setAlarm(index: Int, hour: Int, minute: Int, weekMask: Int, callback: (BlueError?) -> Unit) {
    requireAuthenticated()?.let { callback(it); return }
    // 执行业务逻辑
}
```

### 回调派发规则

**所有公开回调必须通过统一派发器，禁止直接调用：**

```kotlin
// Android - 正确
callbackDispatcher.dispatch { listener?.onAlarmRinging(alarmInfo) }
// 禁止 ❌
listener?.onAlarmRinging(alarmInfo)
```

```swift
// iOS - 正确
callbackDispatcher.dispatch { [weak self] in
    self?.delegate?.blueSDK(self!, didReceiveAlarmRinging: alarmInfo)
}
```

### 错误处理规则

**所有内部异常必须被捕获并转换为 BlueError：**

```kotlin
// 正确
try {
    bleConnector.write(FrameBuilder.build(cmd, data))
} catch (e: Exception) {
    callback(BlueError.BleError(e))
}
// 禁止 ❌ 未捕获异常向上层抛出
```

**日志脱敏规则（所有日志调用必须经过 BlueLogger）：**

```kotlin
BlueLogger.debug("Auth key sent: ***")   // 正确
Log.d("BlueSDK", "Auth key: ${key}")     // 禁止 ❌
```

### 指令队列规则

- 同一时刻只允许一条指令在等待应答（串行队列）
- 超时 5s 后自动重试，最多重试 3 次，超限回调 `BlueError.Timeout`
- 设备主动上报帧（CMD=0x07）不经过指令队列，直接路由到事件分发器

### 所有 Agent 必须遵守

1. **不引入任何第三方库**——零外部依赖，仅使用系统 BLE 框架
2. **不直接操作状态字段**——所有状态变更通过状态机入口
3. **不在非主线程调用公开回调**——所有回调通过 `callbackDispatcher` 派发
4. **不输出密钥/MAC 明文日志**——所有日志通过 `BlueLogger`，脱敏在 `LogFormatter` 处理
5. **不抛出未捕获异常**——所有异常转换为 `BlueError` 通过回调返回
6. **不使用魔法数字**——所有协议常量定义在 `FrameConstants` / `CommandCode` / `DPIDConstants`

---

## Project Structure & Boundaries

### Android SDK 完整目录结构

```
blue-sdk-android/
├── README.md
├── CHANGELOG.md
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
├── .gitignore
│
├── blue-sdk/                           # SDK 主模块（产物：AAR）
│   ├── build.gradle.kts
│   ├── consumer-rules.pro
│   └── src/
│       ├── main/
│       │   ├── AndroidManifest.xml
│       │   └── kotlin/com/blue/sdk/
│       │       ├── BlueSDK.kt                  # 公开 API 入口（单例）
│       │       ├── BlueSDKListener.kt           # 公开事件回调接口
│       │       ├── model/
│       │       │   ├── AlarmInfo.kt
│       │       │   ├── MedicationRecord.kt
│       │       │   └── DeviceInfo.kt
│       │       ├── enums/
│       │       │   ├── ConnectionState.kt
│       │       │   ├── MedicationStatus.kt
│       │       │   ├── LogLevel.kt
│       │       │   ├── VolumeLevel.kt
│       │       │   ├── SoundType.kt
│       │       │   └── TimeFormat.kt
│       │       ├── error/
│       │       │   └── BlueError.kt
│       │       ├── transport/                   # BLE 传输层（internal）
│       │       │   ├── BLEScanner.kt
│       │       │   ├── BLEConnector.kt
│       │       │   ├── FrameBuilder.kt
│       │       │   ├── FrameParser.kt
│       │       │   ├── CRC8Calculator.kt
│       │       │   ├── CommandCode.kt
│       │       │   ├── DPIDConstants.kt
│       │       │   └── FrameConstants.kt
│       │       ├── manager/                     # 业务逻辑层（internal）
│       │       │   ├── ConnectionManager.kt
│       │       │   ├── AuthManager.kt
│       │       │   ├── AlarmManager.kt
│       │       │   ├── MedicationManager.kt
│       │       │   ├── DeviceManager.kt
│       │       │   └── AudioManager.kt
│       │       └── internal/                    # SDK 基础设施（internal）
│       │           ├── CommandQueue.kt
│       │           ├── CommandDispatcher.kt
│       │           ├── CallbackDispatcher.kt
│       │           ├── BlueLogger.kt
│       │           └── LogFormatter.kt
│       └── test/
│           └── kotlin/com/blue/sdk/
│               ├── transport/
│               │   ├── FrameBuilderTest.kt
│               │   ├── FrameParserTest.kt
│               │   └── CRC8CalculatorTest.kt
│               ├── manager/
│               │   ├── ConnectionManagerTest.kt
│               │   └── AuthManagerTest.kt
│               └── internal/
│                   └── CommandQueueTest.kt
│
└── app/                                # Demo 工程
    ├── build.gradle.kts
    └── src/main/kotlin/com/blue/demo/
        └── MainActivity.kt
```

### iOS SDK 完整目录结构

```
blue-sdk-ios/
├── README.md
├── CHANGELOG.md
├── Package.swift
├── BlueSDK.podspec
├── .gitignore
│
├── Sources/
│   └── BlueSDK/
│       ├── BlueSDK.swift               # 公开 API 入口（单例）
│       ├── BlueSDKDelegate.swift
│       ├── Model/
│       │   ├── AlarmInfo.swift
│       │   ├── MedicationRecord.swift
│       │   └── DeviceInfo.swift
│       ├── Enums/
│       │   ├── ConnectionState.swift
│       │   ├── MedicationStatus.swift
│       │   ├── LogLevel.swift
│       │   ├── VolumeLevel.swift
│       │   ├── SoundType.swift
│       │   └── TimeFormat.swift
│       ├── Error/
│       │   └── BlueError.swift
│       ├── Transport/                  # BLE 传输层（internal）
│       │   ├── BLEScanner.swift
│       │   ├── BLEConnector.swift
│       │   ├── FrameBuilder.swift
│       │   ├── FrameParser.swift
│       │   ├── CRC8Calculator.swift
│       │   ├── CommandCode.swift
│       │   ├── DPIDConstants.swift
│       │   └── FrameConstants.swift
│       ├── Manager/                    # 业务逻辑层（internal）
│       │   ├── ConnectionManager.swift
│       │   ├── AuthManager.swift
│       │   ├── AlarmManager.swift
│       │   ├── MedicationManager.swift
│       │   ├── DeviceManager.swift
│       │   └── AudioManager.swift
│       └── Internal/                  # SDK 基础设施（internal）
│           ├── CommandQueue.swift
│           ├── CommandDispatcher.swift
│           ├── CallbackDispatcher.swift
│           ├── BlueLogger.swift
│           └── LogFormatter.swift
│
├── Tests/
│   └── BlueSDKTests/
│       ├── Transport/
│       │   ├── FrameBuilderTests.swift
│       │   ├── FrameParserTests.swift
│       │   └── CRC8CalculatorTests.swift
│       ├── Manager/
│       │   ├── ConnectionManagerTests.swift
│       │   └── AuthManagerTests.swift
│       └── Internal/
│           └── CommandQueueTests.swift
│
└── BlueSDKDemo/
    └── BlueSDKDemo/
        └── ViewController.swift
```

### 架构边界定义

**公开 API 边界（对外稳定，不得破坏性变更）：**
- `BlueSDK`、`BlueSDKListener/Delegate`、`model/`、`enums/`、`error/` 下所有类型

**内部实现边界（对外不可见，可自由重构）：**
- `transport/`、`manager/`、`internal/` 下所有类型标记为 `internal`

**数据流方向：**
```
外部调用 → BlueSDK（公开层）→ Manager（业务层）→ Transport（传输层）→ 系统 BLE 框架
设备上报 → 系统 BLE 框架 → BLEConnector → FrameParser → CommandDispatcher → Manager → BlueSDK → 回调
```

### FR 到模块映射

| FR 能力域 | 主要模块 | 辅助模块 |
|---|---|---|
| FR01~07 设备发现与连接 | `BLEScanner` `BLEConnector` `ConnectionManager` | `CallbackDispatcher` |
| FR08~11 身份认证 | `AuthManager` | `FrameBuilder` `CRC8Calculator` |
| FR12~14 设备信息/时间同步 | `DeviceManager` | `CommandQueue` |
| FR15~19 闹钟管理 | `AlarmManager` | `CommandQueue` `CommandDispatcher` |
| FR20~24 用药事件 | `MedicationManager` | `CommandDispatcher` |
| FR25~29 音频设置 | `AudioManager` | `CommandQueue` |
| FR30~31 系统设置 | `AudioManager` | `CommandQueue` |
| FR32~36 SDK 生命周期/日志 | `BlueSDK` `BlueLogger` `LogFormatter` | `CallbackDispatcher` |

---

## Architecture Validation Results

### 一致性验证 ✅

**决策兼容性：**
- 三层架构与零依赖约束（NFR19）完全兼容——每层仅依赖系统 BLE 框架
- 指令队列串行模式与 5s 超时/3次重试（NFR01~02）直接对应，无冲突
- Listener/Delegate 回调模式与主线程派发线程模型天然兼容
- Swift 主 + ObjC 兼容通过 `@objc` 标注实现，不影响内部实现质量

**模式一致性：**
- 命名约定双平台对称，枚举值语义一致
- 所有错误路径统一收敛到 `BlueError`，无遗漏
- 日志脱敏规则贯穿所有模块，通过 `BlueLogger` 统一入口强制执行

**结构对齐：**
- 目录结构与三层架构完全对应（`transport/` → `manager/` → 公开 API）
- 公开/内部边界通过访问修饰符（`internal`）在语言层面强制执行

### 需求覆盖验证 ✅

**功能需求覆盖（FR01~FR36）：**

| 验证项 | 状态 |
|---|---|
| FR01~07 设备发现与连接 | ✅ `BLEScanner` + `ConnectionManager` 完整覆盖 |
| FR08~11 身份认证 | ✅ `AuthManager` + 状态机守卫覆盖 |
| FR12~14 设备信息/时间同步 | ✅ `DeviceManager` + `CommandQueue` 覆盖 |
| FR15~19 闹钟管理 | ✅ `AlarmManager` + 双向指令路径覆盖 |
| FR20~24 用药事件 | ✅ `MedicationManager` + `CommandDispatcher` 覆盖 |
| FR25~29 音频设置 | ✅ `AudioManager` 覆盖 |
| FR30~31 系统设置 | ✅ `AudioManager` 覆盖 |
| FR32~36 SDK 生命周期/日志 | ✅ `BlueSDK` + `BlueLogger` 覆盖 |

**非功能需求覆盖：**

| NFR 类别 | 架构支撑 | 状态 |
|---|---|---|
| 性能（NFR01~05） | 指令队列超时调度、指数退避重连、主线程非阻塞初始化 | ✅ |
| 安全（NFR06~09） | 内存态密钥、`LogFormatter` 脱敏、零网络依赖 | ✅ |
| 可靠性（NFR10~14） | 状态机守卫、异常隔离层、CRC 校验前置 | ✅ |
| 兼容性（NFR15~19） | 纯系统 API、`@objc` 标注、零第三方依赖 | ✅ |
| 可维护性（NFR20~22） | SemVer、公开 API 稳定层、CHANGELOG | ✅ |

### 实现就绪验证 ✅

- 所有关键决策已文档化，包含具体类名、枚举值、常量定义和代码示例
- 双平台目录树完整，每个文件职责明确，无模糊占位符
- 6 个冲突点全部覆盖，每条规则附有正确/错误示例

### Gap 分析

**无关键 Gap**——所有阻塞实现的决策已完成。

**次要 Gap（不阻塞，实现阶段补充）：**
- `CommandDispatcher` 的 CMD 路由表完整映射（实现时补充）
- `FrameParser` 的粘包/分包处理策略（实现时决策）
- Demo 工程的具体演示场景（实现时补充）

### 架构完整性检查清单

**需求分析**
- [x] 项目上下文深度分析
- [x] 规模与复杂度评估
- [x] 技术约束识别
- [x] 跨切面关注点映射

**架构决策**
- [x] 关键决策文档化（含代码示例）
- [x] 技术栈完整指定（语言、框架、工具）
- [x] 集成模式定义（指令队列、事件分发）
- [x] 性能考量已架构化

**实现模式**
- [x] 命名约定建立（双平台对称表）
- [x] 结构模式定义（三层架构）
- [x] 通信模式指定（回调派发规则）
- [x] 过程模式文档化（错误处理、日志脱敏）

**项目结构**
- [x] 完整目录结构定义（双平台）
- [x] 组件边界建立（public/internal）
- [x] 集成点映射（FR → 模块）
- [x] 需求到结构映射完成

### 架构就绪评估

**整体状态：** ✅ **READY FOR IMPLEMENTATION**

**置信度：** 高

**核心优势：**
- 三层架构清晰，边界通过语言访问修饰符强制执行
- 双平台 API 对称性约定完整，减少跨平台实现分歧
- 所有 Agent 必须遵守的 6 条规则覆盖最高风险冲突点
- FR 到模块的完整映射，实现时无需猜测

**未来增强方向：**
- 响应式扩展模块（Flow/Combine）可作为独立可选模块后续添加
- 多设备管理架构扩展（Growth 阶段）

### 实现交接指南

**AI Agent 实现指引：**
1. 严格遵循三层架构，不得跨层直接调用
2. 所有协议常量从 `FrameConstants` / `CommandCode` / `DPIDConstants` 引用
3. 所有状态变更通过状态机入口，不得直接赋值
4. 所有回调通过 `CallbackDispatcher` 派发到主线程
5. 所有异常转换为 `BlueError` 通过回调返回，不向上抛出

**首要实现优先级：**
1. `FrameConstants` + `CommandCode` + `DPIDConstants`（协议常量，零依赖）
2. `CRC8Calculator` + `FrameBuilder` + `FrameParser`（协议编解码，可独立测试）
3. `BLEScanner` + `BLEConnector`（BLE 传输层）
4. `ConnectionManager`（状态机）
5. `AuthManager`（认证）
6. `AlarmManager` + `MedicationManager` + `DeviceManager` + `AudioManager`（业务层）
7. `BlueSDK`（公开 API 入口，最后组装）
