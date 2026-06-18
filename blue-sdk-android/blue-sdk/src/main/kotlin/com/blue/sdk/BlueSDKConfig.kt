// BlueSDKConfig.kt
// BlueSDK - SDK 初始化配置
// BlueSDK - SDK initialization configuration

package com.blue.sdk

import com.blue.sdk.enums.LogLevel

/**
 * SDK 语言设置
 * SDK language setting
 *
 * - SYSTEM: 跟随系统语言（默认） / Follow system language (default)
 * - ZH: 强制中文 / Force Chinese
 * - EN: 强制英文 / Force English
 * - DE: 强制德语 / Force German
 */
enum class BlueSDKLanguage {
    SYSTEM, ZH, EN, DE
}

/**
 * SDK 初始化配置
 * SDK initialization configuration
 *
 * 通过 BlueSDK.getInstance(context).initialize(config) 传入
 * Pass via BlueSDK.getInstance(context).initialize(config)
 */
data class BlueSDKConfig(
    /**
     * 固定认证密钥
     * Fixed authentication key
     *
     * - 格式/Format: 4 位十六进制字符串（2 字节）/ 4-char hex string (2 bytes), e.g. "05FA"
     * - 有效字符/Valid chars: 0-9, A-F, a-f
     * - 长度/Length: 必须恰好 4 个字符，否则忽略 / Must be exactly 4 chars, ignored otherwise
     * - 示例/Example: "05FA" → keyHigh=0x05, keyLow=0xFA
     * - 设置后优先使用此密钥，为 null 则自动计算
     * - When set, this key takes priority; null = auto-calculate
     */
    val fixedAuthKey: String? = null,

    /**
     * 日志级别，默认 DEBUG
     * Log level, defaults to DEBUG
     */
    val logLevel: LogLevel = LogLevel.DEBUG,

    /**
     * 是否在连接成功后自动执行认证，默认 true
     * Whether to auto-authenticate after connection, defaults to true
     */
    val autoAuthEnabled: Boolean = true,

    /**
     * 断线后是否自动重连，默认 true
     * Whether to auto-reconnect after disconnection, defaults to true
     */
    val autoReconnect: Boolean = true,

    /**
     * 最大自动重连次数，默认 5
     * Maximum auto-reconnect attempts, defaults to 5
     */
    val maxReconnectAttempts: Int = 5,

    /**
     * SDK 语言设置
     * SDK language setting
     */
    val language: BlueSDKLanguage = BlueSDKLanguage.SYSTEM,

    /**
     * 自定义 phoneMac（用于自动计算密钥时的手机标识）
     * Custom phoneMac (phone identifier for auto key calculation)
     *
     * - 格式/Format: 12 位十六进制字符串（6 字节）/ 12-char hex string (6 bytes), e.g. "A1B2C3D4E5F6"
     * - 有效字符/Valid chars: 0-9, A-F, a-f
     * - 长度/Length: 必须恰好 12 个字符，否则忽略 / Must be exactly 12 chars, ignored otherwise
     * - 设置后 SDK 使用此值，不再基于 ANDROID_ID 生成
     * - When set, SDK uses this value instead of generating from ANDROID_ID
     */
    val customPhoneMac: String? = null
)
