// StreamFrameParser.kt
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 流式帧解析器：处理 BLE notify 粘包/分包
// BLE notify 回调可能：
//   1. 一次包含一个完整帧（正常情况）
//   2. 一次包含多个完整帧（粘包）
//   3. 一个帧分多次到达（分包）
// 本解析器通过缓冲区累积数据，识别完整帧后回调

package com.blue.sdk.transport

import com.blue.sdk.internal.BlueLogger

/**
 * 流式帧解析器
 * 线程安全，通过内部缓冲区处理 BLE 数据流的粘包/分包
 */
internal class StreamFrameParser {

    companion object {
        /** 缓冲区最大容量（防止异常数据无限累积）*/
        private const val MAX_BUFFER_SIZE = 1024
    }

    private val buffer = mutableListOf<Byte>()
    private val lock = Any()
    private var onFrameParsed: ((ParsedFrame) -> Unit)? = null

    internal fun setOnFrameParsed(callback: (ParsedFrame) -> Unit) {
        onFrameParsed = callback
    }

    /**
     * 接收新的 BLE notify 数据
     * @param data BLE notify 回调的原始数据
     */
    fun receive(data: ByteArray) {
        synchronized(lock) {
            data.forEach { buffer.add(it) }

            // 防止缓冲区无限增长
            if (buffer.size > MAX_BUFFER_SIZE) {
                BlueLogger.warn("StreamFrameParser buffer overflow (${buffer.size} bytes), cleared")
                buffer.clear()
                return
            }

            extractFrames()
        }
    }

    /** 清空缓冲区（断开连接时调用）*/
    fun reset() {
        synchronized(lock) {
            buffer.clear()
        }
    }

    private fun extractFrames() {
        while (true) {
            // 查找帧头 0x55 0xAA
            val headerIndex = findHeader() ?: run {
                if (buffer.isNotEmpty()) {
                    BlueLogger.debug("StreamFrameParser: no header, discarding ${buffer.size} bytes")
                    buffer.clear()
                }
                return
            }

            // 丢弃帧头之前的垃圾数据
            if (headerIndex > 0) {
                BlueLogger.debug("StreamFrameParser: discarding $headerIndex bytes before header")
                repeat(headerIndex) { buffer.removeAt(0) }
            }

            // 检查是否有足够数据读取长度字段
            if (buffer.size < FrameConstants.DATA_OFFSET) return

            // 读取数据长度
            val lenHigh = buffer[FrameConstants.LEN_HIGH_OFFSET].toInt() and 0xFF
            val lenLow = buffer[FrameConstants.LEN_LOW_OFFSET].toInt() and 0xFF
            val dataLen = (lenHigh shl 8) or lenLow

            // 计算完整帧长度：帧头2 + 版本1 + CMD1 + Len2 + 数据N + CRC1 = 7 + N
            val frameLength = FrameConstants.MIN_FRAME_LENGTH + dataLen

            // 检查缓冲区是否有完整帧
            if (buffer.size < frameLength) return

            // 提取完整帧
            val frameBytes = ByteArray(frameLength) { buffer[it] }
            repeat(frameLength) { buffer.removeAt(0) }

            // 解析帧（CRC 校验失败会静默丢弃）
            val frame = FrameParser.parse(frameBytes)
            if (frame != null) {
                onFrameParsed?.invoke(frame)
            } else {
                BlueLogger.warn("StreamFrameParser: CRC failed, discarded $frameLength bytes")
            }
        }
    }

    /**
     * 在缓冲区中查找帧头 0x55 0xAA 的位置
     * @return 帧头起始位置，未找到返回 null
     */
    private fun findHeader(): Int? {
        for (i in 0 until buffer.size - 1) {
            if (buffer[i] == FrameConstants.HEADER_BYTE1 &&
                buffer[i + 1] == FrameConstants.HEADER_BYTE2) {
                return i
            }
        }
        return null
    }
}
