// AlarmConfig.kt
// BlueSDK - 闹钟配置

package com.blue.sdk.model

import com.blue.sdk.enums.WeekDays

data class AlarmConfig(
    val index: Int,
    val hour: Int,
    val minute: Int,
    val weekMask: Int = 0x7F
) {
    constructor(index: Int, hour: Int, minute: Int, days: WeekDays) :
        this(index, hour, minute, days.rawValue)
}