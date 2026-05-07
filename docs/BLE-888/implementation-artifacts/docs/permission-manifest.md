# BlueSDK 权限清单

**版本**: 1.0.0  
**最后更新**: 2026-05-07

---

## iOS 权限清单

### 必需权限

#### NSBluetoothAlwaysUsageDescription

| 项目 | 说明 |
|------|------|
| **权限名称** | 蓝牙始终使用权限 |
| **系统键名** | `NSBluetoothAlwaysUsageDescription` |
| **适用版本** | iOS 13.0+ |
| **是否必须** | ✅ 必须 |
| **用途** | 扫描、连接和通信 LX-PD02 智能药盒蓝牙设备 |
| **触发时机** | 首次调用 `startScan()` 时系统自动弹出授权弹窗 |
| **拒绝影响** | 无法扫描和连接设备，SDK 返回 `BlueError.permissionDenied` |

**Info.plist 配置：**

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限以连接 LX-PD02 智能药盒设备，用于设置用药提醒和接收用药通知。</string>
```

**建议描述文案（可根据 APP 实际情况调整）：**

> "需要访问蓝牙以连接您的智能药盒，用于设置用药提醒时间和接收按时服药通知。"

---

### 可选权限（按需配置）

#### UIBackgroundModes - bluetooth-central

| 项目 | 说明 |
|------|------|
| **权限名称** | 蓝牙后台运行模式 |
| **系统键名** | `UIBackgroundModes` → `bluetooth-central` |
| **是否必须** | ⚠️ 可选（推荐配置）|
| **用途** | 允许 APP 在后台保持 BLE 连接，接收用药事件 |
| **不配置影响** | APP 进入后台后 BLE 连接可能被系统终止，导致漏报用药事件 |

**Info.plist 配置：**

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

> ⚠️ **注意**：配置后台蓝牙模式会影响 App Store 审核，需在审核说明中解释用途。

---

### iOS 权限检查代码

```swift
import BlueSDK

// 检查权限状态
let status = BlueSDK.shared.checkPermissions()
switch status {
case .granted:
    // 权限已授权，可以开始扫描
    BlueSDK.shared.startScan(onDeviceFound: { device in ... }, onError: { error in ... })
case .denied:
    // 权限被拒绝，引导用户到设置页面
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
case .notDetermined:
    // 尚未请求，调用 startScan 会自动触发系统弹窗
    BlueSDK.shared.startScan(onDeviceFound: { device in ... }, onError: { error in ... })
}
```

---

## Android 权限清单

### Android 12+（API Level 31+）

#### BLUETOOTH_SCAN

| 项目 | 说明 |
|------|------|
| **权限名称** | 蓝牙扫描权限 |
| **权限类型** | 危险权限（需运行时申请）|
| **是否必须** | ✅ 必须 |
| **用途** | 扫描附近的 LX-PD02 蓝牙设备 |
| **特殊标志** | `android:usesPermissionFlags="neverForLocation"` |

#### BLUETOOTH_CONNECT

| 项目 | 说明 |
|------|------|
| **权限名称** | 蓝牙连接权限 |
| **权限类型** | 危险权限（需运行时申请）|
| **是否必须** | ✅ 必须 |
| **用途** | 连接已配对的 LX-PD02 蓝牙设备 |

**AndroidManifest.xml 配置：**

```xml
<!-- Android 12+ 蓝牙权限 -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"
    tools:targetApi="s"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"
    tools:targetApi="s"/>
```

---

### Android 6~11（API Level 23~30）

#### BLUETOOTH

| 项目 | 说明 |
|------|------|
| **权限名称** | 蓝牙基础权限 |
| **权限类型** | 普通权限（自动授予）|
| **是否必须** | ✅ 必须 |
| **用途** | 蓝牙基础功能 |

#### BLUETOOTH_ADMIN

| 项目 | 说明 |
|------|------|
| **权限名称** | 蓝牙管理权限 |
| **权限类型** | 普通权限（自动授予）|
| **是否必须** | ✅ 必须 |
| **用途** | 启动/停止蓝牙扫描 |

#### ACCESS_FINE_LOCATION

| 项目 | 说明 |
|------|------|
| **权限名称** | 精确位置权限 |
| **权限类型** | 危险权限（需运行时申请）|
| **是否必须** | ✅ 必须（Android 系统强制要求）|
| **实际用途** | **仅用于 BLE 扫描**，SDK 不读取或使用位置数据 |
| **用户说明** | 需在权限申请弹窗中说明"此权限仅用于蓝牙扫描，不获取您的位置" |

**AndroidManifest.xml 配置：**

```xml
<!-- Android 6-11 蓝牙权限 -->
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

