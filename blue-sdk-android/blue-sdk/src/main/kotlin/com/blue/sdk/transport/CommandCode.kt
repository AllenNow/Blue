// CommandCode.kt
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// CMD 命令字常量定义

package com.blue.sdk.transport

/**
 * CMD 命令字常量
 * 用于标识帧类型，区分下行指令和上行上报
 */
internal object CommandCode {
    /** 密钥认证（下行）55 AA 00 00 00 02 [keyHigh] [keyLow] [crc8] */
    const val AUTH_KEY: Byte = 0x00
    /** 查询设备信息（下行）55 AA 00 01 00 00 00 */
    const val QUERY_DEVICE_INFO: Byte = 0x01
    /** APP 下发指令（下行）用于设置闹钟、音量、铃声等所有配置类指令 */
    const val SEND_COMMAND: Byte = 0x06
    /** 设备上报（上行）设备主动上报闹钟变更、用药事件等 */
    const val DEVICE_REPORT: Byte = 0x07
    /** 时间同步（双向）设备请求：55 AA 00 E1 00 01 00 E1 */
    const val TIME_SYNC: Byte = 0xE1.toByte()
}
