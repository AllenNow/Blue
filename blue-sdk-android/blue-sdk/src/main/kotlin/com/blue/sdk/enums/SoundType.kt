package com.blue.sdk.enums

/** 设备铃声类型（含静音） */
enum class SoundType(val protocolValue: Byte) {
    /** 静音（协议值 0x00）*/
    MUTE(0x00),
    /** 声音类型 A（协议值 0x01）*/
    TYPE_A(0x01),
    /** 声音类型 B（协议值 0x02）*/
    TYPE_B(0x02),
    /** 声音类型 C（协议值 0x03）*/
    TYPE_C(0x03);

    companion object {
        fun fromByte(value: Byte): SoundType? =
            values().firstOrNull { it.protocolValue == value }
    }
}
