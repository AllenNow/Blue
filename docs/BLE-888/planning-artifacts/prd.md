---
stepsCompleted: ["step-01-init", "step-02-discovery", "step-02b-vision", "step-02c-executive-summary", "step-03-success", "step-04-journeys", "step-05-domain", "step-06-innovation", "step-07-project-type", "step-08-scoping", "step-09-functional", "step-10-nonfunctional", "step-11-polish", "step-12-complete"]
releaseMode: single-release
inputDocuments: []
workflowType: 'prd'
classification:
  projectType: mobile-sdk
  domain: healthcare-iot
  complexity: high
  projectContext: greenfield
---

# Product Requirements Document - Blue

**Author:** Allen
**Date:** 2026-05-06

---

## Executive Summary

LX-PD02 蓝牙 SDK（项目代号：Blue）是专为 LX-PD02 智能药盒硬件设计的移动端原生通信与控制开发套件，同步支持 Android 和 iOS 双平台。SDK 完整封装 LX-PD02 私有蓝牙 5.0 通信协议，向上提供简洁、类型安全的高层 API，使第三方开发者无需了解底层帧结构、CRC 校验、密钥认证等协议细节，即可快速构建具备完整用药提醒闭环能力的移动应用。

目标用户群体涵盖三类场景：患者本人自主管理用药计划、家属或护理人员远程监护用药依从性、医疗机构对患者群体的用药行为追踪与管理。SDK 作为底层能力层，不限定上层应用形态，支持任意业务场景的灵活集成。

### What Makes This Special

LX-PD02 SDK 不是通用 BLE 工具库，而是针对 LX-PD02 协议深度定制的领域专属 SDK，其核心价值体现在三个层面：

1. **协议完整封装**：将私有二进制帧协议（帧头校验、16位长度字段、CRC8 累加校验、CMD 路由）完全内化为 SDK 内部实现，开发者调用层面零协议感知。

2. **用药状态机管理**：SDK 内部维护完整的用药事件状态机（等待响铃 → 开始响铃 → 超时未取药 → 成功取药 / 漏服 / 提前取药），通过事件回调向上层透出语义化的业务事件，而非原始字节流。

3. **双平台 API 一致性**：Android（Kotlin/Java）与 iOS（Swift/Objective-C）提供镜像对称的 API 设计，降低跨平台团队的学习成本和集成差异。

硬件已定型、协议已固化，SDK 是 LX-PD02 设备产生商业价值的最后一块拼图，交付即可被第三方开发者直接集成。

### Project Classification

| 维度 | 值 |
|---|---|
| 项目类型 | 移动端原生 SDK（Android + iOS） |
| 领域 | 医疗健康 / 智能硬件（IoT） |
| 复杂度 | 高（私有协议、双平台原生、状态机、密钥认证） |
| 项目背景 | 绿地项目（硬件已定型，SDK 全新开发） |
| 交付方式 | 开放给第三方开发者集成 |

---

## Success Criteria

### User Success（开发者视角）

- 第三方开发者从零开始，在 **4 小时内**完成 SDK 集成并跑通完整流程（扫描 → 连接 → 认证 → 设置闹钟 → 接收用药事件）
- SDK 提供完整的 API 文档、集成指南和可运行的 Demo 工程，开发者无需阅读底层协议文档
- API 调用层面零协议感知——开发者不需要了解帧结构、CRC 计算、CMD 字段含义

### User Success（终端用户视角）

- 设备与 APP 成功绑定后，闹钟提醒准时触发，用药事件（取药/漏服/超时）准确上报至 APP
- 用户在 APP 上设置的闹钟变更在 **3 秒内**同步至设备

### Business Success

- SDK 发布后，第三方开发者能够在 **2 周内**完成基于 SDK 的 APP 功能开发并提交测试
- SDK 支持至少 **3 个**不同第三方 APP 同时集成，无兼容性问题
- SDK 版本迭代时保持向后兼容，已集成方无需修改业务代码

### Technical Success

- BLE 连接成功率 **≥ 95%**（正常信号环境下）
- 指令响应超时阈值：**5 秒**无响应触发超时回调，SDK 内部自动重试 **3 次**
- 断线后自动重连：间隔 **2/4/8 秒**指数退避，最多重试 **5 次**，超出后回调通知上层
- CRC 校验失败或帧格式异常时，SDK 内部静默丢弃并记录日志，不向上层抛出崩溃
- Android 最低支持 API Level 21（Android 5.0），iOS 最低支持 iOS 13.0，设备蓝牙硬件须支持 **Bluetooth 5.0 及以上**

