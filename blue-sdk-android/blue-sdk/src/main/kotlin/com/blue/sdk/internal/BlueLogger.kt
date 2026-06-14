// BlueLogger.kt
// BlueSDK - SDK 日志系统
// 所有日志始终输出到 Android Logcat（使用 Log.w 确保华为等手机不屏蔽）

package com.blue.sdk.internal

import android.util.Log
import com.blue.sdk.enums.LogLevel

/** 日志处理器函数类型 */
typealias BlueLogHandler = (level: LogLevel, tag: String, message: String) -> Unit

internal object BlueLogger {

    private const val TAG = "BlueSDK"

    /** 当前日志级别 */
    @Volatile var logLevel: LogLevel = LogLevel.DEBUG

    /** 自定义日志处理器（界面展示用） */
    @Volatile var logHandler: BlueLogHandler? = null

    fun error(message: String) {
        output(LogLevel.ERROR, message)
    }

    fun warn(message: String) {
        output(LogLevel.WARN, message)
    }

    fun info(message: String) {
        output(LogLevel.INFO, message)
    }

    fun debug(message: String) {
        output(LogLevel.DEBUG, message)
    }

    private fun output(level: LogLevel, message: String) {
        // 始终输出到 Logcat（使用 Log.w 级别，华为不会屏蔽 WARN）
        val prefix = when (level) {
            LogLevel.ERROR -> "[ERROR]"
            LogLevel.WARN -> "[WARN]"
            LogLevel.INFO -> "[INFO]"
            LogLevel.DEBUG -> "[DEBUG]"
            LogLevel.NONE -> ""
        }
        Log.w(TAG, "$prefix $message")

        // 同时通知自定义 handler（界面日志用）
        logHandler?.invoke(level, TAG, message)
    }
}
