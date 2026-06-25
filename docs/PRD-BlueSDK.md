# BlueSDK 产品需求文档 (PRD)

## 1. 产品概述

BlueSDK 是专为 LX-PD02 智能药盒设计的蓝牙 BLE 通信 SDK，面向第三方公司发布，提供简洁的高层 API，完全封装底层协议细节。集成方无需了解任何 BLE 命令帧格式。

**目标设备**：LX-PD02 智能药盒（广播名前缀 `LX-PD02-XXXX`）  
**通信方式**：Bluetooth 5.0 BLE  
**支持平台**：iOS 13+ / Android 8+  
**支持语言**：中文、英文、德文  
**交付形式**：iOS XCFramework / Android AAR（源码不可见）

---

## 2. SDK 公开 API

### 2.1 生命周期

| API | 功能 |
|-----|------|
| `initialize(config)` | 初始化 SDK（≤100ms），接受 BlueSDKConfig 配置 |
| `destroy()` | 销毁 SDK，释放资源 |
| `setLogLevel(level)` | 设置日志级别 |
| `setLogHandler(handler)` | 自定义日志处理器 |
| `setLanguage(language)` | 运行时切换语言（zh/en/de） |

### 2.2 配置（BlueSDKConfig）

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `fixedAuthKey` | String? | nil | 固定密钥（4位hex，如"05FA"） |
| `customPhoneMac` | String? | nil | 自定义手机标识（12位hex） |
| `logLevel` | LogLevel | .debug | 日志级别 |
| `autoAuthEnabled` | Bool | true | 连接后自动认证 |
| `autoReconnect` | Bool | true | 断线自动重连 |
| `maxReconnectAttempts` | Int | 5 | 最大重连次数 |
| `language` | Language | .system | SDK 语言（system/zh/en/de） |

### 2.3 连接管理

| API | 功能 |
|-----|------|
| `checkPermissions()` | 查询蓝牙权限状态 |
| `startScan(timeout, callback)` | 扫描设备（ScanEvent 单回调） |
| `stopScan()` | 停止扫描 |
| `connect(device)` | 连接设备（自动认证） |
| `disconnect()` | 断开连接 |
| `cancelReconnection()` | 取消自动重连 |
| `connectionState` | 当前连接状态（只读） |
| `currentTimeFormat` | 当前设备时制（只读） |
| `currentAuthKeyDisplay` | 当前密钥展示（只读） |

**连接状态机**：
```
DISCONNECTED → CONNECTING → CONNECTED → AUTHENTICATED
                    ↓                         ↓
              RECONNECTING ←──────────────────┘ (意外断开)
```

### 2.4 认证与绑定

| API | 功能 |
|-----|------|
| `authenticateWithKey(keyHigh, keyLow)` | 手动密钥认证（高级） |
| `clearBinding(completion)` | 解绑设备（发送 CMD=0xA1，成功后清除本地密钥） |

**认证密钥来源优先级**：
1. `config.fixedAuthKey`（4位hex直接使用）
2. `config.customPhoneMac`（集成方自定义ID）
3. 平台自动生成（iOS: UUID+Keychain / Android: ANDROID_ID+SHA256）

### 2.5 设备信息与时间同步

| API | 功能 |
|-----|------|
| `queryDeviceInfo(completion)` | 查询设备MAC和固件版本（需已连接） |
| `syncTime(date, completion)` | 下发当前时间 |

### 2.6 闹钟管理（7个槽位）

| API | 功能 |
|-----|------|
| `setAlarm(index, hour, minute, days)` | 设置闹钟（类型安全 WeekDays） |
| `deleteAlarm(index, completion)` | 删除闹钟 |
| `clearAllAlarms(completion)` | 清空所有闹钟 |
| `setAlarms(alarms, completion)` | 批量设置闹钟 |

**WeekDays 类型**：`.all`、`.weekdays`、`.weekend`、`[.monday, .wednesday, .friday]`

### 2.7 用药事件

| API | 功能 |
|-----|------|
| `sendMedicationNotification(status)` | 下发用药结果通知（MedicationStatus 枚举） |

**用药状态**：
| 值 | 枚举 | 含义 |
|----|------|------|
| 0x01 | `.taken` | 按时取药 |
| 0x02 | `.timeout` | 超时取药 |
| 0x03 | `.missed` | 漏服 |
| 0x04 | `.early` | 提前取药 |

### 2.8 音频与系统设置

| API | 功能 | 参数范围 |
|-----|------|---------|
| `setVolume(level)` | 音量 | .low/.medium/.high |
| `setSoundType(type)` | 铃声 | .mute/.typeA/.typeB |
| `setSilence(enabled)` | 静音开关 | true/false |
| `setAlertDuration(minutes)` | 响铃时长 | 1~5 分钟（整数） |
| `setTimeFormat(format)` | 时间格式 | .hour12/.hour24 |
| `restoreFactory(completion)` | 恢复出厂（等待设备确认） | - |

---

## 3. 事件回调（16种）

所有回调主线程派发，支持多播 Observer（无限数量）。

