// AlarmConfig.kt
// BlueSDK - 闹钟配置数据类（批量设置用）
// BlueSDK - Alarm configuration data class (for batch operations)

package com.blue.sdk.model

/**
 * 闹钟配置（用于批量设置）
 * Alarm configuration (for batch operations)
 *
 * 使用示例 / Usage:
 * ```kotlin
 * val alarms = listOf(
 *     AlarmConfig(1, 8, 0),
 *     AlarmConfig(2, 12, 30, days = WeekDay.WEEKDAYS),
 *     AlarmConfig(3, 20, 0, days = WeekDay.WEEKEND)
 * )
 * sdk.setAlarms(alarms) { result -> ... }
 * ```
 *
 * @param index 闹钟槽位（1~7）/ Alarm slot (1~7)
 * @param hour 小时（0~23）/ Hour (0~23)
 * @param minute 分钟（0~59）/ Minute (0~59)
 * @param weekMask 星期周期掩码（bit0=周一...bit6=周日，默认 0x7F 每天）/ Week bitmask (default 0x7F = every day)
 * @param days 类型安全的星期集合（优先使用）/ Type-safe day set (takes priority)
 */
data class AlarmConfig(
    val index: Int,
    val hour: Int,
    val minute: Int,
    val weekMask: Int = 0x7F,
    val days: Set<com.blue.sdk.enums.WeekDay>? = null
) {
    /**
     * 获取实际的 weekMask 值
     * Get resolved weekMask value
     */
    internal fun resolvedWeekMask(): Int =
        days?.let { com.blue.sdk.enums.WeekDay.toMask(it) } ?: weekMask
}
