// FrameParser.kt
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 帧解析器：从 BLE notify 数据流中识别并解析完整的协议帧
// CRC8 校验失败时静默丢弃，不抛出异常（NFR12）

package com.blue.sdk.transport

/**
 * 解析后的协议帧
 */
internal data class ParsedFrame(
    val version: Byte,
    val cmd: Byte,
    val data: ByteArray
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is ParsedFrame) return false
        return version == other.version && cmd == other.cmd && data.contentEquals(other.data)
    }
    override fun hashCode(): Int = 31 * (31 * version.hashCode() + cmd.hashCode()) + data.contentHashCode()
}

/**
 * 帧解析器
 * 从 BLE notify 原始字节流中解析完整协议帧
 */
internal object FrameParser {

    /**
     * 解析单个完整帧
     * @param bytes 原始字节数组（应为一个完整帧）
     * @return 解析成功返回 ParsedFrame，帧头错误或 CRC8 校验失败返回 null（静默丢弃）
     */
    fun parse(bytes: ByteArray): ParsedFrame? {
        if (bytes.size < FrameConstants.MIN_FRAME_LENGTH) return null

        // 帧头校验
        if (bytes[0] != FrameConstants.HEADER_BYTE1 || bytes[1] != FrameConstants.HEADER_BYTE2) return null

        // 解析长度字段
        val lenHigh = bytes[FrameConstants.LEN_HIGH_OFFSET].toInt() and 0xFF
        val lenLow  = bytes[FrameConstants.LEN_LOW_OFFSET].toInt() and 0xFF
        val dataLen = (lenHigh shl 8) or lenLow

        // 帧完整性检查
        val expectedLength = FrameConstants.MIN_FRAME_LENGTH + dataLen
        if (bytes.size != expectedLength) return null

        // CRC8 校验（失败时静默丢弃，NFR12）
        if (!CRC8Calculator.verify(bytes)) return null

        val version = bytes[FrameConstants.VERSION_OFFSET]
        val cmd     = bytes[FrameConstants.CMD_OFFSET]
        val data    = if (dataLen > 0)
            bytes.copyOfRange(FrameConstants.DATA_OFFSET, FrameConstants.DATA_OFFSET + dataLen)
        else ByteArray(0)

        return ParsedFrame(version = version, cmd = cmd, data = data)
    }
}
