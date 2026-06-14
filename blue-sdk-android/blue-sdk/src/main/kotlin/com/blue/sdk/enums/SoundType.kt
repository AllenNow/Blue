package com.blue.sdk.enums

enum class SoundType(val protocolValue: Byte) {
    TYPE_A(0x01),
    TYPE_B(0x02),
    TYPE_C(0x03);
    
    companion object {
        fun fromByte(value: Byte): SoundType? =
            values().firstOrNull { it.protocolValue == value }
    }
}