### Measurable Outcomes

| 指标 | 目标值 |
|---|---|
| 开发者首次集成耗时 | ≤ 4 小时 |
| 指令下发到设备响应延迟 | ≤ 3 秒（正常环境） |
| BLE 连接成功率 | ≥ 95% |
| 用药事件上报准确率 | 100%（无丢包） |
| SDK 崩溃率 | 0（所有异常内部处理） |

---

## User Journeys

### Journey 1：第三方开发者 — 首次集成（成功路径）

**角色：** 李明，某健康管理 APP 的 Android 开发工程师，有 BLE 开发经验但从未接触过 LX-PD02 设备。

**开场：** 李明收到需求——在现有 APP 中接入智能药盒功能，要求两周内提测。他拿到 SDK 包和文档，开始集成。

**过程：**
1. 阅读集成指南，5 分钟内完成 Gradle 依赖配置
2. 调用 `BlueSDK.startScan()` 扫描到附近的 `LX-PD02-A1B2` 设备
3. 调用 `connect(deviceId)` 建立连接，收到 `onConnected` 回调
4. SDK 自动计算密钥并发送认证包，收到 `onAuthSuccess` 回调——无需手动处理任何字节
5. 调用 `setAlarm(1, 8, 0, 0x7F)` 设置每天早 8 点提醒，收到设备应答回调
6. 模拟闹钟触发，收到 `onAlarmRinging`、`onMedicationTaken` 事件

**高潮：** 李明意识到整个流程不需要看一行协议文档，SDK 把所有状态机都处理好了。

**结果：** 3 小时内跑通核心流程，第二天开始写业务逻辑，第 10 天提测。

**揭示的需求：** 扫描 API、连接 API、自动认证、闹钟设置 API、用药事件回调、Demo 工程、集成文档。

---

### Journey 2：第三方开发者 — 异常处理（边缘路径）

**角色：** 王芳，iOS 开发工程师，在用户家中演示时遭遇设备断连。

**开场：** 演示进行到一半，设备因距离过远断开连接，用户焦虑地看着她。

**过程：**
1. APP 收到 `onDisconnected` 回调，UI 显示"连接已断开，正在重连..."
2. SDK 内部自动触发重连（2s → 4s → 8s 退避），王芳无需写任何重连逻辑
3. 第 2 次重连成功，收到 `onConnected` 回调
4. SDK 自动重新发送认证包，`onAuthSuccess` 后恢复正常状态
5. 之前设置的闹钟仍在设备中，无需重新下发

**高潮：** 整个重连过程 APP 自动处理，用户几乎没有感知。

**结果：** 演示顺利完成，用户对产品稳定性建立信心。

**揭示的需求：** 自动重连机制、重连状态回调、认证状态恢复、连接状态枚举（已连接/重连中/已断开）。

---

### Journey 3：患者终端用户 — 日常用药提醒（核心场景）

**角色：** 张奶奶，68 岁，每天需要按时服用降压药，子女为她配置了智能药盒 APP。

**开场：** 早上 8 点，张奶奶还在厨房做早饭，药盒开始响铃。

**过程：**
1. 设备触发闹钟，上报 `onAlarmRinging` 事件，APP 推送通知
2. 张奶奶走到药盒前，打开盖子取药
3. 设备检测到取药动作，上报 `onMedicationTaken`（用药成功）
4. APP 记录本次用药时间，通知消失
5. 子女在家属端 APP 看到"今日 08:02 已按时服药"

**高潮：** 子女不在身边也能确认老人按时服药，焦虑感消除。

**揭示的需求：** 闹钟响铃事件、用药成功事件、用药记录上报（含时间戳）、事件语义化（不是原始字节）。

---

### Journey 4：患者终端用户 — 漏服场景（异常场景）

**角色：** 张奶奶，闹钟响铃后因外出忘记取药。

**过程：**
1. 设备触发闹钟，APP 推送通知，张奶奶外出未看到
2. 超时时间到，设备上报 `onAlarmTimeout`（超时未取药）
3. APP 再次推送"您已超时未取药"强提醒
4. 张奶奶回家后手动取药，设备上报 `onMedicationLate`（超时取药）
5. APP 记录本次为"超时服药"，子女端显示异常标记

**揭示的需求：** 超时事件、漏服事件、超时取药事件、用药状态枚举（按时/超时/漏服/提前）。

