# ============================================================
# BlueSDK ProGuard / R8 规则
# 此文件会自动合并到集成方的混淆规则中（通过 consumerProguardFiles）
# 无需集成方手动配置
# ============================================================

# 保留 SDK 公开 API
-keep public class com.blue.sdk.BlueSDK { *; }
-keep public class com.blue.sdk.BlueSDKConfig { *; }
-keep public enum com.blue.sdk.BlueSDKLanguage { *; }
-keep public interface com.blue.sdk.BlueSDKListener { *; }

# 保留数据模型（集成方会直接使用）
-keep public class com.blue.sdk.model.** { *; }

# 保留枚举（防止枚举值被混淆）
-keep public enum com.blue.sdk.enums.** { *; }

# 保留错误类型（sealed class 子类）
-keep public class com.blue.sdk.error.BlueError { *; }
-keep public class com.blue.sdk.error.BlueError$* { *; }

# 保留回调函数类型
-keep public class com.blue.sdk.internal.BlueLogHandler { *; }

# BLE 相关（防止 GATT 回调被混淆）
-keep class * extends android.bluetooth.BluetoothGattCallback { *; }
