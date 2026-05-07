package com.blue.sdk.enums

/** 设备铃声类型 */
enum class SoundType(val protocolValue: Byte) {
    MUTE(0x00),
    TYPE_A(0x01),
    TYPE_B(0x02),
    TYPE_C(0x03);

    companion object {
        fun fromByte(byte: Byte): SoundType? =
            values().find { it.protocolValue == byte }
    }
}
