package com.blue.sdk.enums

/** SDK 日志级别 */
enum class LogLevel(val priority: Int) {
    /** 关闭所有日志（默认）*/
    NONE(0),
    /** 仅错误日志 */
    ERROR(1),
    /** 警告及以上 */
    WARN(2),
    /** 信息及以上 */
    INFO(3),
    /** 调试及以上（输出原始帧数据）*/
    DEBUG(4)
}
