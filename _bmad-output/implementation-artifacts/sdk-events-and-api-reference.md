# BlueSDK 事件、接口与数据结构参考

## 事件回调总览

SDK 通过多播观察者模式派发事件。所有回调在**主线程**执行。

| # | 事件 | Android 方法 | iOS 方法 | 触发时机 |
|---|------|-------------|----------|---------|
| 1 | 连接状态变化 | `onConnectionStateChanged(state)` | `blueSDK(_:didChangeConnectionState:)` | BLE 连接/断开/重连 |
| 2 | 认证结果 | `onAuthResult(success, error)` | `blueSDK(_:didAuthenticateWithSuccess:error:)` | 密钥认证完成 |
| 3 | 设备信息 | `onDeviceInfoReceived(info)` | `blueSDK(_:didReceiveDeviceInfo:)` | queryDeviceInfo 应答 |
| 4 | 时间同步请求 | `onTimeSyncRequested()` | `blueSDKDidRequestTimeSync(_:)` | 设备请求同步时间 |
| 5 | 闹钟配置变更 | `onAlarmUpdated(alarm)` | `blueSDK(_:didUpdateAlarm:)` | 设备上报闹钟设置 |
| 6 | 闹钟响铃 | `onAlarmRinging(index, alarmInfo)` | `blueSDK(_:didAlarmRinging:alarmInfo:)` | 闹钟触发响铃 |
| 7 | 闹钟超时 | `onAlarmTimeout(index, alarmInfo)` | `blueSDK(_:didAlarmTimeout:alarmInfo:)` | 响铃超时无操作 |
| 8 | 用药结果（实时） | `onMedicationResult(index, status)` | `blueSDK(_:didReceiveMedicationResult:status:)` | 用户取药/漏服瞬间 |
| 9 | 用药记录（完整） | `onMedicationRecordReported(record)` | `blueSDK(_:didReceiveMedicationRecord:)` | 设备上报完整历史记录 |
| 10 | 铃声类型变更 | `onSoundTypeChanged(type)` | `blueSDK(_:didChangeSoundType:)` | 设备上报铃声配置 |
| 11 | 时间格式变更 | `onTimeFormatChanged(format)` | `blueSDK(_:didChangeTimeFormat:)` | 设备上报 12/24H |
| 12 | 低电量 | `onLowBattery()` | `blueSDKDidReportLowBattery(_:)` | 设备电量低 |
| 13 | 设备解绑 | `onDeviceUnbound()` | `blueSDKDidReportDeviceUnbound(_:)` | 设备端执行解绑 |
| 14 | 连接错误 | `onError(error)` | `blueSDK(_:didEncounterError:)` | 超时/BLE 错误等 |
| 15 | 正在重连 | `onReconnecting(attempt, max)` | `blueSDK(_:didStartReconnecting:maxAttempts:)` | 自动重连中 |
| 16 | 重连失败 | `onReconnectFailed()` | `blueSDKDidFailReconnection(_:)` | 达到最大重连次数 |

---

## 数据结构

### ConnectionState（连接状态枚举）

| 值 | 含义 |
|----|------|
| `DISCONNECTED` / `.disconnected` | 已断开 |
| `CONNECTING` / `.connecting` | 连接中 |
| `CONNECTED` / `.connected` | 已连接（未认证） |
| `AUTHENTICATED` / `.authenticated` | 已认证（可执行业务） |
| `RECONNECTING` / `.reconnecting` | 自动重连中 |

### AlarmInfo（闹钟信息）

| 字段 | 类型 | 说明 |
|------|------|------|
| `index` | Int | 闹钟槽位 1~7 |
| `hour` | Int | 小时 0~23 |
| `minute` | Int | 分钟 0~59 |
| `weekMask` | Int | 星期掩码 bit0=周一...bit6=周日 |
| `advanceStatus` | Int | 预告状态 |

### MedicationRecord（用药记录）

| 字段 | 类型 | 说明 |
|------|------|------|
| `timestamp` | Int64/Long | 实际事件时间（Unix ms） |
| `alarmIndex` | Int | 对应闹钟槽位 1~7 |
| `alarmHour` | Int | 闹钟设定小时（应该吃药的时间） |
| `alarmMinute` | Int | 闹钟设定分钟 |
| `status` | MedicationStatus | 用药结果 |

### MedicationStatus（用药状态枚举）

| 协议值 | Android | iOS | 含义 |
|--------|---------|-----|------|
| 0x01 | `TAKEN` | `.taken` | 按时取药 |
| 0x02 | `TIMEOUT` | `.timeout` | 超时取药 |
| 0x03 | `MISSED` | `.missed` | 漏服 |
| 0x04 | `EARLY` | `.early` | 提前取药 |

### SoundType（铃声类型枚举）

| Android | iOS | 含义 |
|---------|-----|------|
| `TYPE_A` | `.typeA` | 铃声 A |
| `TYPE_B` | `.typeB` | 铃声 B |

