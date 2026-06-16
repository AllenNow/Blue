// StreamFrameParser.kt
// BlueSDK - 流式帧解析器

package com.blue.sdk.transport

internal class StreamFrameParser {

    private val buffer = mutableListOf<Byte>()
    private var onFrameParsed: ((ParsedFrame) -> Unit)? = null

    internal fun setOnFrameParsed(callback: (ParsedFrame) -> Unit) {
        onFrameParsed = callback
    }

    fun receive(data: ByteArray) {
        buffer.addAll(data.asList())
        parse()
    }

    fun reset() {
        buffer.clear()
    }

    private fun parse() {
        while (buffer.size >= FrameConstants.MIN_FRAME_LENGTH) {
            val headerStart = buffer.indexOf(FrameConstants.HEADER_BYTE1)
            if (headerStart == -1) {
                buffer.clear()
                return
            }

            if (headerStart > 0) {
                for (i in 0 until headerStart) {
                    buffer.removeAt(0)
                }
            }

            if (buffer.size < FrameConstants.MIN_FRAME_LENGTH) return

            val lenHigh = buffer[FrameConstants.LEN_HIGH_OFFSET].toInt() and 0xFF
            val lenLow = buffer[FrameConstants.LEN_LOW_OFFSET].toInt() and 0xFF
            val length = (lenHigh shl 8) or lenLow + FrameConstants.DATA_OFFSET + 1

            if (buffer.size < length) return

            val frameBytes = buffer.subList(0, length).toByteArray()
            for (i in 0 until length) {
                buffer.removeAt(0)
            }

            FrameParser.parse(frameBytes)?.let { parsed ->
                onFrameParsed?.invoke(parsed)
            }
        }
    }
}