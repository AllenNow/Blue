// AudioManager.kt
// BlueSDK - 音频与系统设置管理器（FR25~FR31）

package com.blue.sdk.manager

import com.blue.sdk.enums.SoundType
import com.blue.sdk.enums.TimeFormat
import com.blue.sdk.enums.VolumeLevel
import com.blue.sdk.error.BlueError
import com.blue.sdk.internal.CommandQueue
import com.blue.sdk.transport.CommandCode
import com.blue.sdk.transport.DPIDConstants
import com.blue.sdk.transport.FrameBuilder

internal class AudioManager(private val commandQueue: CommandQueue) {

    fun setVolume(level: VolumeLevel, completion: (Result<Unit>) -> Unit) {
        sendCommand(byteArrayOf(DPIDConstants.VOLUME_LEVEL, 0x04, 0x00, 0x01, level.protocolValue), completion)
    }

    fun setSoundType(type: SoundType, completion: (Result<Unit>) -> Unit) {
        sendCommand(byteArrayOf(DPIDConstants.SOUND_TYPE_SETTING, 0x04, 0x00, 0x01, type.protocolValue), completion)
    }

    fun setSilence(enabled: Boolean, completion: (Result<Unit>) -> Unit) {
        val value: Byte = if (enabled) 0x01 else 0x00
        sendCommand(byteArrayOf(DPIDConstants.SILENCE, 0x04, 0x00, 0x01, value), completion)
    }

    fun setAlertDuration(minutes: Int, completion: (Result<Unit>) -> Unit) {
        sendCommand(byteArrayOf(DPIDConstants.ALERT_DURATION_SETTING, 0x02, 0x00, 0x04,
            0x00, 0x00, 0x00, minutes.toByte()), completion)
    }

    fun setTimeFormat(format: TimeFormat, completion: (Result<Unit>) -> Unit) {
        sendCommand(byteArrayOf(DPIDConstants.TIME_FORMAT, 0x04, 0x00, 0x01, format.protocolValue), completion)
    }

    private fun sendCommand(data: ByteArray, completion: (Result<Unit>) -> Unit) {
        val frame = FrameBuilder.build(CommandCode.SEND_COMMAND, data)
        commandQueue.enqueue(CommandCode.SEND_COMMAND, frame) { result ->
            result.fold(
                onSuccess = { completion(Result.success(Unit)) },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    companion object {
        fun parseSoundType(data: ByteArray): SoundType? =
            if (data.size >= 5) SoundType.fromByte(data[4]) else null

        fun parseTimeFormat(data: ByteArray): TimeFormat? =
            if (data.size >= 5) TimeFormat.values().find { it.protocolValue == data[4] } else null
    }
}
