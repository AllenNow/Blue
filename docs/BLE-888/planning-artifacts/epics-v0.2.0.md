# BlueSDK v0.2.0 — Epic & Story 拆解

**版本代号**: Growth  
**核心主题**: 可靠性与开发者体验  
**创建日期**: 2026-06-09

---

## Epic 总览

| Epic | 名称 | Story 数 | 价值 |
|------|------|---------|------|
| Epic 8 | 离线指令队列 | 4 | 断线时缓存指令，重连后自动下发 |
| Epic 9 | 协议能力补齐 | 3 | 恢复出厂、低电量、设备解绑 |
| Epic 10 | 开发者调试工具 | 4 | BLE 调试面板、错误引导、日志导出 |
| Epic 11 | 工程质量与发布 | 4 | CI 测试、混淆验证、打包脚本、版本自动化 |

---

## Epic 8：离线指令队列

**目标**: 用户在设备不在蓝牙范围时修改设置（如闹钟），指令缓存到本地，设备重连后自动下发，避免"设置了但不生效"的困惑。

### Story 8.1：离线指令缓存层

As a 第三方开发者，
I want SDK 在设备断开时自动将业务指令缓存到内存队列，
So that 我无需判断连接状态就能调用设置 API，SDK 会在合适时机自动执行。

**Acceptance Criteria:**

**Given** 设备已断开连接（状态为 DISCONNECTED 或 RECONNECTING）
**When** 调用 `setAlarm()`、`setVolume()` 等业务 API
**Then** 指令不报错，进入离线队列缓存
**And** SDK 返回特定状态标识（如 `Result.success` 附带 `isPending: true`）
**And** 离线队列最大容量 50 条，超出时丢弃最早的指令并记录 WARN 日志
**And** 离线队列仅缓存配置类指令（闹钟/音量/铃声/时间格式），不缓存查询类指令

---

### Story 8.2：重连后自动下发

As a 第三方开发者，
I want SDK 在设备重连并认证成功后自动按顺序下发缓存的离线指令，
So that 用户在 APP 上做的设置最终一定会同步到设备。

**Acceptance Criteria:**

**Given** 离线队列中有 N 条待下发指令
**When** 设备重连并认证成功（状态变为 AUTHENTICATED）
**Then** SDK 自动按 FIFO 顺序逐条下发缓存指令
**And** 每条指令复用现有超时重试机制（5秒超时，3次重试）
**And** 下发过程中如果再次断线，剩余指令保留在离线队列
**And** 全部下发完成后触发 `onOfflineQueueFlushed(count)` 回调通知上层
**And** 任何指令下发失败触发 `onOfflineCommandFailed(command, error)` 回调

---

### Story 8.3：离线队列管理 API

As a 第三方开发者，
I want 查看和管理离线队列，
So that 我可以在 UI 上提示用户"有 N 条待同步设置"，或允许用户手动清空。

**Acceptance Criteria:**

**Given** SDK 已初始化
**When** 调用 `BlueSDK.pendingCommandCount` 属性
**Then** 返回当前离线队列中待下发的指令数量
**And** 调用 `BlueSDK.clearPendingCommands()` 可清空离线队列
**And** 调用 `BlueSDK.getPendingCommands()` 可获取待下发指令列表（只读）

---

### Story 8.4：离线队列事件回调

As a 第三方开发者，
I want 监听离线队列的状态变化，
So that 我可以在 UI 上实时更新同步状态。

**Acceptance Criteria:**

**Given** 已注册 BlueSDKDelegate/Listener
**When** 离线队列状态变化时
**Then** 新增回调：
- `onOfflineCommandQueued(count)` — 有新指令进入离线队列
- `onOfflineQueueFlushed(successCount, failedCount)` — 重连后队列全部下发完成
- `onOfflineCommandFailed(commandType, error)` — 单条离线指令下发失败
**And** 所有回调在主线程派发

---

## Epic 9：协议能力补齐

**目标**: 补齐 PRD Nice-to-Have 中已规划但未实现的 3 个协议功能。

### Story 9.1：恢复出厂设置

As a 第三方开发者，
I want 发送恢复出厂设置指令，
So that 用户可以将设备重置为初始状态。

**Acceptance Criteria:**

