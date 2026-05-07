package com.blue.sdk.enums

/** 用药结果状态枚举，对应协议中 byte9 的状态值 */
enum class MedicationStatus(val protocolValue: Int) {
    /** 按时取药（0x01）*/
    TAKEN(0x01),
    /** 超时取药（0x02）*/
    TIMEOUT(0x02),
    /** 漏服（0x03）*/
    MISSED(0x03),
    /** 提前取药（0x04）*/
    EARLY(0x04);

    companion object {
        fun fromByte(byte: Byte): MedicationStatus? =
            values().find { it.protocolValue == (byte.toInt() and 0xFF) }
    }
}
