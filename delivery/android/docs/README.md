# BlueSDK Android

LX-PD02 智能药盒蓝牙通信 SDK（Android 原生 Kotlin）

## 系统要求

- Android 5.0+（API 21+）
- Kotlin 1.9+
- Bluetooth 5.0+ 硬件

## 集成方式

### 本地 AAR（推荐）

将 `blue-sdk-release.aar` 放入 `app/libs/` 目录，在 `build.gradle.kts` 中添加：

```kotlin
dependencies {
    implementation(files("libs/blue-sdk-release.aar"))
}
```

### 本地模块依赖（开发阶段）

```kotlin
// settings.gradle.kts
include(":blue-sdk")

// app/build.gradle.kts
dependencies {
    implementation(project(":blue-sdk"))
}
```

## 快速开始

### 1. 权限配置

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<!-- Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>
```

### 2. 初始化 SDK

```kotlin
// 在 Application.onCreate() 中调用一次
val config = BlueSDKConfig(
    fixedAuthKey = null,        // 固定密钥，null 则自动计算
    logLevel = LogLevel.DEBUG,  // 日志级别
    autoAuthEnabled = true      // 连接后自动认证
)
BlueSDK.getInstance(this).initialize(config)
```

### 3. 扫描并连接设备

```kotlin
val sdk = BlueSDK.getInstance(context)
sdk.listener = myListener

// 扫描（10秒超时自动停止）
sdk.startScan(timeoutMs = 10000L) { event ->
    when (event) {
        is ScanEvent.DeviceFound -> {
            sdk.connect(event.device)  // 连接后 SDK 自动完成密钥认证
            sdk.stopScan()
        }
        is ScanEvent.Error -> { /* 处理错误 */ }
        is ScanEvent.Stopped -> { /* 扫描超时 */ }
    }
}
```

### 4. 监听事件回调

```kotlin
sdk.listener = object : BlueSDKListener {
    override fun onConnectionStateChanged(state: ConnectionState) {
        // DISCONNECTED → CONNECTING → CONNECTED → AUTHENTICATED
    }
    override fun onAuthResult(success: Boolean, error: BlueError?) {
        if (success) { /* 可以发送业务指令了 */ }
    }
    override fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) {
        // 设备闹钟响铃
    }
    override fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {
        // 用药结果（按时/超时/漏服/提前）
    }
}
```

### 5. 发送业务指令

```kotlin
// 所有业务指令需在 AUTHENTICATED 状态后调用

// 设置闹钟（类型安全）
sdk.setAlarm(index = 1, hour = 8, minute = 0, days = WeekDays.WEEKDAYS) { result ->
    result.fold(
        onSuccess = { alarmInfo -> /* 设置成功 */ },
        onFailure = { error -> /* 处理错误 */ }
    )
}

// 批量设置闹钟
sdk.setAlarms(listOf(
    AlarmConfig(index = 1, hour = 8, minute = 0, days = WeekDays.WEEKDAYS),
    AlarmConfig(index = 2, hour = 12, minute = 30, days = WeekDays.ALL),
    AlarmConfig(index = 3, hour = 20, minute = 0, days = WeekDays.WEEKEND)
)) { result -> }

// 音频设置
sdk.setSoundType(SoundType.TYPE_A) { }
sdk.setVolume(VolumeLevel.MEDIUM) { }
sdk.setTimeFormat(TimeFormat.HOUR_24) { }
sdk.setSilence(true) { }
sdk.setAlertDuration(5) { }  // 5分钟

