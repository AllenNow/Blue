# BlueSDK - Android

LX-PD02 智能药盒蓝牙通信 SDK（Android 原生）

## 简介

BlueSDK 是专为 LX-PD02 智能药盒硬件设计的 Android 原生蓝牙通信与控制 SDK。完整封装 LX-PD02 私有蓝牙 5.0 通信协议，向上提供简洁、类型安全的高层 API。

## 系统要求

- Android 5.0+（API Level 21+）
- Kotlin 1.9+
- 设备蓝牙硬件须支持 Bluetooth 5.0 及以上

## 集成方式

### Gradle（本地 AAR）

```kotlin
dependencies {
    implementation(files("libs/blue-sdk-x.x.x.aar"))
}
```

## 快速开始

```kotlin
// 初始化
BlueSDK.getInstance(context).initialize()

// 设置日志级别（开发阶段）
BlueSDK.getInstance(context).setLogLevel(LogLevel.DEBUG)

// 注册事件监听
BlueSDK.getInstance(context).setListener(object : BlueSDKListener {
    override fun onConnectionStateChanged(state: ConnectionState) { }
    override fun onAuthResult(success: Boolean, error: BlueError?) { }
    // ...
})
```

## 权限配置

在 `AndroidManifest.xml` 中添加：

```xml
<!-- Android 6-11 -->
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<!-- Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
```

## 文档

- [变更日志](./CHANGELOG.md)

## 许可证

MIT License