**Given** 设备已认证
**When** 调用 `BlueSDK.restoreFactory(completion:)`
**Then** SDK 发送帧：CMD=0x06，DPID=0x71，数据=0x01
**And** 验证：发送帧 `55 AA 00 06 00 05 76 01 00 01 01 83`（协议文档第12条）
**And** 设备应答后触发成功回调
**And** 恢复出厂后 SDK 自动断开连接并重置内部状态
**And** 5秒超时触发 `BlueError.timeout`

---

### Story 9.2：低电量事件监听

As a 第三方开发者，
I want 接收设备低电量上报事件，
So that APP 可以提醒用户更换电池。

**Acceptance Criteria:**

**Given** 设备已认证且已注册监听器
**When** 设备上报低电量帧（CMD=0x07，DPID=0x75，数据=0x01）
**Then** SDK 触发 `onLowBattery()` 回调
**And** 回调在主线程派发
**And** 上报帧不经过指令队列，直接路由到事件分发器

---

### Story 9.3：设备解绑上报

As a 第三方开发者，
I want 接收设备端解绑操作的上报，
So that 当用户在设备上执行解绑时 APP 可以同步清除绑定信息。

**Acceptance Criteria:**

**Given** 设备已认证且已注册监听器
**When** 设备端执行解绑操作并上报
**Then** SDK 触发 `onDeviceUnbound()` 回调
**And** SDK 自动断开连接并重置内部状态（含清空离线队列）
**And** 回调在主线程派发

---

## Epic 10：开发者调试工具

**目标**: 提升集成方的调试效率，减少支持成本。

### Story 10.1：BLE 原始帧调试面板

As a 集成方开发者，
I want 在 Demo APP 中有一个页面可以手动发送原始十六进制帧并查看设备应答，
So that 我可以直接调试协议问题而不需要写代码。

**Acceptance Criteria:**

**Given** Demo APP 已启动且设备已连接认证
**When** 用户在文本框输入十六进制帧（如 `55 AA 00 01 00 00 00`）
**Then** 点击"发送"后 SDK 直接发送该帧（绕过业务 API）
**And** 页面实时显示设备应答帧的十六进制数据
**And** 支持自动 CRC8 填充（勾选"自动补 CRC"后只需输入到数据段末尾）
**And** 历史收发记录可上下滚动查看

---

### Story 10.2：错误恢复引导

As a 第三方开发者，
I want 每种 BlueError 附带恢复建议，
So that 我可以直接展示给用户或根据建议编写恢复逻辑。

**Acceptance Criteria:**

**Given** SDK 返回任何 BlueError
**When** 调用 `error.recoveryHint`
**Then** 返回非空字符串，描述建议的恢复操作：
- `.notInitialized` → "请在 APP 启动时调用 BlueSDK.initialize()"
- `.notAuthenticated` → "请先调用 authenticate() 完成设备认证"
- `.authFailed` → "密钥不匹配，请确认手机和设备的 MAC 地址正确"
- `.timeout` → "设备无响应，请确认设备在蓝牙范围内且已开机"
- `.permissionDenied` → "请在系统设置中开启蓝牙权限"
- `.invalidParameter` → "参数无效，请检查闹钟索引是否在 1~7 范围内"
- `.disconnected` → "设备已断开，请等待自动重连或手动重新连接"
- `.bleError` → "蓝牙系统异常，请尝试关闭再开启手机蓝牙"
**And** 双平台 API 对称：iOS `error.recoveryHint`，Android `error.recoveryHint`

---

### Story 10.3：连接状态可视化（Demo）

As a 集成方开发者，
I want Demo APP 中有一个实时的连接状态机可视化组件，
So that 我可以直观看到 5 个状态之间的转换过程。

**Acceptance Criteria:**

**Given** Demo APP 已启动
**When** 连接状态发生变化
**Then** 页面上的状态图实时高亮当前状态
**And** 显示状态转换历史记录（时间戳 + 从哪个状态到哪个状态）
**And** 重连计数器实时显示当前重连次数
**And** 双平台 Demo 均实现此功能

---

### Story 10.4：连接日志一键导出

As a 第三方开发者，
I want 一键导出 SDK 运行日志，
So that 遇到问题时可以将日志发给 SDK 维护方远程排查。

**Acceptance Criteria:**

**Given** SDK 已初始化且日志级别 ≥ DEBUG
**When** 调用 `BlueSDK.exportLog()` 或 `BlueSDK.exportLog(since: Date)`
**Then** 返回日志文本（String）或写入临时文件返回文件路径
**And** 日志包含：时间戳、级别、标签、消息（密钥已脱敏）
**And** 最近 1000 条日志保留在内存环形缓冲区
**And** 导出的日志自动附带 SDK 版本号、设备型号、系统版本等环境信息

