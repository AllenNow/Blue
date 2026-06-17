// BlueSDKConfig.kt
// BlueSDK - SDK 配置类

package com.blue.sdk

import com.blue.sdk.enums.LogLevel

/**
 * SDK 语言设置
 * - SYSTEM: 跟随系统语言（默认）
 * - ZH: 强制中文
 * - EN: 强制英文
 */
enum class BlueSDKLanguage {
    SYSTEM, ZH, EN
}

data class BlueSDKConfig(
    val fixedAuthKey: String? = null,
    val logLevel: LogLevel = LogLevel.DEBUG,
    val autoAuthEnabled: Boolean = true,
    val autoReconnect: Boolean = true,
    val maxReconnectAttempts: Int = 5,
    val language: BlueSDKLanguage = BlueSDKLanguage.SYSTEM
)
