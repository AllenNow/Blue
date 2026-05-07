# BlueSDK Android 集成指南

**版本**: 0.1.0  
**最低系统**: Android 5.0（API Level 21）  
**最低蓝牙**: Bluetooth 5.0  
**语言**: Kotlin 1.9+（支持 Java 调用）

---

## 1. 集成方式

### 本地 AAR

将 `blue-sdk-x.x.x.aar` 放入 `app/libs/` 目录，在 `build.gradle.kts` 中添加：

```kotlin
dependencies {
    implementation(files("libs/blue-sdk-x.x.x.aar"))
}
```

### 本地模块依赖（开发阶段）

在 `settings.gradle.kts` 中：

```kotlin
include(":blue-sdk")
project(":blue-sdk").projectDir = File("../blue-sdk-android/blue-sdk")
```

在 `app/build.gradle.kts` 中：

```kotlin
dependencies {
    implementation(project(":blue-sdk"))
}
```

---

## 2. 权限配置

在 `AndroidManifest.xml` 中添加：

```xml
<!-- Android 6-11 -->
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<!-- Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>

<uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>
```

---

## 3. 初始化

在 `Application` 中：

```kotlin
import com.blue.sdk.BlueSDK
import com.blue.sdk.enums.LogLevel

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        BlueSDK.getInstance(this).initialize()
        // 开发阶段开启调试日志
        BlueSDK.getInstance(this).setLogLevel(LogLevel.DEBUG)
    }

    override fun onTerminate() {
        super.onTerminate()
        BlueSDK.getInstance(this).destroy()
    }
}
```

---

## 4. 注册事件监听

```kotlin
import com.blue.sdk.BlueSDKListener
import com.blue.sdk.enums.*
import com.blue.sdk.error.BlueError
import com.blue.sdk.model.*

class MainActivity : AppCompatActivity(), BlueSDKListener {

    private val sdk get() = BlueSDK.getInstance(this)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sdk.listener = this
    }

    override fun onDestroy() {
        super.onDestroy()
        sdk.listener = null
    }

    // 连接状态变化
    override fun onConnectionStateChanged(state: ConnectionState) {
        when (state) {
            ConnectionState.DISCONNECTED  -> println("已断开")
            ConnectionState.CONNECTING    -> println("连接中")
            ConnectionState.CONNECTED     -> println("已连接（未认证）")
            ConnectionState.AUTHENTICATED -> println("已认证")
            ConnectionState.RECONNECTING  -> println("重连中")
        }
    }

    // 认证结果
    override fun onAuthResult(success: Boolean, error: BlueError?) {
        if (success) println("认证成功")
        else println("认证失败：${error?.message}")
    }

    // 闹钟响铃
    override fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) {
        println("闹钟${alarmIndex}响铃：${alarmInfo.hour}:${alarmInfo.minute}")
    }

    // 用药结果
    override fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {
        when (status) {
            MedicationStatus.TAKEN   -> println("按时取药")
            MedicationStatus.TIMEOUT -> println("超时取药")
            MedicationStatus.MISSED  -> println("漏服")
            MedicationStatus.EARLY   -> println("提前取药")
        }
    }

    // 时间同步请求（自动响应）
    override fun onTimeSyncRequested() {
        sdk.syncTime { result ->
            println("时间同步：$result")
        }
    }
}
```

---

## 5. 完整集成流程

### 步骤1：检查权限

```kotlin
val status = sdk.checkPermissions()
if (status != PermissionStatus.GRANTED) {
    // 申请权限
    ActivityCompat.requestPermissions(this, requiredPermissions, REQUEST_CODE)
}
```

### 步骤2：扫描并连接设备

```kotlin
// 开始扫描（FR01）
sdk.startScan(
    onDeviceFound = { device ->
        println("发现设备：${device.deviceName}，信号：${device.rssi} dBm")
        // 选择目标设备后连接
        sdk.connect(device)
    },
    onError = { error ->
        println("扫描错误：${error.message}")
    }
)

// 停止扫描
sdk.stopScan()
```