// 设备控制
sdk.syncTime { }
sdk.queryDeviceInfo { result -> }
sdk.restoreFactory { }
```

## 架构概览

```
┌─────────────────────────────────────────────────────┐
│                    集成方 App                         │
├─────────────────────────────────────────────────────┤
│  BlueSDK (公开 API 入口)                             │
│  ├── BlueSDKConfig        配置                      │
│  ├── BlueSDKListener      事件回调                   │
│  └── BlueError            错误类型                   │
├─────────────────────────────────────────────────────┤
│  Manager 层（业务逻辑）                               │
│  ├── AuthManager          密钥认证                   │
│  ├── AlarmManager         闹钟管理 (7槽位)           │
│  ├── MedicationManager    用药事件                   │
│  ├── AudioManager         音频/系统设置              │
│  ├── DeviceManager        设备信息/时间同步           │
│  ├── ConnectionManager    连接状态机                 │
│  └── PermissionManager    权限检查                   │
├─────────────────────────────────────────────────────┤
│  Internal 层（基础设施）                              │
│  ├── CommandQueue         FIFO 串行指令队列          │
│  ├── CallbackDispatcher   主线程回调派发             │
│  ├── BlueLogger           分级日志 + 脱敏            │
│  ├── KeystoreHelper       phoneMac 持久化            │
│  └── LogFormatter         日志格式化                 │
├─────────────────────────────────────────────────────┤
│  Transport 层（协议通信）                             │
│  ├── BLEScanner           设备扫描                   │
│  ├── BLEConnector         GATT 连接/读写             │
│  ├── FrameBuilder         帧构建（55 AA...CRC8）     │
│  ├── FrameParser          帧解析 + CRC 校验          │
│  ├── StreamFrameParser    粘包/分包处理              │
│  ├── CRC8Calculator       校验算法                   │
│  ├── CommandCode          CMD 命令字常量             │
│  ├── DPIDConstants        DPID 功能字节常量          │
│  └── FrameConstants       帧格式常量                 │
└─────────────────────────────────────────────────────┘
                        ↕ BLE
┌─────────────────────────────────────────────────────┐
│              LX-PD02 智能药盒硬件                     │
└─────────────────────────────────────────────────────┘
```

## 连接状态机

```
                    connect()
 DISCONNECTED ──────────────────→ CONNECTING
      ↑                                │
      │ disconnect()                   │ GATT 连接成功
      │ 重连失败(5次)                    ↓
      ←──────────────────────── CONNECTED
      ↑                                │
      │                                │ 自动密钥认证
      │        意外断线                  ↓
 RECONNECTING ←──────────────── AUTHENTICATED
      │                                │
      │     2s/4s/8s 指数退避            │ disconnect()
      └────────→ CONNECTING ←──────────┘ (不触发重连)