| # | 事件 | 说明 |
|---|------|------|
| 1 | 连接状态变化 | BLE 连接/断开/重连 |
| 2 | 认证结果 | 密钥认证成功/失败 |
| 3 | 设备信息 | queryDeviceInfo 应答 |
| 4 | 时间同步请求 | 设备请求同步时间（SDK 自动响应） |
| 5 | 闹钟配置变更 | 设备上报闹钟设置 |
| 6 | 闹钟响铃 | 闹钟触发 |
| 7 | 闹钟超时 | 响铃超时无操作 |
| 8 | 用药结果（实时） | 取药/漏服瞬间通知 |
| 9 | 用药记录（完整） | 包含设定时间+实际时间 |
| 10 | 铃声类型变更 | 设备上报铃声配置 |
| 11 | 时间格式变更 | 设备上报12/24H |
| 12 | 低电量 | 设备电量低 |
| 13 | 用药通知 | 响铃(1)/超时(2)/已取药(3) |
| 14 | 连接错误 | 超时/BLE错误 |
| 15 | 正在重连 | 自动重连进度 |
| 16 | 重连失败 | 达到最大次数 |

**多播 Observer**：
- `addObserver(observer)` — 注册（iOS 弱引用/Android 需手动移除）
- `removeObserver(observer)` — 移除
- 主 delegate/listener 和所有 observer 同时收到事件

---

## 4. 协议帧结构（SDK 内部，集成方不可见）

```
[0x55][0xAA][版本=0x00][CMD][Len高][Len低][Data...][CRC8]
```

| CMD | 方向 | 功能 |
|-----|------|------|
| 0x00 | 下行 | 密钥认证 |
| 0x01 | 下行 | 查询设备信息 |
| 0x06 | 下行 | APP下发指令 |
| 0x07 | 上行 | 设备上报/应答 |
| 0xA1 | 下行 | 解绑设备 |
| 0xE1 | 双向 | 时间同步 |

---

## 5. DPID 映射表

| DPID | 用途 | 方向 |
|------|------|------|
| 0x65 | 用药记录上报 | 上行 |
| 0x66~0x6C | 闹钟1~7 | 双向 |
| 0x6D | 铃声类型（0=静音/1=A/2=B） | 双向 |
| 0x6E | 音量(type=04) / 持续时间(type=02) | 下行 |
| 0x6F | 用药通知(上行:01响铃/02超时/03取药) / 铃声设置(下行) | 双向 |
| 0x73 | 时制（0=12H/1=24H） | 双向 |
| 0x74 | 静音（0=关/1=开） | 双向 |
| 0x75 | 低电上报 | 上行 |
| 0x71 | 恢复出厂 | 下行 |

---

## 6. Demo App 功能

### 6.1 主页
- 连接状态卡片 + 密钥输入框（支持 fixedAuthKey 和 customPhoneMac）
- 全屏 Loading 遮罩（可取消）
- 快捷操作：设备信息、同步时间、指令验证
- 音频设置：铃声(A/B)、音量、时制、静音、响铃时长(1~5分)
- 工具入口：用药记录、闹钟管理、FAQ
- 系统操作：清空闹钟、恢复出厂、解绑设备
- 日志窗口（版本号水印 + 自动滚动）
- 设备上报自动同步 UI 控件状态
- 断开连接弹窗提示
- 多语言切换（中/英/德）
- Dark/Light Mode 适配

### 6.2 闹钟管理页
- 7个槽位列表（时间、周期、运行状态标签：空闲/响铃中/已完成）
- 点击编辑（时间选择器+周重复按钮，传入当前值作为默认）
- 左滑删除、清空全部
- 本地持久化（UserDefaults/SharedPreferences）
- 实时接收设备上报更新（多播 Observer）

### 6.3 用药记录页
- 日历选择日期查询 / 全部记录
- 状态图例（✅按时 ⏰超时 ❌漏服 ⏩提前）
- 居中布局：emoji + 标题 + "设定 xx:xx → 实际 xx:xx"
- 时间格式跟随设备时制（12H/24H）
- SQLite 持久化 + 去重（alarmIndex + timestamp + status）
- 只从完整记录帧(0x65)入库（不从实时事件入库）
- 实时接收设备上报更新

### 6.4 用药通知处理
- type=1（响铃）：前台弹窗"请及时取药"
- type=2（超时）：本地推送漏服通知
- type=3（取药）：前台弹窗鼓励

### 6.5 FAQ 页面
- 常见问题解答（中/英/德三语）

---

## 7. 跨平台一致性

| 维度 | iOS | Android |
|------|-----|---------|
| 单例 | `BlueSDK.shared` | `BlueSDK.getInstance(context)` |
| 回调 | `BlueSDKDelegate` protocol | `BlueSDKListener` interface |
| 方法可选 | extension 默认实现 | interface 默认空方法体 |
| 观察者引用 | NSHashTable 弱引用 | MutableList 强引用（需手动移除） |
| 密钥存储 | Keychain（卸载不丢） | ANDROID_ID 确定性生成（卸载不变） |
| 错误类型 | `enum BlueError` + associated value | `sealed class BlueError` |
| 时间参数 | `Date` | `Date`（原 Long 已改） |
| 周类型 | `WeekDays: OptionSet` | `Set<WeekDay>` |
| 扫描模式 | `ScanEvent` enum | `ScanEvent` sealed class |

---

## 8. 非功能需求

- **NFR01**: 初始化耗时 ≤ 100ms
- **NFR02**: 指令响应超时 5 秒，最多重试 3 次
- **NFR03**: 连接超时 15 秒
- **NFR04**: 最小指令间隔 200ms
- **NFR05**: 所有回调主线程派发
- **NFR06**: 密钥不落盘日志
- **NFR07**: 支持中/英/德三语
- **NFR08**: 交付为二进制产物（源码不可见）
