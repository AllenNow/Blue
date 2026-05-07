# BlueSDK API 参考文档

**版本**: 0.1.0  
**最后更新**: 2026-05-07

---

## BlueSDK（主入口）

### 初始化

| 方法 | iOS | Android | 说明 |
|------|-----|---------|------|
| 获取实例 | `BlueSDK.shared` | `BlueSDK.getInstance(context)` | 单例 |
| 初始化 | `initialize()` | `initialize()` | 必须首先调用 |
| 销毁 | `destroy()` | `destroy()` | 释放所有 BLE 资源 |

### 日志配置

| 方法 | iOS | Android | 说明 |
|------|-----|---------|------|
| 设置日志级别 | `setLogLevel(_ level: LogLevel)` | `setLogLevel(level: LogLevel)` | FR34 |
| 自定义日志处理器 | `setLogHandler(_ handler: BlueLogHandler?)` | `setLogHandler(handler: BlueLogHandler?)` | FR35 |

### 连接管理

| 方法 | iOS | Android | 说明 |
|------|-----|---------|------|
| 检查权限 | `checkPermissions() -> PermissionStatus` | `checkPermissions(): PermissionStatus` | FR07 |
| 查询连接状态 | `connectionState: ConnectionState` | `connectionState: ConnectionState` | FR06 |
| 断开连接 | `disconnect()` | `disconnect()` | FR03 |

### 认证

| 方法 | iOS | Android | 说明 |
|------|-----|---------|------|
| 密钥认证 | `authenticate(phoneMac:deviceMac:completion:)` | `authenticate(phoneMac, deviceMac, completion)` | FR08 |

### 设备信息与时间同步

| 方法 | iOS | Android | 说明 |
|------|-----|---------|------|
| 查询设备信息 | `queryDeviceInfo(completion:)` | `queryDeviceInfo(completion)` | FR12 |
| 同步时间 | `syncTime(date:completion:)` | `syncTime(timeMs, completion)` | FR14 |

### 闹钟管理

| 方法 | iOS | Android | 说明 |
|------|-----|---------|------|
| 设置闹钟 | `setAlarm(index:hour:minute:weekMask:completion:)` | `setAlarm(index, hour, minute, weekMask, completion)` | FR15 |
| 删除闹钟 | `deleteAlarm(index:completion:)` | `deleteAlarm(index, completion)` | FR16 |
| 清空所有闹钟 | `clearAllAlarms(completion:)` | `clearAllAlarms(completion)` | FR17 |

### 用药事件

| 方法 | iOS | Android | 说明 |
|------|-----|---------|------|
| 下发用药通知 | `sendMedicationNotification(status:completion:)` | `sendMedicationNotification(status, completion)` | FR24 |

### 音频与系统设置

| 方法 | iOS | Android | 说明 |
|------|-----|---------|------|
| 设置音量 | `setVolume(_ level:completion:)` | `setVolume(level, completion)` | FR25 |
| 设置铃声类型 | `setSoundType(_ type:completion:)` | `setSoundType(type, completion)` | FR26 |
| 设置静音 | `setSilence(_ enabled:completion:)` | `setSilence(enabled, completion)` | FR28 |
| 设置持续时长 | `setAlertDuration(_ minutes:completion:)` | `setAlertDuration(minutes, completion)` | FR29 |
| 设置时间格式 | `setTimeFormat(_ format:completion:)` | `setTimeFormat(format, completion)` | FR30 |

---

## BlueSDKDelegate / BlueSDKListener（事件回调）

所有回调在**主线程**派发。

| 回调 | iOS（Delegate） | Android（Listener） | 说明 |
|------|----------------|---------------------|------|
| 连接状态变化 | `blueSDK(_:didChangeConnectionState:)` | `onConnectionStateChanged(state)` | FR04 |
| 认证结果 | `blueSDK(_:didAuthenticateWithSuccess:error:)` | `onAuthResult(success, error)` | FR09 |
| 设备信息 | `blueSDK(_:didReceiveDeviceInfo:)` | `onDeviceInfoReceived(info)` | FR12 |
| 时间同步请求 | `blueSDKDidRequestTimeSync(_:)` | `onTimeSyncRequested()` | FR13 |
| 闹钟变更上报 | `blueSDK(_:didUpdateAlarm:)` | `onAlarmUpdated(alarm)` | FR18 |
| 闹钟响铃 | `blueSDK(_:didAlarmRinging:alarmInfo:)` | `onAlarmRinging(alarmIndex, alarmInfo)` | FR20 |
| 闹钟超时 | `blueSDK(_:didAlarmTimeout:alarmInfo:)` | `onAlarmTimeout(alarmIndex, alarmInfo)` | FR21 |
| 用药结果 | `blueSDK(_:didReceiveMedicationResult:status:)` | `onMedicationResult(alarmIndex, status)` | FR22 |
| 用药记录 | `blueSDK(_:didReceiveMedicationRecord:)` | `onMedicationRecordReported(record)` | FR23 |
| 铃声类型变更 | `blueSDK(_:didChangeSoundType:)` | `onSoundTypeChanged(type)` | FR27 |
| 时间格式变更 | `blueSDK(_:didChangeTimeFormat:)` | `onTimeFormatChanged(format)` | FR31 |