---

## Epic 11：工程质量与发布

**目标**: 建立可持续的发布流程和质量保障体系。

### Story 11.1：BLE 模拟器集成测试（iOS）

As a SDK 维护者，
I want 在 CI 中使用 BLE 模拟器运行连接/认证/指令全流程测试，
So that 每次代码变更都能自动验证 BLE 交互逻辑。

**Acceptance Criteria:**

**Given** CI 环境（macOS runner）
**When** 执行 `swift test` 或 Xcode Test
**Then** 使用 `MockCBCentralManager` 和 `MockCBPeripheral` 模拟 BLE 交互
**And** 覆盖场景：扫描发现 → 连接 → 认证成功 → 指令下发 → 应答匹配
**And** 覆盖异常场景：认证失败 → 自动断开、连接超时 → 重连
**And** 不依赖真实 BLE 硬件

---

### Story 11.2：ProGuard 混淆验证（Android）

As a SDK 维护者，
I want 在 CI 中验证 AAR 开启混淆后公开 API 仍可正常调用，
So that 集成方不会因为混淆配置导致 SDK 功能失效。

**Acceptance Criteria:**

**Given** `consumer-rules.pro` 已配置保留规则
**When** 在 CI 中编译 release AAR（开启 R8 混淆）
**Then** 编译成功且无混淆相关警告
**And** Demo App 引用 release AAR 后能正常编译和运行
**And** 通过反射验证 `BlueSDK`、`BlueSDKListener`、`BlueError` 类和方法均存在

---

### Story 11.3：XCFramework 打包脚本

As a SDK 维护者，
I want 一条命令生成 iOS XCFramework，
So that 可以分发给不使用 CocoaPods/SPM 的集成方。

**Acceptance Criteria:**

**Given** 脚本 `scripts/build-xcframework.sh`
**When** 执行该脚本
**Then** 生成 `BlueSDK.xcframework`（含 arm64 真机 + x86_64 模拟器）
**And** 生成物可以拖入任意 Xcode 工程直接使用
**And** 生成物包含 Swift module 接口文件
**And** 脚本输出版本号和生成物路径

---

### Story 11.4：版本号自动化与发布流程

As a SDK 维护者，
I want 一条命令完成版本号递增、CHANGELOG 更新、Git Tag 和打包发布，
So that 发版不再依赖手动操作，减少人为错误。

**Acceptance Criteria:**

**Given** 当前版本为 `0.1.0`
**When** 执行 `make release VERSION=0.2.0`（或等效命令）
**Then** 自动更新 `BlueSDK.podspec` 和 `build.gradle.kts` 中的版本号
**And** 自动更新 CHANGELOG.md（从 `[Unreleased]` 移动到 `[0.2.0]` 并添加日期）
**And** 创建 Git commit：`release: v0.2.0`
**And** 创建 Git tag：`v0.2.0`
**And** iOS：生成 XCFramework（调用 Story 11.3 脚本）
**And** Android：生成 release AAR

---

## FR 覆盖映射（v0.2.0 新增）

| Story | 新增 FR |
|-------|---------|
| 8.1~8.4 | 离线指令队列（扩展 FR15~FR30 的离线能力）|
| 9.1 | 恢复出厂设置（DPID 0x71）|
| 9.2 | 低电量事件（DPID 0x75）|
| 9.3 | 设备解绑上报 |
| 10.1 | 调试面板（开发者工具）|
| 10.2 | 错误恢复引导（开发者体验）|
| 10.3 | 状态可视化（开发者工具）|
| 10.4 | 日志导出（开发者工具）|
| 11.1~11.4 | 工程质量（非功能性）|

---

## 依赖关系

```
Epic 8（离线队列）→ 独立，可先行开发
Epic 9（协议补齐）→ 独立，可并行
Epic 10（调试工具）→ 依赖 Epic 8 完成后体验更完整
Epic 11（工程发布）→ 独立，可并行
```

**建议开发顺序**: Epic 9（快速出成果）→ Epic 8（核心价值）→ Epic 11（发布基建）→ Epic 10（体验锦上添花）

---

**文档版本**: 1.0  
**最后更新**: 2026-06-09
