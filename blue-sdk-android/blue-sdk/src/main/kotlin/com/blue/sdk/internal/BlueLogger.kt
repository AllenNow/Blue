// BlueLogger.kt
// BlueSDK - SDK 日志系统
// 支持日志级别控制、自定义日志处理器（FR34、FR35）、日志导出（Story 10.4）
// 密钥值在任何级别下均不输出明文（FR36）

package com.blue.sdk.internal

import android.util.Log
import com.blue.sdk.enums.LogLevel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** 日志处理器函数类型 */
typealias BlueLogHandler = (level: LogLevel, tag: String, message: String) -> Unit

internal object BlueLogger {

    private const val TAG = "BlueSDK"

    /** 当前日志级别 */
    @Volatile var logLevel: LogLevel = LogLevel.DEBUG

    /** 是否输出原始帧日志（TX/RX），默认 false */
    @Volatile var rawFrameLogEnabled: Boolean = false

    /** 自定义日志处理器（界面展示用） */
    @Volatile var logHandler: BlueLogHandler? = null

    // 环形日志缓冲区（Story 10.4）
    private const val BUFFER_CAPACITY = 1000
    private val logBuffer = mutableListOf<String>()
    private val bufferLock = Any()

    private val isoFormatter: SimpleDateFormat by lazy {
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
    }

    fun error(message: String) { output(LogLevel.ERROR, message) }
    fun warn(message: String) { output(LogLevel.WARN, message) }
    fun info(message: String) { output(LogLevel.INFO, message) }
    fun debug(message: String) { output(LogLevel.DEBUG, message) }

    /**
     * 导出最近的日志记录
     * @param maxLines 最大导出行数，null 表示全部（最多 1000 条）
     * @return 日志文本
     */
    fun exportLog(maxLines: Int? = null): String {
        synchronized(bufferLock) {
            val lines = if (maxLines != null) logBuffer.takeLast(maxLines) else logBuffer.toList()
            val header = buildString {
                appendLine("=== BlueSDK Log Export ===")
                appendLine("SDK Version: 0.2.0")
                appendLine("Export Time: ${isoFormatter.format(Date())}")
                appendLine("Log Level: $logLevel")
                appendLine("Entries: ${lines.size}")
                appendLine("===========================")
                appendLine()
            }
            return header + lines.joinToString("\n")
        }
    }

    /** 清空日志缓冲区 */
    fun clearLogBuffer() {
        synchronized(bufferLock) { logBuffer.clear() }
    }

    /** 当前缓冲区中的日志条数 */
    val logBufferCount: Int get() = synchronized(bufferLock) { logBuffer.size }

    private fun output(level: LogLevel, message: String) {
        if (level.priority > logLevel.priority) return

        val sanitized = LogFormatter.sanitize(message)
        val formatted = LogFormatter.format(level, TAG, message)

        // 写入环形缓冲区
        val timestamp = isoFormatter.format(Date())
        val entry = "[$timestamp] $formatted"
        synchronized(bufferLock) {
            logBuffer.add(entry)
            if (logBuffer.size > BUFFER_CAPACITY) {
                logBuffer.removeAt(0)
            }
        }

        // 输出到 Logcat（使用 Log.w 级别，华为等手机不会屏蔽 WARN）
        Log.w(TAG, formatted)

        // 同时通知自定义 handler（界面日志用）
        logHandler?.invoke(level, TAG, sanitized)
    }
}
