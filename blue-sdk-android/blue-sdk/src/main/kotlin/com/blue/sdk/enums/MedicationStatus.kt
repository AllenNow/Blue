// MedicationStatus.kt
// BlueSDK - 用药结果状态枚举
// BlueSDK - Medication result status enum

package com.blue.sdk.enums

/**
 * 用药结果状态枚举，对应协议中的状态值
 * Medication result status enum, maps to protocol status values
 */
enum class MedicationStatus(val protocolValue: Int) {
    /** 按时取药（0x01）/ Taken on time (0x01) */
    TAKEN(0x01),
    /** 超时取药（0x02）/ Taken late (0x02) */
    TIMEOUT(0x02),
    /** 漏服（0x03）/ Missed (0x03) */
    MISSED(0x03),
    /** 提前取药（0x04）/ Taken early (0x04) */
    EARLY(0x04);

    companion object {
        /**
         * 从协议字节值转换
         * Convert from protocol byte value
         */
        fun fromByte(byte: Byte): MedicationStatus? =
            values().find { it.protocolValue == (byte.toInt() and 0xFF) }
    }

    /** 用户可读的状态描述（中文）/ User-readable description (Chinese) */
    val displayNameZh: String get() = when (this) {
        TAKEN -> "按时取药"
        TIMEOUT -> "超时取药"
        MISSED -> "漏服"
        EARLY -> "提前取药"
    }

    /** 用户可读的状态描述（英文）/ User-readable description (English) */
    val displayNameEn: String get() = when (this) {
        TAKEN -> "Taken on time"
        TIMEOUT -> "Taken late"
        MISSED -> "Missed"
        EARLY -> "Taken early"
    }

    /** 用户可读的状态描述（德语）/ User-readable description (German) */
    val displayNameDe: String get() = when (this) {
        TAKEN -> "Pünktlich eingenommen"
        TIMEOUT -> "Verspätet eingenommen"
        MISSED -> "Vergessen"
        EARLY -> "Vorzeitig eingenommen"
    }
}
