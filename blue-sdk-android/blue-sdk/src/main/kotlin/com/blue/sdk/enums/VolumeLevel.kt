package com.blue.sdk.enums

/** 设备提醒音量级别 */
enum class VolumeLevel(val protocolValue: Byte) {
    LOW(0x01),
    MEDIUM(0x02),
    HIGH(0x03)
}
