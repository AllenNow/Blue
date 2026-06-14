// FrameBuilder.kt
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 帧构建器：将业务数据封装为符合协议格式的二进制帧
// 帧格式：[0x55][0xAA][版本][CMD][LenHigh][LenLow][Data...][CRC8]

package com.blue.sdk.transport

/**
 * 帧构建器
 * 所有下行指令通过此类构建，保证帧格式正确
 */
internal object FrameBuilder {

    /**
     * 构建完整协议帧
     * @param cmd 命令字（见 CommandCode）
     * @param data 数据内容，可为空
     * @return 完整帧字节数组，包含帧头、版本、CMD、长度、数据和 CRC8
     */
    fun build(cmd: Byte, data: ByteArray = ByteArray(0)): ByteArray {
        val len = data.size
        val lenHigh = ((len shr 8) and 0xFF).toByte()
        val lenLow  = (len and 0xFF).toByte()

        val frame = ByteArray(FrameConstants.MIN_FRAME_LENGTH + len)
        frame[0] = FrameConstants.HEADER_BYTE1
        frame[1] = FrameConstants.HEADER_BYTE2
        frame[2] = FrameConstants.PROTOCOL_VERSION
        frame[3] = cmd
        frame[4] = lenHigh
        frame[5] = lenLow
        if (len > 0) {
            System.arraycopy(data, 0, frame, FrameConstants.DATA_OFFSET, len)
        }
        frame[frame.size - 1] = CRC8Calculator.calculate(frame.copyOf(frame.size - 1))
        return frame
    }
}
