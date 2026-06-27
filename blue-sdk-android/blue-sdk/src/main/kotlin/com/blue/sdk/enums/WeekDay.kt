// WeekDay.kt
// BlueSDK - 星期枚举（闹钟周期配置）
// BlueSDK - Weekday enum (alarm repeat schedule)

package com.blue.sdk.enums

/**
 * 星期枚举
 * Weekday enum
 *
 * 用于闹钟的周期配置，替代原始 weekMask 整型位掩码
 * Used for alarm repeat configuration, replaces raw weekMask int bitmask
 *
 * 使用示例 / Usage:
 * ```kotlin
 * val workdays = setOf(WeekDay.MONDAY, WeekDay.TUESDAY, WeekDay.WEDNESDAY, WeekDay.THURSDAY, WeekDay.FRIDAY)
 * sdk.setAlarm(1, 8, 0, days = workdays) { ... }
 * ```
 */
enum class WeekDay(val mask: Int) {
    SUNDAY(0x01),
    MONDAY(0x02),
    TUESDAY(0x04),
    WEDNESDAY(0x08),
    THURSDAY(0x10),
    FRIDAY(0x20),
    SATURDAY(0x40);

    companion object {
        /** 所有天（每天）/ All days (every day) */
        val ALL: Set<WeekDay> = values().toSet()

        /** 工作日（周一至周五）/ Weekdays (Mon-Fri) */
        val WEEKDAYS: Set<WeekDay> = setOf(MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY)

        /** 周末 / Weekend */
        val WEEKEND: Set<WeekDay> = setOf(SATURDAY, SUNDAY)

        /**
         * 将 Set<WeekDay> 转换为协议位掩码
         * Convert Set<WeekDay> to protocol bitmask
         */
        fun toMask(days: Set<WeekDay>): Int = days.fold(0) { acc, day -> acc or day.mask }

        /**
         * 从协议位掩码解析为 Set<WeekDay>
         * Parse protocol bitmask to Set<WeekDay>
         */
        fun fromMask(mask: Int): Set<WeekDay> = values().filter { mask and it.mask != 0 }.toSet()
    }
}