### 步骤3：认证

```kotlin
val phoneMac = byteArrayOf(0xC7.toByte(), 0x50, 0xB2.toByte(), 0xAA.toByte(), 0xC3.toByte(), 0xF3.toByte())
val deviceMac = byteArrayOf(0xA6.toByte(), 0xC0.toByte(), 0x82.toByte(), 0x00, 0xA1.toByte(), 0xC2.toByte())

sdk.authenticate(phoneMac, deviceMac) { result ->
    result.fold(
        onSuccess = { println("认证成功") },
        onFailure = { println("认证失败：${(it as BlueError).message}") }
    )
}
```

### 步骤3：设置闹钟

```kotlin
// 设置闹钟1：每天 08:00
sdk.setAlarm(index = 1, hour = 8, minute = 0, weekMask = 0x7F) { result ->
    result.fold(
        onSuccess = { alarm -> println("闹钟${alarm.index}设置成功") },
        onFailure = { println("设置失败：${(it as BlueError).message}") }
    )
}
```

### 步骤4：其他操作

```kotlin
// 删除闹钟
sdk.deleteAlarm(index = 1) { result -> }

// 清空所有闹钟
sdk.clearAllAlarms { result -> }

// 设置音量
sdk.setVolume(VolumeLevel.MEDIUM) { result -> }

// 设置时间格式
sdk.setTimeFormat(TimeFormat.HOUR_24) { result -> }

// 断开连接
sdk.disconnect()
```

---

## 6. 错误处理

```kotlin
when (error) {
    is BlueError.NotInitialized   -> // 未调用 initialize()
    is BlueError.NotAuthenticated -> // 未完成认证
    is BlueError.AuthFailed       -> // 密钥不匹配
    is BlueError.Timeout          -> // 指令超时（5秒）
    is BlueError.PermissionDenied -> // 蓝牙权限未授权
    is BlueError.InvalidParameter -> // 参数无效
    is BlueError.Disconnected     -> // 设备已断开
    is BlueError.BleError         -> // 系统 BLE 错误，error.cause 包含原始异常
}
```

---

## 7. 日志配置

```kotlin
// 开发阶段
sdk.setLogLevel(LogLevel.DEBUG)

// 接管日志输出
sdk.setLogHandler { level, tag, message ->
    Log.d(tag, "[$level] $message")
}

// 生产环境关闭日志
sdk.setLogLevel(LogLevel.NONE)
```

> ⚠️ 密钥值在任何日志级别下均不输出明文。

---

## 8. Java 调用示例

```java
BlueSDK sdk = BlueSDK.getInstance(context);
sdk.initialize();

sdk.setAlarm(1, 8, 0, 0x7F, result -> {
    if (result.isSuccess()) {
        AlarmInfo alarm = result.getOrNull();
        Log.d("Demo", "闹钟" + alarm.getIndex() + "设置成功");
    }
});
```

---

## 9. 隐私合规

### 数据处理声明

本 SDK **不收集、不存储、不上传**任何用户数据：
- 用药记录通过回调传递给 APP，SDK 不做存储
- 设备 MAC 地址仅在内存中用于密钥计算，不持久化
- 不包含任何网络请求

### APP 隐私政策建议文案

```
本应用使用蓝牙功能连接 LX-PD02 智能药盒，用于设置用药提醒和接收服药通知。
Android 系统要求扫描蓝牙设备时需要位置权限，本应用仅将此权限用于蓝牙扫描，
不会获取或记录您的地理位置。
```

### Google Play 数据安全表单

- **位置数据**：选择"否，不收集位置数据"（`neverForLocation` 标志已声明）
- **蓝牙数据**：选择"是" → 用途选"应用功能" → 不与第三方共享

详见：[permission-manifest.md](./permission-manifest.md)
