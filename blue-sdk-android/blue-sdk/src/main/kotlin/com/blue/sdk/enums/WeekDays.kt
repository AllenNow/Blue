// WeekDays.kt
// BlueSDK - 星期枚举

package com.blue.sdk.enums

enum class WeekDays(val rawValue: Int) {
    SUNDAY(0x01),
    MONDAY(0x02),
    TUESDAY(0x04),
    WEDNESDAY(0x08),
    THURSDAY(0x10),
    FRIDAY(0x20),
    SATURDAY(0x40),
    ALL(0x7F)
}