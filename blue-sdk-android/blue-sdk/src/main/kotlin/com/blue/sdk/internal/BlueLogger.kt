// BlueLogger.kt
// BlueSDK - SDK 日志系统（FR34、FR35、FR36）

package com.blue.sdk.internal

import android.util.Log
import com.blue.sdk.enums.LogLevel

/** 日志处理器函数类型 */
typealias BlueLogHandler = (level: LogLevel, tag: String, message: String) -> Unit

internal object BlueLogger {

    /** 当前日志级别，默认 NONE（关闭）*/
    @Volatile var logLevel: LogLevel = LogLevel.NONE
    /** 自定义日志处理器，null 时使用 Android Logcat */
    @Volatile var logHandler: BlueLogHandler? = null

    fun error(message: String, tag: String = "BlueSDK") = log(LogLevel.ERROR, tag, message)
    fun warn(message: String, tag: String = "BlueSDK")  = log(LogLevel.WARN, tag, message)
    fun info(message: String, tag: String = "BlueSDK")  = log(LogLevel.INFO, tag, message)
    fun debug(message: String, tag: String = "BlueSDK") = log(LogLevel.DEBUG, tag, message)

    private fun log(level: LogLevel, tag: String, message: String) {
        if (level.priority > logLevel.priority) return
        val sanitized = LogFormatter.sanitize(message)
        val handler = logHandler
        if (handler != null) {
            handler(level, tag, sanitized)
        } else {
            val formatted = LogFormatter.format(level, tag, message)
            when (level) {
                LogLevel.ERROR -> Log.e(tag, formatted)
                LogLevel.WARN  -> Log.w(tag, formatted)
                LogLevel.INFO  -> Log.i(tag, formatted)
                LogLevel.DEBUG -> Log.d(tag, formatted)
                LogLevel.NONE  -> Unit
            }
        }
    }
}