---

## 枚举类型

### ConnectionState

| 值 | iOS | Android | 说明 |
|----|-----|---------|------|
| 已断开 | `.disconnected` | `DISCONNECTED` | 初始状态 |
| 连接中 | `.connecting` | `CONNECTING` | |
| 已连接（未认证）| `.connected` | `CONNECTED` | |
| 已认证 | `.authenticated` | `AUTHENTICATED` | 可执行业务指令 |
| 重连中 | `.reconnecting` | `RECONNECTING` | 断线自动重连 |

### MedicationStatus

| 值 | iOS | Android | 协议值 |
|----|-----|---------|--------|
| 按时取药 | `.taken` | `TAKEN` | `0x01` |
| 超时取药 | `.timeout` | `TIMEOUT` | `0x02` |
| 漏服 | `.missed` | `MISSED` | `0x03` |
| 提前取药 | `.early` | `EARLY` | `0x04` |

### LogLevel

| 值 | iOS | Android | 说明 |
|----|-----|---------|------|
| 关闭 | `.none` | `NONE` | 默认 |
| 错误 | `.error` | `ERROR` | |
| 警告 | `.warn` | `WARN` | |
| 信息 | `.info` | `INFO` | |
| 调试 | `.debug` | `DEBUG` | 输出原始帧数据 |

### VolumeLevel

| 值 | iOS | Android | 协议值 |
|----|-----|---------|--------|
| 低 | `.low` | `LOW` | `0x01` |
| 中 | `.medium` | `MEDIUM` | `0x02` |
| 高 | `.high` | `HIGH` | `0x03` |

### SoundType

| 值 | iOS | Android | 协议值 |
|----|-----|---------|--------|
| 静音 | `.mute` | `MUTE` | `0x00` |
| 类型A | `.typeA` | `TYPE_A` | `0x01` |
| 类型B | `.typeB` | `TYPE_B` | `0x02` |
| 类型C | `.typeC` | `TYPE_C` | `0x03` |

### TimeFormat

| 值 | iOS | Android | 协议值 |
|----|-----|---------|--------|
| 12小时制 | `.hour12` | `HOUR_12` | `0x00` |
| 24小时制 | `.hour24` | `HOUR_24` | `0x01` |

### PermissionStatus

| 值 | iOS | Android | 说明 |
|----|-----|---------|------|
| 已授权 | `.granted` | `GRANTED` | |
| 已拒绝 | `.denied` | `DENIED` | |
| 未请求 | `.notDetermined` | `NOT_DETERMINED` | |

---

## 数据模型

### AlarmInfo

| 字段 | 类型 | 说明 |
|------|------|------|
| index | Int | 闹钟槽位（1~7）|
| hour | Int | 小时（0~23）|
| minute | Int | 分钟（0~59）|
| weekMask | Int | 星期掩码（bit0=周日...bit6=周六）|
| advanceStatus | Int | 提前取药状态 |
| isDeleted | Bool | 是否为删除状态（字段全为0xFF）|

### MedicationRecord

| 字段 | 类型 | 说明 |
|------|------|------|
| timestamp | TimeInterval / Long | Unix 时间戳（iOS: 秒，Android: 毫秒）|
| alarmIndex | Int | 关联闹钟槽位（1~7）|
| status | MedicationStatus | 用药状态 |

### DeviceInfo

| 字段 | 类型 | 说明 |
|------|------|------|
| firmwareVersion | String | 固件版本号（如 "1.0.0"）|
| deviceId | String | 设备 MAC 地址 |

---

## BlueError

### iOS（enum）

```swift
public enum BlueError: Int, Error {
    case notInitialized    // SDK 未初始化
    case notAuthenticated  // 设备未认证
    case authFailed        // 认证失败
    case timeout           // 指令超时
    case permissionDenied  // 权限未授权
    case invalidParameter  // 参数无效
    case protocolError     // 协议错误
    case bleError          // 系统 BLE 错误
    case disconnected      // 设备已断开
}
```

### Android（sealed class）

```kotlin
sealed class BlueError(val message: String) {
    object NotInitialized : BlueError("SDK 未初始化")
    object NotAuthenticated : BlueError("设备未认证")
    object AuthFailed : BlueError("认证失败")
    object Timeout : BlueError("指令超时")
    object PermissionDenied : BlueError("权限未授权")
    object InvalidParameter : BlueError("参数无效")
    object ProtocolError : BlueError("协议错误")
    object Disconnected : BlueError("设备已断开")
    data class BleError(val cause: Throwable) : BlueError("BLE 错误")
}
```
