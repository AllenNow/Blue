// FrameConstants.kt
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 协议帧格式常量定义
// 帧结构：[0x55][0xAA][版本][CMD][LenHigh][LenLow][Data...][CRC8]

package com.blue.sdk.transport

/**
 * 协议帧格式常量
 * 所有帧结构相关的固定值，禁止在其他文件中使用魔法数字（ARCH-02）
 */
internal object FrameConstants {
    /** 帧头第一字节 */
    const val HEADER_BYTE1: Byte = 0x55.toByte()
    /** 帧头第二字节 */
    const val HEADER_BYTE2: Byte = 0xAA.toByte()
    /** 协议版本号 */
    const val PROTOCOL_VERSION: Byte = 0x00
    /** 最小帧长度：帧头2 + 版本1 + CMD1 + Len2 + CRC1 = 7字节 */
    const val MIN_FRAME_LENGTH: Int = 7
    /** 帧头偏移量 */
    const val HEADER_OFFSET: Int = 0
    /** 版本字段偏移量 */
    const val VERSION_OFFSET: Int = 2
    /** CMD 字段偏移量 */
    const val CMD_OFFSET: Int = 3
    /** 数据长度高字节偏移量 */
    const val LEN_HIGH_OFFSET: Int = 4
    /** 数据长度低字节偏移量 */
    const val LEN_LOW_OFFSET: Int = 5
    /** 数据起始偏移量 */
    const val DATA_OFFSET: Int = 6
}