---

### Journey 5：开发者 — 调试排查（支撑场景）

**角色：** 陈工，集成 SDK 后发现某台设备偶发认证失败，需要排查。

**过程：**
1. 开启 SDK 调试日志模式 `BlueSDK.setLogLevel(DEBUG)`
2. 复现问题，查看日志中的原始帧数据和 CRC 计算过程
3. 发现是该设备 MAC 地址读取异常导致密钥计算错误
4. 修复上层 MAC 地址获取逻辑，问题解决

**揭示的需求：** 调试日志开关、日志级别控制、关键操作日志输出（帧收发、CRC、认证过程）。

---

### Journey Requirements Summary

| 旅程 | 揭示的核心能力需求 |
|---|---|
| 开发者首次集成 | 扫描、连接、自动认证、闹钟 API、事件回调、文档/Demo |
| 开发者异常处理 | 自动重连、状态回调、认证恢复 |
| 患者日常用药 | 响铃事件、取药事件、用药记录上报 |
| 患者漏服场景 | 超时事件、漏服事件、用药状态枚举 |
| 开发者调试排查 | 日志系统、调试模式、帧级日志 |


---

## Domain-Specific Requirements

### 合规与监管

- SDK 本身不持久化任何用户健康数据（用药记录、时间戳等），数据存储责任由上层 APP 承担；SDK 文档须明确声明此边界，协助第三方开发者满足 GDPR / 中国《个人信息保护法》（PIPL）合规要求
- SDK 版本号遵循语义化版本规范（SemVer），每次发布附带变更日志（CHANGELOG），为有医疗器械合规需求的集成方提供版本追溯依据
- 密钥计算过程（手机 MAC + 设备 MAC 累加）仅在内存中执行，禁止写入任何日志或持久化存储

### 技术约束

- **BLE 权限声明**：Android 12+ 需声明 `BLUETOOTH_SCAN`、`BLUETOOTH_CONNECT` 权限；iOS 需配置 `NSBluetoothAlwaysUsageDescription`；SDK 提供权限状态检查 API，文档提供权限申请示例代码
- **后台运行限制**：iOS 系统对后台 BLE 连接有严格限制，SDK 文档须说明后台保活约束，建议上层 APP 结合 APNs 推送通知作为用药事件的补偿通知机制
- **线程模型**：所有事件回调默认在主线程（UI 线程）派发；提供可选的回调线程配置，满足有自定义线程调度需求的开发者
- **协议版本校验**：SDK 在连接建立后校验设备协议版本字段（帧字节2），版本不匹配时触发 `onProtocolVersionMismatch` 回调，不强制断开但告警上层

### 风险与缓解

| 风险 | 影响 | 缓解措施 |
|---|---|---|
| 密钥算法被逆向 | 非授权设备接入 | 文档说明密钥仅用于设备绑定验证，建议上层 APP 增加用户账号绑定层 |
| iOS 后台 BLE 被系统终止 | 漏报用药事件 | SDK 文档说明 iOS 后台限制，建议结合 APNs 推送通知补偿 |
| Android 厂商 BLE 兼容性差异 | 部分机型连接失败 | SDK 内置常见机型适配逻辑，发布兼容性测试矩阵文档 |
| 设备固件升级导致协议变更 | SDK 功能失效 | SDK 设计协议版本字段校验机制，版本不匹配时回调告警 |
| 第三方开发者误用 API 顺序 | 认证失败或指令丢失 | SDK 内部实现状态机守卫，未认证时调用业务 API 返回明确错误码 |


---

## Mobile SDK Specific Requirements

### 项目类型概述

Blue SDK 是一个**领域专属移动端原生 SDK**，面向 Android（Kotlin/Java）和 iOS（Swift/Objective-C）双平台，封装 LX-PD02 私有 BLE 协议，以高层语义化 API 对外暴露设备控制与事件订阅能力。SDK 不包含 UI 组件，不依赖任何特定 APP 框架，可嵌入任意 Android/iOS 原生工程。

### 平台需求

| 维度 | Android | iOS |
|---|---|---|
| 最低系统版本 | API Level 21（Android 5.0） | iOS 13.0 |
| 开发语言 | Kotlin（主）/ Java（兼容） | Swift（主）/ Objective-C（兼容） |
| 分发格式 | AAR 库文件 | XCFramework（支持模拟器+真机） |
| 依赖管理 | Maven / Gradle 本地依赖 | CocoaPods / Swift Package Manager |
| BLE 框架 | Android BluetoothLE API | CoreBluetooth |
| 最低蓝牙版本 | Bluetooth 5.0 | Bluetooth 5.0 |

