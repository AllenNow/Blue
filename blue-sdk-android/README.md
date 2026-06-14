# BlueSDK Android

LX-PD02 智能药盒蓝牙通信 SDK（Android 原生 Kotlin）

## 系统要求

- Android 5.0+（API 21+）
- Kotlin 1.9+
- Bluetooth 5.0+ 硬件

## 项目结构

```
blue-sdk-android/
├── blue-sdk/          # SDK Library 模块
│   └── src/main/kotlin/com/blue/sdk/
│       ├── BlueSDK.kt              # 公开 API 入口（单例）
│       ├── BlueSDKListener.kt      # 事件回调接口
│       ├── enums/                   # 枚举（ConnectionState、SoundType 等）
│       ├── error/BlueError.kt      # 错误类型
│       ├── internal/               # 内部组件（CommandQueue、KeyStorage 等）
│       ├── manager/                # 业务管理器（Auth、Alarm、Audio 等）
│       ├── model/                  # 数据模型（AlarmInfo、DeviceInfo 等）
│       └── transport/              # 传输协议层（BLE、帧构建/解析）
└── app/               # Demo App
    └── src/main/kotlin/com/blue/demo/
        ├── MainActivity.kt             # 主控台
        ├── AlarmManagerActivity.kt     # 闹钟管理
        ├── MedicationRecordsActivity.kt # 用药记录
        ├── ProtocolTestActivity.kt     # 协议验证
        └── MedicationDatabase.kt       # SQLite 持久化
```

## 快速开始

### 初始化

```kotlin
// Application 中
BlueSDK.getInstance(this).initialize()
BlueSDK.getInstance(this).setLogLevel(LogLevel.DEBUG)
```

### 扫描连接（自动认证）

```kotlin
val sdk = BlueSDK.getInstance(this)
sdk.listener = this

sdk.startScan(
    onDeviceFound = { device ->
        sdk.connect(device)  // 连接成功后 SDK 自动完成密钥认证
        sdk.stopScan()
    },
    onError = { error -> /* 处理错误 */ }
)
```

连接成功后 SDK 自动：
1. 从 SharedPreferences 读取/生成 phoneMac（6字节）
2. 用设备蓝牙 MAC + phoneMac 计算密钥（12字节累加取16-bit总和）
3. 发送认证帧，成功后状态变为 `AUTHENTICATED`

### 操作指令

```kotlin
// 设置闹钟（需认证后调用）
sdk.setAlarm(1, 8, 0, 0x7F) { result -> }

// 设置铃声类型
sdk.setSoundType(SoundType.TYPE_A) { result -> }

// 同步时间
sdk.syncTime { result -> }

// 恢复出厂
sdk.restoreFactory { result -> }
```

## 公开 API

| 方法 | 功能 |
|------|------|
| `initialize()` / `destroy()` | 生命周期 |
| `startScan()` / `stopScan()` | 设备扫描 |
| `connect(device)` / `disconnect()` | 连接管理（含自动认证） |
| `clearBinding()` | 清除本地绑定密钥 |
| `authenticateWithKey(h, l)` | 使用指定密钥认证 |
| `queryDeviceInfo()` | 查询设备 MAC 和固件版本 |
| `syncTime()` | 时间同步（fire-and-forget） |
| `setAlarm()` / `deleteAlarm()` / `clearAllAlarms()` | 闹钟管理（7槽位） |
| `setVolume(level)` | 音量（低/中/高） |
| `setSoundType(type)` | 铃声（A/B/C） |
| `setTimeFormat(format)` | 时制（12H/24H） |
| `setSilence(enabled)` | 静音开关 |
| `setAlertDuration(minutes)` | 提醒持续时间 |
| `restoreFactory()` | 恢复出厂设置 |

## 事件回调（BlueSDKListener）

```kotlin
interface BlueSDKListener {
    fun onConnectionStateChanged(state: ConnectionState)
    fun onAuthResult(success: Boolean, error: BlueError?)
    fun onTimeSyncRequested()
    fun onAlarmUpdated(alarm: AlarmInfo)
    fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo)
    fun onAlarmTimeout(alarmIndex: Int, alarmInfo: AlarmInfo)
    fun onMedicationResult(alarmIndex: Int, status: MedicationStatus)
    fun onMedicationRecordReported(record: MedicationRecord)
    fun onSoundTypeChanged(type: SoundType)
    fun onTimeFormatChanged(format: TimeFormat)
}
```

## 协议 DPID 参考

| DPID | 用途 | 帧格式 |
|------|------|--------|
| 0x66~0x6C | 闹钟1~7 | `XX 00 00 07 01 HH MM WW 00 00 00` |
| 0x6E | 音量设置 | `6E 04 00 01 XX` (01低/02中/03高) |
| 0x6F | 铃声类型 | `6F 04 00 01 XX` (01=A/02=B/03=C) |
| 0x70 | 提醒持续时间 | `70 02 00 04 00 00 00 XX` |
| 0x73 | 时制 | `73 04 00 01 XX` (00=12H/01=24H) |
| 0x74 | 静音 | `74 04 00 01 XX` (00=关/01=开) |
| 0x76 | 恢复出厂 | `76 01 00 01 01` |

## 权限配置

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>
```

## Demo App 功能

- **主页**：紧凑单页布局，连接状态 + Loading 遮罩 + 全指令操作 + SDK 日志
- **闹钟管理**：7槽位列表，TimePicker 编辑，长按删除
- **用药记录**：CalendarView 按日期查询，SQLite 持久化
- **协议验证**：15条自动化测试，收发帧实时日志

## 构建

```bash
./gradlew :app:assembleDebug
```

## License

MIT
