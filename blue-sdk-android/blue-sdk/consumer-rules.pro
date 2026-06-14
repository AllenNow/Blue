# BlueSDK ProGuard 规则（供集成方使用）
# 保留所有公开 API 类和方法
-keep public class com.blue.sdk.BlueSDK { *; }
-keep public interface com.blue.sdk.BlueSDKListener { *; }
-keep public class com.blue.sdk.model.** { *; }
-keep public enum com.blue.sdk.enums.** { *; }
-keep public class com.blue.sdk.error.BlueError { *; }
