package com.blue.sdk.model

/**
 * 闹钟信息数据模型
 * @param index 闹钟槽位索引（1~7）
 * @param hour 小时（0~23）
 * @param minute 分钟（0~59）
 * @param weekMask 星期周期掩码（bit0=周日...bit6=周六，默认 0x7F 每天）
 * @param advanceStatus 提前取药状态（bit0=当天已取药, bit4=次日已取药）
 */
data class AlarmInfo(
    val index: Int,
    val hour: Int,
    val minute: Int,
    val weekMask: Int,
    val advanceStatus: Int
) {
    /** 是否为删除状态（所有字段为 0xFF）*/
    val isDeleted: Boolean get() = hour == 0xFF && minute == 0xFF && weekMask == 0xFF
}
