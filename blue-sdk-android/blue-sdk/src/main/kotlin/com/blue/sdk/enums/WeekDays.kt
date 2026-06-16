// WeekDays.kt
// BlueSDK - 星期枚举

package com.blue.sdk.enums

enum class WeekDays(val rawValue: Int) {
    MONDAY(0x01),
    TUESDAY(0x02),
    WEDNESDAY(0x04),
    THURSDAY(0x08),
    FRIDAY(0x10),
    SATURDAY(0x20),
    SUNDAY(0x40),
    ALL(0x7F)
}