# BlueSDK Android 集成指南

LX-PD02 智能药盒蓝牙通信 SDK（Android 原生 Kotlin/Java）

## 系统要求

- Android 5.0+（API 21）
- Kotlin 1.9+ 或 Java 8+
- Bluetooth 5.0+ 硬件

## 集成方式

将 `blue-sdk-release.aar` 放入项目 `libs/` 目录：

```kotlin
// build.gradle.kts
dependencies {
    implementation(files("libs/blue-sdk-release.aar"))
}
```

## 权限配置

```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>
```

## 快速开始

### 1. 初始化

```kotlin
// Application.onCreate() 中调用一次
BlueSDK.getInstance(this).initialize(BlueSDKConfig(
    logLevel = LogLevel.DEBUG
))
```

### 2. 扫描连接

```kotlin
val sdk = BlueSDK.getInstance(context)
sdk.listener = myListener

sdk.startScan(timeoutMs = 10000L) { event ->
    when (event) {
        is ScanEvent.DeviceFound -> {
            sdk.connect(event.device)
            sdk.stopScan()
        }
        is ScanEvent.Error -> { /* 处理错误 */ }
        is ScanEvent.Stopped -> { /* 扫描超时 */ }
    }
}
```

### 3. 连接流程（SDK 自动完成）

连接设备后，SDK 内部自动执行以下步骤，无需集成方干预：

```
扫描发现设备
    ↓
建立 BLE 连接（15秒超时）
    ↓
GATT 服务发现 + 特征订阅
    ↓
自动密钥认证（计算+发送+验证）
    ↓
认证成功 → 状态变为 AUTHENTICATED
    ↓
自动同步系统时间到设备
    ↓
可以发送业务指令
```

集成方只需关注 `onConnectionStateChanged` 和 `onAuthResult` 回调。

### 4. 监听事件

```kotlin
sdk.listener = object : BlueSDKListener {
    override fun onConnectionStateChanged(state: ConnectionState) {
        // DISCONNECTED → CONNECTING → CONNECTED → AUTHENTICATED
    }
    override fun onAuthResult(success: Boolean, error: BlueError?) {
        if (success) { /* 可以操作设备了 */ }
    }
    override fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) {
        // 设备闹钟响铃
    }
    override fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {
        // 用药结果
    }
}
```

### 5. 业务操作

```kotlin
// 设置闹钟
sdk.setAlarm(index = 1, hour = 8, minute = 0, days = WeekDays.WEEKDAYS) { result -> }

// 批量设置
sdk.setAlarms(listOf(
    AlarmConfig(1, 8, 0, WeekDays.WEEKDAYS),
    AlarmConfig(2, 12, 30, WeekDays.ALL),
    AlarmConfig(3, 20, 0, WeekDays.WEEKEND)
)) { result -> }

// 音频设置
sdk.setSoundType(SoundType.TYPE_A) { }
sdk.setVolume(VolumeLevel.MEDIUM) { }
sdk.setTimeFormat(TimeFormat.HOUR_24) { }
sdk.setSilence(true) { }
sdk.setAlertDuration(5) { }

// 设备控制
sdk.queryDeviceInfo { result -> }
sdk.restoreFactory { }
sdk.clearBinding { }
```

## 连接状态机

```
 DISCONNECTED ────→ CONNECTING ────→ CONNECTED ────→ AUTHENTICATED
      ↑                                                    │
      │                                                    │ 意外断线
      │         RECONNECTING ←─────────────────────────────┘
      │              │
      │              │ 2s/4s/8s 指数退避，最多 5 次
      └──────────────┘ 重连失败
```

| 状态 | 说明 |
|------|------|
| `DISCONNECTED` | 未连接，可调用 connect() |
| `CONNECTING` | 正在建立连接（15秒超时） |
| `CONNECTED` | BLE 已连接，SDK 正在自动认证 |
| `AUTHENTICATED` | 认证通过，可执行所有业务操作 |
| `RECONNECTING` | 意外断线后自动重连中 |

## 公开 API

### 生命周期

| 方法 | 说明 |
|------|------|
| `initialize(config)` | 初始化（Application 中调用一次） |
| `destroy()` | 释放资源 |

### 连接管理

| 方法 | 说明 |
|------|------|
| `startScan(timeoutMs, callback)` | 扫描设备 |
| `stopScan()` | 停止扫描 |
| `connect(device)` | 连接（自动认证+时间同步） |
| `disconnect()` | 断开连接 |
| `cancelReconnection()` | 取消自动重连 |
| `clearBinding()` | 解绑设备（清除配对） |
| `checkPermissions()` | 查询蓝牙权限状态 |
| `connectionState` | 当前状态 |