### 设备权限

**Android 权限声明（集成方 AndroidManifest.xml）：**
```xml
<!-- Android 6-11 -->
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<!-- Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
```

**iOS 权限声明（集成方 Info.plist）：**
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限以连接智能药盒设备</string>
```

SDK 提供 `BlueSDK.checkPermissions()` API，返回当前权限状态枚举，集成方可据此引导用户授权。

### API 设计模式

**初始化与生命周期：**
```kotlin
// Android
val sdk = BlueSDK.getInstance(context)
sdk.initialize()
sdk.destroy() // Activity/Application 销毁时调用
```
```swift
// iOS
let sdk = BlueSDK.shared
sdk.initialize()
sdk.destroy()
```

**事件订阅模式（观察者模式）：**
- Android：接口回调（Listener）+ 可选 LiveData/Flow 扩展
- iOS：Protocol Delegate + 可选 Combine Publisher 扩展
- 所有回调默认主线程派发

**错误处理：**
- 所有异步操作通过回调返回 `BlueError` 枚举，不抛出异常
- `BlueError` 包含：错误码、错误描述、可恢复性标志

### 离线与状态管理

- SDK 不做本地数据持久化，所有状态为内存态
- 连接断开后，SDK 内部状态重置，重连后需重新认证
- 闹钟配置存储在设备端，重连后可通过查询 API 重新获取
- SDK 提供 `getConnectionState()` 同步方法，供 APP 随时查询当前连接状态

### 日志与调试

```kotlin
// 日志级别：NONE / ERROR / WARN / INFO / DEBUG / VERBOSE
BlueSDK.setLogLevel(LogLevel.DEBUG)

