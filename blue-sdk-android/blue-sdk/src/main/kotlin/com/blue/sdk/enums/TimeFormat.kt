package com.blue.sdk.enums

/** 设备时间显示格式 */
enum class TimeFormat(val protocolValue: Byte) {
    /** 12 小时制（协议值 0x00）*/
    HOUR_12(0x00),
    /** 24 小时制（协议值 0x01）*/
    HOUR_24(0x01)
}
