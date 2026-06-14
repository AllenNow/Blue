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

    /**
     * 设置音量等级
     * 使用 DPID 0x6E（ALERT_DURATION），type=0x04
     * 帧格式：6E 04 00 01 XX（01低/02中/03高）
     */
    fun setVolume(level: VolumeLevel, completion: (Result<Unit>) -> Unit) {
        sendCommand(byteArrayOf(DPIDConstants.ALERT_DURATION, 0x04, 0x00, 0x01, level.protocolValue), completion)
    }

    /**
     * 设置铃声类型
     * 使用 DPID 0x6F（NOTIFICATION_OF_RESULTS）
     * 帧格式：6F 04 00 01 XX（01=A/02=B/03=C）
     */
    fun setSoundType(type: SoundType, completion: (Result<Unit>) -> Unit) {
        sendCommand(byteArrayOf(DPIDConstants.NOTIFICATION_OF_RESULTS, 0x04, 0x00, 0x01, type.protocolValue), completion)
    }

    fun setSilence(enabled: Boolean, completion: (Result<Unit>) -> Unit) {
        val value: Byte = if (enabled) 0x01 else 0x00
        sendCommand(byteArrayOf(DPIDConstants.SILENCE, 0x04, 0x00, 0x01, value), completion)
    }

    /**
     * 设置提醒持续时间（分钟）
     * 使用 DPID 0x70（EMPTY_ALL_ALARMS），type=0x02
     * 帧格式：70 02 00 04 00 00 00 XX（分钟数）
     */
    fun setAlertDuration(minutes: Int, completion: (Result<Unit>) -> Unit) {
        sendCommand(byteArrayOf(DPIDConstants.EMPTY_ALL_ALARMS, 0x02, 0x00, 0x04,
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
