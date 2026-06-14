// CRC8Calculator.kt
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// CRC8 校验计算器
// 算法：从帧头第一字节开始，所有字节累加和对 256 求余
// 公式：crc = (sum of bytes[0..6+Len-1]) % 256

package com.blue.sdk.transport

/**
 * CRC8 校验计算器
 * 唯一实现，不允许变体（ARCH-03）
 */
internal object CRC8Calculator {

    /**
     * 计算字节数组的 CRC8 校验值
     * @param bytes 参与校验的字节数组（从帧头第一字节到数据最后一字节）
     * @return CRC8 校验值（累加和对 256 求余）
     */
    fun calculate(bytes: ByteArray): Byte {
        val sum = bytes.fold(0) { acc, byte -> acc + (byte.toInt() and 0xFF) }
        return (sum % 256).toByte()
    }

    /**
     * 验证帧数据的 CRC8 校验值是否正确
     * @param frame 完整帧数据（包含末尾的 CRC8 字节）
     * @return 校验是否通过
     */
    fun verify(frame: ByteArray): Boolean {
        if (frame.size < FrameConstants.MIN_FRAME_LENGTH) return false
        val payload = frame.copyOf(frame.size - 1)
        val expected = frame.last()
        return calculate(payload) == expected
    }
}