### 闹钟管理（需认证后调用）

| 方法 | 说明 |
|------|------|
| `setAlarm(index, hour, minute, days)` | 设置闹钟（1~7） |
| `setAlarms(list)` | 批量设置 |
| `deleteAlarm(index)` | 删除闹钟 |
| `clearAllAlarms()` | 清空全部 |
| `queryAlarm(index)` | 查询单个闹钟 |

### 音频与系统（需认证后调用）

| 方法 | 说明 |
|------|------|
| `setVolume(level)` | 音量（LOW/MEDIUM/HIGH） |
| `setSoundType(type)` | 铃声（TYPE_A/B/C/MUTE） |
| `setSilence(enabled)` | 静音开关 |
| `setAlertDuration(minutes)` | 提醒持续时间 |
| `setTimeFormat(format)` | 时制（12H/24H） |
| `restoreFactory()` | 恢复出厂 |

### 设备信息

| 方法 | 说明 | 前置条件 |
|------|------|----------|
| `queryDeviceInfo()` | 获取 MAC + 固件版本 | 已初始化 |
| `syncTime()` | 同步时间（连接后自动执行） | 已认证 |

### 用药事件

| 方法 | 说明 |
|------|------|
| `sendMedicationNotification(status)` | 下发用药结果通知 |

### 日志

| 方法 | 说明 |
|------|------|
| `setLogLevel(level)` | 日志级别 |
| `setLogHandler(handler)` | 自定义日志回调 |
| `exportLog(maxLines)` | 导出最近日志 |

## 事件回调（BlueSDKListener）

| 回调 | 触发时机 |
|------|----------|
| `onConnectionStateChanged` | 连接状态变化 |
| `onAuthResult` | 认证完成 |
| `onAlarmUpdated` | 设备闹钟配置变更 |
| `onAlarmRinging` | 闹钟响铃 |
| `onAlarmTimeout` | 闹钟超时未取药 |
| `onMedicationResult` | 用药结果（取药/超时/漏服/提前） |
| `onMedicationRecordReported` | 历史用药记录上报 |
| `onSoundTypeChanged` | 铃声变更 |
| `onTimeFormatChanged` | 时制变更 |
| `onLowBattery` | 设备低电 |
| `onReconnecting` | 正在重连 |
| `onReconnectFailed` | 重连失败 |

## 错误处理

```kotlin
sdk.setAlarm(1, 8, 0) { result ->
    result.fold(
        onSuccess = { /* 成功 */ },
        onFailure = { error ->
            val e = error as BlueError
            Log.e("SDK", "${e.message}")
            Log.e("SDK", "建议：${e.recoverySuggestion}")
        }
    )
}
```

| 错误 | 说明 | 恢复建议 |
|------|------|----------|
| `NotInitialized` | 未初始化 | 先调用 initialize() |
| `NotAuthenticated` | 未认证 | 等待自动认证完成 |
| `AuthFailed` | 密钥不匹配 | 设备恢复出厂后重试 |
| `Timeout` | 指令超时 | 确认设备在范围内 |
| `PermissionDenied` | 权限未授权 | 引导用户授权 |
| `InvalidParameter` | 参数无效 | 检查参数范围 |
| `Disconnected` | 连接已断开 | SDK 自动重连或手动 connect |

## 线程模型

- **BlueSDKListener 回调在主线程派发**
- API 的 completion 回调可能在 BLE 线程，操作 UI 需 `runOnUiThread`
- SDK 本身线程安全，可在任意线程调用
- 多条指令可连续调用，SDK 内部自动排队

## 常见问题

### 华为手机扫描不到设备
Android 6~11 需要开启「位置服务」（系统限制）。

### 小米手机后台断连
在「自启动管理」中允许 APP，关闭「省电优化」。

### 认证失败
设备已绑定其他手机 → 对设备恢复出厂 → APP 调用 clearBinding()。

### 多条指令如何发送
直接连续调用，SDK 内部自动串行排队，无需手动等待。

## SDK 技术指标

| 指标 | 数值 |
|------|------|
| AAR 大小 | ~120 KB |
| 初始化耗时 | < 100ms |
| 第三方依赖 | 零 |
| 最低系统 | Android 5.0 |

## 更多信息

- 详细变更记录：见 CHANGELOG.md
- 隐私说明：见 PRIVACY.md
- 集成验证清单：见 DELIVERY.md
- Demo App：完整功能参考实现（含源码）