### TimeFormat（时间格式枚举）

| Android | iOS | 含义 |
|---------|-----|------|
| `HOUR_12` | `.hour12` | 12 小时制 |
| `HOUR_24` | `.hour24` | 24 小时制 |

### VolumeLevel（音量等级枚举）

| Android | iOS | 含义 |
|---------|-----|------|
| `LOW` | `.low` | 低 |
| `MEDIUM` | `.medium` | 中 |
| `HIGH` | `.high` | 高 |

### DeviceInfo（设备信息）

| 字段 | 类型 | 说明 |
|------|------|------|
| `firmwareVersion` | String | 固件版本号（如 "1.0.0"） |
| `macAddress` | ByteArray/[UInt8] | 设备 MAC 地址（6字节） |

### BlueError（错误类型）

| 错误码 | Android | iOS | 说明 | 恢复建议 |
|--------|---------|-----|------|---------|
| 1 | `NotInitialized` | `.notInitialized` | SDK 未初始化 | 先调用 initialize() |
| 2 | `NotAuthenticated` | `.notAuthenticated` | 未认证 | 等待自动认证完成 |
| 3 | `AuthFailed` | `.authFailed` | 认证失败 | 检查密钥或恢复出厂 |
| 4 | `Timeout` | `.timeout` | 指令超时 | 确认设备在范围内 |
| 5 | `PermissionDenied` | `.permissionDenied` | 权限未授权 | 授予蓝牙权限 |
| 6 | `InvalidParameter` | `.invalidParameter` | 参数无效 | 检查参数范围 |
| 7 | `ProtocolError` | `.protocolError` | 协议错误 | 断开重连 |
| 8 | `BleError` | `.bleError(underlying:)` | 系统 BLE 错误 | 重启蓝牙 |
| 9 | `Disconnected` | `.disconnected` | 设备断开 | 重新连接 |

---

## 公开 API 方法

### 生命周期

| 方法 | 说明 |
|------|------|
| `initialize(config)` | 初始化 SDK |
| `destroy()` | 销毁释放资源 |

### 连接管理

| 方法 | 说明 |
|------|------|
| `startScan(timeout, callback)` | 扫描设备 |
| `stopScan()` | 停止扫描 |
| `connect(device)` | 连接设备 |
| `disconnect()` | 断开连接 |
| `cancelReconnection()` | 取消自动重连 |
| `checkPermissions()` | 查询蓝牙权限 |

### 认证与绑定

| 方法 | 说明 |
|------|------|
| `authenticateWithKey(keyHigh, keyLow)` | 手动密钥认证（高级） |
| `clearBinding(completion)` | 解绑设备（发送 0xA1 指令） |

### 设备信息

| 方法 | 说明 |
|------|------|
| `queryDeviceInfo(completion)` | 查询设备信息 |
| `syncTime(date, completion)` | 同步时间 |

### 闹钟管理

| 方法 | 说明 |
|------|------|
| `setAlarm(index, hour, minute, days, completion)` | 设置闹钟 |
| `deleteAlarm(index, completion)` | 删除闹钟 |
| `clearAllAlarms(completion)` | 清空所有闹钟 |
| `setAlarms(alarms, completion)` | 批量设置闹钟 |

### 音频与系统

| 方法 | 说明 |
|------|------|
| `setVolume(level, completion)` | 设置音量 |
| `setSoundType(type, completion)` | 设置铃声 |
| `setSilence(enabled, completion)` | 设置静音 |
| `setAlertDuration(minutes, completion)` | 设置提醒时长 |
| `setTimeFormat(format, completion)` | 设置时间格式 |
| `restoreFactory(completion)` | 恢复出厂设置 |

### 用药通知

| 方法 | 说明 |
|------|------|
| `sendMedicationNotification(status, completion)` | 下发用药结果通知 |

### 日志

| 方法 | 说明 |
|------|------|
| `setLogLevel(level)` | 设置日志级别 |
| `setLogHandler(handler)` | 自定义日志处理器 |

### 状态属性（只读）

| 属性 | 类型 | 说明 |
|------|------|------|
| `connectionState` | ConnectionState | 当前连接状态 |
| `currentTimeFormat` | TimeFormat | 当前设备时制 |
| `currentAuthKeyDisplay` | String | 当前密钥展示 |

### 配置属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `config` | BlueSDKConfig | SDK 配置（可运行时修改） |
| `fixedAuthKey` | String? | 固定密钥（简写访问） |
| `listener` / `delegate` | 接口/协议 | 主事件回调 |

---

## 观察者注册

```swift
// iOS
BlueSDK.shared.addObserver(self)    // 注册（弱引用）
BlueSDK.shared.removeObserver(self) // 移除（可选）
```

```kotlin
// Android
sdk.addObserver(observer)    // 注册（强引用）
sdk.removeObserver(observer) // 移除（必须）
```

支持无限数量观察者，与主 delegate/listener 同时接收事件。