// 自定义日志输出（集成方可接管日志）
BlueSDK.setLogHandler { level, tag, message ->
    MyLogger.log(level, tag, message)
}
```

- DEBUG 级别输出原始帧数据（十六进制）、CRC 计算过程、认证流程
- 生产环境建议设置为 `ERROR` 或 `NONE`
- 密钥值在任何日志级别下均不输出明文

### 交付物清单

| 交付物 | Android | iOS |
|---|---|---|
| SDK 库文件 | blue-sdk-x.x.x.aar | BlueSDK.xcframework |
| API 参考文档 | Javadoc / KDoc | DocC |
| 集成指南 | README.md | README.md |
| Demo 工程 | blue-sdk-demo-android | blue-sdk-demo-ios |
| 变更日志 | CHANGELOG.md | CHANGELOG.md |
| 兼容性矩阵 | compatibility-matrix.md | compatibility-matrix.md |


---

## Product Scope

### 交付策略

**交付方式：** 单次完整交付（Single Release）
**交付哲学：** 平台型 SDK——完整封装 LX-PD02 协议全部能力，使第三方开发者能够构建任意用药管理场景，无功能缺口
**团队配置建议：** Android 工程师 × 1、iOS 工程师 × 1、技术文档工程师 × 1（兼职）

### 支持的核心用户旅程

| 旅程 | 是否覆盖 |
|---|---|
| 开发者首次集成（扫描→连接→认证→闹钟→事件） | ✅ |
| 开发者异常处理（断线重连、认证恢复） | ✅ |
| 患者日常用药提醒（响铃→取药→上报） | ✅ |
| 患者漏服场景（超时→漏服→超时取药） | ✅ |
| 开发者调试排查（日志系统） | ✅ |

### Must-Have 能力（本次交付全部包含）

**连接管理**
- 按广播名前缀 `LX-PD02` 扫描设备
- 建立 / 断开 BLE 连接
- 连接状态变化回调（已连接 / 重连中 / 已断开）
- 断线自动重连（指数退避：2s / 4s / 8s，最多 5 次）
- 权限状态检查 API

**身份认证**
- 密钥包自动计算（手机 MAC + 设备 MAC 累加）
- 认证结果回调（成功 / 失败）
- 认证失败自动断开连接
- 未认证状态下调用业务 API 返回明确错误码

**设备信息**
- 查询设备固件版本等基础信息

**时间同步**
- 响应设备时间同步请求，自动下发当前系统时间

**闹钟管理（7 个槽位）**
- 设置单个闹钟（时间、周期、星期掩码）
- 删除单个闹钟
- 清空所有闹钟
- 接收设备端闹钟变更上报

**用药事件**
- 接收闹钟开始响铃事件
- 接收闹钟超时事件
- 接收用药成功 / 漏服 / 提前取药事件
- 接收用药记录上报（含时间戳）
- 用药状态枚举：`TAKEN` / `TIMEOUT` / `MISSED` / `EARLY`

**音频设置**
- 设置音量（低 / 中 / 高）
- 设置铃声类型（A / B / C）
- 设置当前闹钟静音开关

**系统设置**
- 设置 12 / 24 小时制

**日志与调试**
- 日志级别控制（NONE / ERROR / WARN / INFO / DEBUG）
- 自定义日志处理器接口
- 密钥值任何级别下不输出明文

### Nice-to-Have 能力（本次交付视资源决定）

- 恢复出厂设置
- 低电量事件监听
- 协议版本不匹配告警回调

### 后续版本路线图

**Growth（下一版本）**
- 恢复出厂设置（若未纳入本次交付）
- 设备解绑流程（设备端操作上报处理）
- 低电量事件监听与处理
- 闹钟记录（DPID_ALARMRECORD）完整读写支持
- 多设备管理（同时管理多个 LX-PD02 设备）
- 连接日志导出（用于开发者调试）

**Vision（远期）**
- 跨平台 Flutter / React Native 封装层
- 云端用药数据同步协议扩展
- OTA 固件升级支持（如硬件后续支持）
- 设备健康诊断 API（信号强度、连接质量评分）

### 风险缓解策略

| 风险类型 | 风险描述 | 缓解措施 |
|---|---|---|
| 技术风险 | Android 厂商 BLE 兼容性差异 | 覆盖主流机型测试（华为/小米/OPPO/vivo），发布兼容性矩阵 |
| 技术风险 | iOS 后台 BLE 保活限制 | 文档明确说明限制，提供 APNs 补偿方案示例 |
| 市场风险 | 第三方开发者集成体验差 | Demo 工程 + 集成指南 + 4 小时集成目标验收 |
| 资源风险 | 双平台并行开发进度不同步 | 先对齐 API 接口契约文档，再并行实现 |


---

## Functional Requirements

### FR 能力域 1：设备发现与连接管理

- **FR01**：开发者可发起 BLE 扫描，SDK 自动过滤并返回广播名前缀为 `LX-PD02` 的设备列表
- **FR02**：开发者可指定设备 ID 发起连接请求
- **FR03**：开发者可主动断开当前连接
- **FR04**：上层应用可订阅连接状态变化事件（已连接 / 重连中 / 已断开 / 连接失败）
- **FR05**：SDK 在连接意外断开后自动执行重连，重连结果通过回调通知上层
- **FR06**：开发者可查询当前连接状态（同步方法）
- **FR07**：开发者可查询当前蓝牙权限状态，SDK 返回权限枚举值

### FR 能力域 2：身份认证与安全绑定

- **FR08**：SDK 可基于手机 MAC 地址与设备 MAC 地址自动计算并发送密钥包
- **FR09**：上层应用可订阅认证结果事件（认证成功 / 认证失败）
- **FR10**：SDK 在认证失败时自动断开连接，并通过回调通知上层
- **FR11**：SDK 在未完成认证的状态下拒绝执行业务指令，并返回明确错误码

### FR 能力域 3：设备信息与时间同步

- **FR12**：开发者可主动查询设备基础信息（固件版本等）
- **FR13**：上层应用可订阅设备时间同步请求事件
- **FR14**：开发者可向设备下发当前系统时间完成时间同步

### FR 能力域 4：闹钟管理

- **FR15**：开发者可设置指定槽位（1~7）的闹钟，包含时、分、星期周期掩码
- **FR16**：开发者可删除指定槽位的闹钟
- **FR17**：开发者可清空设备上所有闹钟
- **FR18**：上层应用可订阅设备端闹钟变更上报事件，获取最新闹钟配置
- **FR19**：SDK 返回的闹钟数据包含完整字段：时间、周期掩码、提前取药状态

### FR 能力域 5：用药事件与记录

- **FR20**：上层应用可订阅闹钟开始响铃事件，事件携带对应闹钟槽位信息
- **FR21**：上层应用可订阅闹钟超时未取药事件
- **FR22**：上层应用可订阅用药结果事件，结果包含语义化状态枚举（按时取药 / 超时取药 / 漏服 / 提前取药）
- **FR23**：上层应用可订阅用药记录上报事件，记录包含时间戳、闹钟槽位、用药状态
- **FR24**：开发者可向设备下发用药结果通知指令（等待 / 响铃开始 / 错过 / 成功）

### FR 能力域 6：音频与提醒设置

- **FR25**：开发者可设置设备提醒音量（低 / 中 / 高三档）
- **FR26**：开发者可设置设备铃声类型（类型 A / B / C）
- **FR27**：上层应用可订阅设备端铃声类型变更上报事件
- **FR28**：开发者可设置当前闹钟静音状态（开 / 关）
- **FR29**：开发者可设置闹钟提醒持续时长

### FR 能力域 7：系统设置

- **FR30**：开发者可设置设备时间显示格式（12 小时制 / 24 小时制）
- **FR31**：上层应用可订阅设备端时间格式变更上报事件

### FR 能力域 8：SDK 生命周期与开发者工具

- **FR32**：开发者可初始化 SDK 并绑定应用上下文
- **FR33**：开发者可销毁 SDK 实例，释放所有 BLE 资源
- **FR34**：开发者可设置 SDK 日志级别（NONE / ERROR / WARN / INFO / DEBUG）
- **FR35**：开发者可注册自定义日志处理器，接管 SDK 日志输出
- **FR36**：SDK 在任何日志级别下均不输出密钥明文

> ⚠️ **能力契约声明**：以上 36 条功能需求是本次交付的完整能力边界。架构设计、Epic 拆分、UX 设计均以此为准，未列入的能力不在本次交付范围内。

---

## Non-Functional Requirements

### 性能（Performance）

- **NFR01**：指令从 SDK 发出到收到设备应答的端到端延迟，在正常 BLE 信号环境下 **≤ 3 秒**
- **NFR02**：SDK 发出指令后，若 **5 秒**内未收到设备应答，触发超时回调，SDK 内部自动重试，最多重试 **3 次**
- **NFR03**：BLE 扫描结果首次返回延迟 **≤ 2 秒**（设备在有效信号范围内）
- **NFR04**：SDK 初始化耗时 **≤ 100ms**，不阻塞主线程
- **NFR05**：SDK 运行时内存占用 **≤ 5MB**（不含系统 BLE 栈）

### 安全（Security）

- **NFR06**：密钥计算过程仅在内存中执行，密钥值不写入任何日志、文件或持久化存储
- **NFR07**：SDK 在任何日志级别下均不输出密钥明文、MAC 地址原始值
- **NFR08**：SDK 不收集、不上传任何用户数据或设备数据至远程服务器
- **NFR09**：SDK 不包含任何网络请求能力，所有通信仅限本地 BLE 通道

### 可靠性（Reliability）

- **NFR10**：在正常 BLE 信号环境下，连接成功率 **≥ 95%**
- **NFR11**：断线后自动重连成功率（5 次重试内）**≥ 90%**
- **NFR12**：CRC 校验失败或帧格式异常时，SDK 内部静默丢弃并记录日志，不向上层抛出未捕获异常（崩溃率为 0）
- **NFR13**：SDK 内部状态机在任意异常输入下不进入死锁或无限等待状态
- **NFR14**：用药事件上报不丢失——SDK 收到设备上报帧后，必须在回调触发前完成帧完整性校验

### 兼容性（Compatibility）

- **NFR15**：Android 平台兼容 API Level 21~最新版本，设备蓝牙硬件须支持 **Bluetooth 5.0 及以上**，覆盖华为、小米、OPPO、vivo、三星主流机型
- **NFR16**：iOS 平台兼容 iOS 13.0~最新版本，设备蓝牙硬件须支持 **Bluetooth 5.0 及以上**，覆盖 iPhone 8 及以上机型
- **NFR17**：Android SDK 同时提供 Kotlin 和 Java 调用接口，无需额外适配层
- **NFR18**：iOS SDK 同时提供 Swift 和 Objective-C 调用接口，无需额外适配层
- **NFR19**：SDK 不引入任何第三方运行时依赖（零外部依赖），仅依赖系统 BLE 框架

### 可维护性（Maintainability）

- **NFR20**：SDK 遵循语义化版本规范（SemVer），主版本号变更时提供迁移指南
- **NFR21**：SDK 公开 API 变更须保持向后兼容，已集成方升级小版本无需修改业务代码
- **NFR22**：每次发布附带 CHANGELOG，记录新增能力、变更行为、已知问题
