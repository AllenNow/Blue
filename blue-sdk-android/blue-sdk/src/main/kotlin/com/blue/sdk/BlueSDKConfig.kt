// BlueSDKConfig.kt
// BlueSDK - SDK 配置类

package com.blue.sdk

import com.blue.sdk.enums.LogLevel

data class BlueSDKConfig(
    val fixedAuthKey: String? = null,
    val logLevel: LogLevel = LogLevel.DEBUG,
    val autoAuthEnabled: Boolean = true,
    val autoReconnect: Boolean = true,
    val maxReconnectAttempts: Int = 5
)