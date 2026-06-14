package com.blue.sdk.model

import com.blue.sdk.enums.MedicationStatus

/**
 * 用药记录数据模型
 * @param timestamp 用药时间戳（Unix 时间戳，毫秒）
 * @param alarmIndex 对应的闹钟槽位索引（1~7）
 * @param status 用药状态
 */
data class MedicationRecord(
    val timestamp: Long,
    val alarmIndex: Int,
    val status: MedicationStatus
)
