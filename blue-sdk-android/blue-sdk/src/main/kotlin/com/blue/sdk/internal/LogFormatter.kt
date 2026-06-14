// LogFormatter.kt
// BlueSDK - 日志脱敏处理器
// 密钥值和 MAC 地址在任何日志级别下均不输出明文（FR36、NFR07）

package com.blue.sdk.internal

import com.blue.sdk.enums.LogLevel

internal object LogFormatter {

    private val sensitivePatterns = listOf(
        Regex("(?i)(auth[_\\s]?key[:\\s]+)[0-9a-fA-F\\s]+"),
        Regex("(?i)(key[:\\s]+)[0-9a-fA-F\\s]{2,}"),
        Regex("(?i)(mac[:\\s]+)([0-9a-fA-F]{2}[:\\-\\s]){5}[0-9a-fA-F]{2}")
    )

    /** 对日志消息进行脱敏处理 */
    fun sanitize(message: String): String {
        var result = message
        sensitivePatterns.forEach { pattern ->
            result = pattern.replace(result) { match ->
                "${match.groupValues[1]}***"
            }
        }
        return result
    }

    /** 格式化日志输出字符串 */
    fun format(level: LogLevel, tag: String, message: String): String {
        val sanitized = sanitize(message)
        return "[BlueSDK][${level.name}][$tag] $sanitized"
    }
}
