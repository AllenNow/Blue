# BlueSDK - Android

LX-PD02 智能药盒蓝牙通信 SDK（Android 原生）

[![Platform](https://img.shields.io/badge/platform-Android%205.0%2B-green)](https://developer.android.com)
[![Kotlin](https://img.shields.io/badge/Kotlin-1.9%2B-purple)](https://kotlinlang.org)
[![Bluetooth](https://img.shields.io/badge/Bluetooth-5.0%2B-blue)](https://www.bluetooth.com)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## 简介

BlueSDK 完整封装 LX-PD02 私有蓝牙 5.0 通信协议，向上提供简洁、类型安全的高层 API。第三方开发者无需了解底层帧结构、CRC 校验、密钥认证等协议细节，即可快速构建具备完整用药提醒闭环能力的移动应用。

**核心能力：**
- 🔵 BLE 设备扫描与连接（自动重连、指数退避）
- 🔐 密钥认证（手机 MAC + 设备 MAC 累加算法）
- ⏰ 闹钟管理（7 个槽位）
- 💊 用药事件接收（响铃/超时/取药/漏服）
- 📋 用药记录上报（含毫秒时间戳）
- 🔊 音频与系统设置
- 📝 分级日志（密钥脱敏）

---

## 系统要求

- Android 5.0+（API Level 21+）
- Kotlin 1.9+
- 设备蓝牙须支持 Bluetooth 5.0+

---

## 集成

### 本地 AAR（推荐）

将 `blue-sdk-x.x.x.aar` 放入 `app/libs/`：

```kotlin
// app/build.gradle.kts
dependencies {
    implementation(files("libs/blue-sdk-x.x.x.aar"))
}
```

### 本地模块依赖（开发阶段）

```kotlin
// settings.gradle.kts
include(":blue-sdk")
project(":blue-sdk").projectDir = File("../blue-sdk-android/blue-sdk")

// app/build.gradle.kts
dependencies {
    implementation(project(":blue-sdk"))
}
```

---

## 权限配置

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

> **说明**：Android 6~11 的 `ACCESS_FINE_LOCATION` 是系统对 BLE 扫描的强制要求，SDK 不读取或使用位置数据。

---

## 快速开始

### 1. 初始化

```kotlin
// Application.kt
import com.blue.sdk.BlueSDK
import com.blue.sdk.enums.LogLevel

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        BlueSDK.getInstance(this).initialize()
        BlueSDK.getInstance(this).setLogLevel(LogLevel.DEBUG) // 开发阶段
    }
    override fun onTerminate() {
        super.onTerminate()
        BlueSDK.getInstance(this).destroy()
    }
}
```

### 2. 注册事件监听

```kotlin
class MainActivity : AppCompatActivity(), BlueSDKListener {

    private val sdk get() = BlueSDK.getInstance(this)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sdk.listener = this
    }

    override fun onConnectionStateChanged(state: ConnectionState) {
        println("连接状态：$state")
    }

    override fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) {
        println("闹钟${alarmIndex}响铃：${alarmInfo.hour}:${alarmInfo.minute}")
    }

    override fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {
        println("用药结果：$status")
    }

    override fun onTimeSyncRequested() {
        sdk.syncTime { _ -> }
    }
}
```

### 3. 申请权限并扫描

```kotlin
// 申请运行时权限（Android 6+）
private fun requestPermissionsAndScan() {
    val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
    } else {
        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
    }
    ActivityCompat.requestPermissions(this, permissions, REQUEST_CODE)
}

// 扫描设备
private fun startScan() {
    sdk.startScan(
        onDeviceFound = { device ->
            println("发现：${device.deviceName}，信号：${device.rssi} dBm")
            sdk.connect(device)
            sdk.stopScan()
        },
        onError = { error ->
            println("扫描错误：${error.message}")
        }
    )
}
```

### 4. 认证

```kotlin
sdk.authenticate(phoneMac, deviceMac) { result ->
    result.fold(
        onSuccess = { println("认证成功") },
        onFailure = { println("认证失败：${(it as BlueError).message}") }
    )
}
```

### 5. 设置闹钟

```kotlin
// 设置闹钟1：每天 08:00
sdk.setAlarm(index = 1, hour = 8, minute = 0, weekMask = 0x7F) { result ->
    result.fold(
        onSuccess = { alarm -> println("闹钟${alarm.index}设置成功") },
        onFailure = { println("设置失败：${(it as BlueError).message}") }
    )
}
```

---

## 错误处理

```kotlin
when (error) {
    is BlueError.NotInitialized   -> // 未调用 initialize()
    is BlueError.NotAuthenticated -> // 未完成认证
    is BlueError.AuthFailed       -> // 密钥不匹配
    is BlueError.Timeout          -> // 指令超时（5秒，自动重试3次）
    is BlueError.PermissionDenied -> // 蓝牙权限未授权
    is BlueError.InvalidParameter -> // 参数无效
    is BlueError.Disconnected     -> // 设备已断开
    is BlueError.BleError         -> // 系统 BLE 错误，error.cause 含原始异常
}
```

---

## 日志配置

```kotlin
// 开发阶段
sdk.setLogLevel(LogLevel.DEBUG)

// 接管日志
sdk.setLogHandler { level, tag, message ->
    Log.d(tag, "[$level] $message")
}

// 生产环境关闭
sdk.setLogLevel(LogLevel.NONE)
```

> ⚠️ 密钥值在任何日志级别下均不输出明文。

---

## Java 调用

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

## 隐私说明

本 SDK **不收集、不存储、不上传**任何用户数据：
- 用药记录通过回调传递给 APP，SDK 不做存储
- 设备 MAC 地址仅在内存中用于密钥计算，不持久化
- 不包含任何网络请求

详见 [隐私政策](../docs/BLE-888/implementation-artifacts/docs/privacy-policy.md)

---

## 文档

| 文档 | 说明 |
|------|------|
| [API 参考](../docs/BLE-888/implementation-artifacts/docs/api-reference.md) | 完整 API 列表 |
| [协议参考](../docs/BLE-888/implementation-artifacts/docs/protocol-reference.md) | 帧格式、DPID、CRC8 |
| [权限清单](../docs/BLE-888/implementation-artifacts/docs/permission-manifest.md) | 权限配置与合规 |
| [故障排查](../docs/BLE-888/implementation-artifacts/docs/troubleshooting.md) | 常见问题解决 |
| [兼容性矩阵](compatibility-matrix.md) | 设备与系统兼容性 |
| [变更日志](CHANGELOG.md) | 版本历史 |

---

## 已知问题

- BLE GATT UUID 使用通用串口服务占位，待硬件方确认后更新
- 时间同步帧格式待硬件方确认
- 编译验证待 Android Studio 执行

---

## 许可证

MIT License