---

### 完整 AndroidManifest.xml 配置

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <!-- Android 6-11 -->
    <uses-permission android:name="android.permission.BLUETOOTH"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>

    <!-- Android 12+ -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation"
        tools:targetApi="s"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"
        tools:targetApi="s"/>

    <!-- 声明需要 BLE 硬件 -->
    <uses-feature
        android:name="android.hardware.bluetooth_le"
        android:required="true"/>

</manifest>
```

---

### Android 运行时权限申请代码

```kotlin
import android.Manifest
import android.os.Build
import androidx.activity.result.contract.ActivityResultContracts
import com.blue.sdk.BlueSDK
import com.blue.sdk.enums.PermissionStatus

class MainActivity : AppCompatActivity() {

    private val sdk get() = BlueSDK.getInstance(this)

    // 权限申请启动器
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val allGranted = permissions.values.all { it }
        if (allGranted) {
            startScan()
        } else {
            showPermissionDeniedDialog()
        }
    }

    private fun checkAndRequestPermissions() {
        when (sdk.checkPermissions()) {
            PermissionStatus.GRANTED -> startScan()
            PermissionStatus.DENIED -> showPermissionDeniedDialog()
            PermissionStatus.NOT_DETERMINED -> requestPermissions()
        }
    }

    private fun requestPermissions() {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        requestPermissionLauncher.launch(permissions)
    }

    private fun startScan() {
        sdk.startScan(
            onDeviceFound = { device ->
                println("发现设备：${device.deviceName}")
                sdk.connect(device)
            },
            onError = { error ->
                println("扫描错误：${error.message}")
            }
        )
    }

    private fun showPermissionDeniedDialog() {
        // 引导用户到系统设置开启权限
        AlertDialog.Builder(this)
            .setTitle("需要蓝牙权限")
            .setMessage("请在系统设置中开启蓝牙权限，以连接智能药盒设备。")
            .setPositiveButton("去设置") { _, _ ->
                startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", packageName, null)
                })
            }
            .setNegativeButton("取消", null)
            .show()
    }
}
```

---

## 权限申请最佳实践

### 1. 在合适时机申请

```
❌ 错误：APP 启动时立即申请所有权限
✅ 正确：用户点击"连接设备"时才申请蓝牙权限
```

### 2. 说明权限用途

在申请权限前，展示说明弹窗：

```
"本应用需要蓝牙权限来连接您的 LX-PD02 智能药盒，
用于设置用药提醒和接收服药通知。
我们不会使用蓝牙权限获取您的位置信息。"
```

### 3. 处理权限拒绝

- 提供降级方案（如手动输入提醒时间）
- 引导用户到系统设置重新授权
- 不要反复弹出权限申请

### 4. Android 位置权限说明

Android 6~11 申请 `ACCESS_FINE_LOCATION` 时，建议在自定义弹窗中说明：

```
"Android 系统要求扫描蓝牙设备时需要位置权限。
本应用仅将此权限用于蓝牙扫描，
不会获取或记录您的地理位置。"
```

---

## 隐私合规检查清单

集成本 SDK 前，请确认以下合规项：

### iOS

- [ ] `Info.plist` 已添加 `NSBluetoothAlwaysUsageDescription`，描述文案清晰
- [ ] APP 隐私政策中说明了蓝牙权限用途
- [ ] App Store Connect 隐私问卷中正确填写了蓝牙使用情况
- [ ] 如需后台蓝牙，已配置 `UIBackgroundModes` 并在审核说明中解释

### Android

- [ ] `AndroidManifest.xml` 已声明所有必需权限
- [ ] 实现了运行时权限申请逻辑（Android 6+）
- [ ] 权限申请前有清晰的用途说明
- [ ] APP 隐私政策中说明了蓝牙和位置权限用途
- [ ] Google Play 数据安全表单中正确填写了权限使用情况

### 通用

- [ ] APP 隐私政策中说明 SDK 不收集用户数据
- [ ] 用药记录等健康数据的存储和传输符合 PIPL/GDPR 要求
- [ ] 已告知用户健康数据的收集目的和使用方式
- [ ] 提供了用户数据删除机制