```

**状态说明：**
- `DISCONNECTED` — 初始状态，可调用 `connect()`
- `CONNECTING` — 正在建立 GATT 连接（15秒超时）
- `CONNECTED` — GATT 就绪，SDK 自动发起认证
- `AUTHENTICATED` — 认证通过，可执行所有业务指令
- `RECONNECTING` — 意外断线后自动重连（最多5次）

## 线程模型

- **所有 `BlueSDKListener` 回调在主线程派发**，集成方无需手动切换线程
- **API 方法的 `completion` 回调可能在 BLE 线程触发**，如需操作 UI 请使用 `runOnUiThread`
- 内部 BLE 操作在系统蓝牙线程执行
- `CommandQueue` 保证同一时刻只有一条指令在等待应答（FIFO 串行）
- 指令间隔 200ms，超时 5 秒自动重试，最多重试 3 次
- SDK 本身线程安全，所有公开方法可在任意线程调用

## 公开 API 参考

### 生命周期

| 方法 | 说明 |
|------|------|
| `initialize(config)` | 初始化 SDK（Application 中调用一次） |
| `destroy()` | 释放所有 BLE 资源 |

### 连接管理

| 方法 | 说明 |
|------|------|
| `startScan(timeoutMs, callback)` | 扫描 BLE 设备（统一 ScanEvent 回调） |
| `stopScan()` | 停止扫描 |
| `connect(device)` | 连接设备（自动认证） |
| `disconnect()` | 主动断开（不触发重连） |
| `cancelReconnection()` | 取消自动重连 |
| `clearBinding()` | 清除本地绑定密钥 |
| `authenticateWithKey(high, low)` | 指定密钥认证 |
| `checkPermissions()` | 查询蓝牙权限状态 |
| `connectionState` | 当前连接状态（属性） |

### 设备信息

| 方法 | 说明 | 前置条件 |
|------|------|----------|
| `queryDeviceInfo(completion)` | 查询 MAC + 固件版本 | 已初始化 |
| `syncTime(completion)` | 下发系统时间 | 已认证 |

### 闹钟管理

| 方法 | 说明 | 前置条件 |
|------|------|----------|
| `setAlarm(index, hour, minute, days, completion)` | 设置闹钟（1~7） | 已认证 |
| `setAlarms(list, completion)` | 批量设置 | 已认证 |
| `deleteAlarm(index, completion)` | 删除闹钟 | 已认证 |
| `clearAllAlarms(completion)` | 清空全部 | 已认证 |

### 音频与系统

| 方法 | 说明 | 前置条件 |
|------|------|----------|
| `setVolume(level, completion)` | 音量（LOW/MEDIUM/HIGH） | 已认证 |
| `setSoundType(type, completion)` | 铃声（TYPE_A/B/C/MUTE） | 已认证 |
| `setSilence(enabled, completion)` | 静音开关 | 已认证 |
| `setAlertDuration(minutes, completion)` | 提醒持续时间 | 已认证 |
| `setTimeFormat(format, completion)` | 时制（HOUR_12/HOUR_24） | 已认证 |
| `restoreFactory(completion)` | 恢复出厂设置 | 已认证 |

### 用药事件

| 方法 | 说明 | 前置条件 |
|------|------|----------|
| `sendMedicationNotification(status, completion)` | 下发用药结果通知 | 已认证 |

### 日志

| 方法 | 说明 |
|------|------|
| `setLogLevel(level)` | 设置日志级别 |
| `setLogHandler(handler)` | 自定义日志处理器 |
| `exportLog(maxLines)` | 导出最近日志（最多1000条） |
| `clearLogBuffer()` | 清空日志缓冲区 |

## 错误处理

所有异步操作通过 `Result<T>` 回调返回，不抛出异常。

```kotlin
sdk.setAlarm(1, 8, 0) { result ->
    result.fold(
        onSuccess = { info -> /* 成功 */ },
        onFailure = { error ->
            val blueError = error as BlueError
            Log.e("SDK", "${blueError.message} | 建议：${blueError.recoverySuggestion}")
        }
    )
}
```

### 错误类型

| 错误 | Code | 说明 | 恢复建议 |
|------|------|------|----------|
| `NotInitialized` | 1 | SDK 未初始化 | 先调用 `initialize()` |
| `NotAuthenticated` | 2 | 未完成认证 | 等待自动认证完成或检查密钥配置 |
| `AuthFailed` | 3 | 密钥不匹配 | 检查 fixedAuthKey 或对设备恢复出厂 |
| `Timeout` | 4 | 指令超时（5秒×3次） | 确认设备在 3 米内且电量充足 |
| `PermissionDenied` | 5 | 蓝牙权限未授权 | Android 12+ 需 BLUETOOTH_SCAN + CONNECT |
| `InvalidParameter` | 6 | 参数无效 | 检查闹钟索引 1~7、小时 0~23、分钟 0~59 |
| `ProtocolError` | 7 | 帧 CRC 校验失败 | 可能是蓝牙干扰，断开重连后重试 |
| `BleError` | 8 | 系统蓝牙异常 | 确认蓝牙已开启，尝试重启蓝牙 |
| `Disconnected` | 9 | 连接已断开 | SDK 会自动重连，或手动调用 connect() |

## 常见问题 FAQ

### 华为手机扫描不到设备

Android 6~11 需要**开启位置服务**才能执行 BLE 扫描（系统限制，非 SDK 问题）。扫描前提示用户开启 GPS。

### 小米手机后台断连

MIUI 的"省电优化"会杀后台蓝牙连接。需要：
1. 在"自启动管理"中允许 APP
2. 在"电量和性能"中关闭该 APP 的"省电优化"
3. 将 APP 锁定在最近任务列表中

### 认证失败怎么办

1. 检查 `BlueSDKConfig.fixedAuthKey` 是否正确（4位十六进制，如 "05FA"）
2. 如果设备已被其他手机绑定，需对设备**长按按键恢复出厂设置**
3. 恢复后在 APP 中调用 `clearBinding()` 清除本地旧密钥

### 多个指令如何发送

SDK 内部 `CommandQueue` 自动串行排队，集成方可以连续调用多个指令，无需手动等待上一个完成：

```kotlin
sdk.setAlarm(1, 8, 0) { }
sdk.setAlarm(2, 12, 30) { }   // 自动排队，等第一个完成后发送
sdk.setSoundType(SoundType.TYPE_A) { }  // 继续排队
```

### 设备端时间同步请求

设备可能主动请求时间同步（如断电重启后）。SDK 已自动处理（30秒节流），集成方无需干预。如需感知此事件，实现 `onTimeSyncRequested()` 回调即可。

## 协议参考

### 帧格式

```
[0x55][0xAA][版本=0x00][CMD][LenHigh][LenLow][Data...][CRC8]
```

- **CRC8**：从第一字节到数据最后一字节，逐字节累加对 256 求余
- **最小帧**：7 字节（无数据时 Len=0x0000）

### CMD 命令字

| CMD | 方向 | 用途 |
|-----|------|------|
| 0x00 | APP→设备 | 密钥认证 |
| 0x01 | APP→设备 | 查询设备信息 |
| 0x06 | APP→设备 | 下发配置指令 |
| 0x07 | 设备→APP | 设备主动上报 |
| 0xE1 | 双向 | 时间同步 |

### DPID 功能字节

| DPID | 用途 | 数据格式 |
|------|------|----------|
| 0x65 | 用药记录上报 | 15字节（闹钟DP+年月日时分+状态） |
| 0x66~0x6C | 闹钟1~7 | `XX 00 00 07 01 HH MM WW 00 00 00` |
| 0x6D | 声音类型上报 | 设备→APP (1=A, 2=B) |
| 0x6E | 音量/持续时间 | type=04 音量 / type=02 持续时间 |
| 0x6F | 铃声设置 | `6F 04 00 01 XX` (01=A/02=B/03=C) |
| 0x70 | 清空闹钟 | `70 01 00 01 01` |
| 0x73 | 时制 | `73 04 00 01 XX` (00=12H/01=24H) |
| 0x74 | 静音 | `74 04 00 01 XX` (00=关/01=开) |
| 0x75 | 低电上报 | 设备→APP (只上报) |
| 0x71 | 恢复出厂 | `71 01 00 01 01` |

## 项目结构

```
blue-sdk-android/
├── blue-sdk/                    # SDK Library 模块
│   └── src/main/kotlin/com/blue/sdk/
│       ├── BlueSDK.kt           # 公开 API 入口（单例）
│       ├── BlueSDKConfig.kt     # 初始化配置
│       ├── BlueSDKListener.kt   # 事件回调接口
│       ├── enums/               # 枚举类型
│       ├── error/               # BlueError
│       ├── internal/            # 内部组件
│       ├── manager/             # 业务管理器
│       ├── model/               # 数据模型
│       └── transport/           # BLE 传输协议层
└── app/                         # Demo App
    └── src/main/kotlin/com/blue/demo/
        ├── MainActivity.kt              # 主控台
        ├── AlarmManagerActivity.kt      # 闹钟管理（7槽位编辑）
        ├── MedicationRecordsActivity.kt # 用药记录（日历+SQLite）
        ├── ProtocolTestActivity.kt      # 协议自动化验证（15用例）
        ├── MedicationDatabase.kt        # SQLite 持久化
        └── DemoApplication.kt           # SDK 初始化
```

## Demo App

Demo 应用演示了 SDK 全部功能，可直接作为集成参考：

- **主页**：扫描连接 + 全指令操作面板 + 实时日志
- **闹钟管理**：7 个槽位列表，TimePicker 设置时间，多选星期
- **用药记录**：DatePicker 按日期查询，SQLite 持久化，支持切换全部/按日
- **协议验证**：15 条测试用例自动化执行，收发帧实时日志

运行 Demo：
```bash
# Android Studio 打开 blue-sdk-android/ 目录
# 选择 app 模块 → 连接真机 → Run
```

> ⚠️ BLE 不支持模拟器，必须使用支持蓝牙 5.0 的真机测试

## 版本历史

参见 [CHANGELOG.md](./CHANGELOG.md)

## License

MIT
