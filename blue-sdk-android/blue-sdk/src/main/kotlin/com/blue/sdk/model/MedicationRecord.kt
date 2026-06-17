package com.blue.sdk.model

import com.blue.sdk.enums.MedicationStatus

/**
 * 用药记录数据模型
 * @param timestamp 实际事件时间戳（Unix 时间戳，毫秒）— 取药/漏服发生的时刻
 * @param alarmIndex 对应的闹钟槽位索引（1~7）
 * @param alarmHour 闹钟设定小时（0~23）— 应该吃药的时间
 * @param alarmMinute 闹钟设定分钟（0~59）
 * @param status 用药状态（取药/超时/漏服/提前）
 */
data class MedicationRecord(
    val timestamp: Long,
    val alarmIndex: Int,
    val alarmHour: Int,
    val alarmMinute: Int,
    val status: MedicationStatus
) {
    /** 闹钟设定时间格式化（如 "08:00"）*/
    val alarmTimeString: String get() = "%02d:%02d".format(alarmHour, alarmMinute)
}
