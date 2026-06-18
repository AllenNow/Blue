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
     * 帧格式：78 04 00 01 XX（01低/02中/03高）
     * 协议示例：55 AA 00 06 00 05 78 04 00 01 01 88
     */
    fun setVolume(level: VolumeLevel, completion: (Result<Unit>) -> Unit) {
        sendCommand(byteArrayOf(0x78.toByte(), 0x04, 0x00, 0x01, level.protocolValue), completion)
    }

    /**
     * 设置铃声类型
     * 使用 DPID 0x6D（TYPE_OF_SOUND）
     * 帧格式：6D 04 00 01 XX（00=静音/01=A/02=B/03=C）
     */
    fun setSoundType(type: SoundType, completion: (Result<Unit>) -> Unit) {
        sendCommand(byteArrayOf(DPIDConstants.TYPE_OF_SOUND, 0x04, 0x00, 0x01, type.protocolValue), completion)
    }

    /** 设置静音（通过铃声类型=0x00实现，取消静音恢复为类型A）*/
    fun setSilence(enabled: Boolean, completion: (Result<Unit>) -> Unit) {
        if (enabled) setSoundType(SoundType.MUTE, completion)
        else setSoundType(SoundType.TYPE_A, completion)
    }

    /**
     * 设置提醒持续时间（分钟）
     * 使用 DPID 0x70（EMPTY_ALL_ALARMS），type=0x02
     * 帧格式：6E 02 00 04 00 00 00 XX
     * 协议示例：55 AA 00 06 00 08 6E 02 00 04 00 00 00 05 86（2分钟，值=5）
     */
    /**
     * 设置提醒持续时长（1~5分钟）
     * Set alert duration (1~5 minutes)
     */
    fun setAlertDuration(minutes: Int, completion: (Result<Unit>) -> Unit) {
        if (minutes < 1 || minutes > 5) {
            completion(Result.failure(BlueError.InvalidParameter))
            return
        }
        sendCommand(byteArrayOf(DPIDConstants.ALERT_DURATION, 0x02, 0x00, 0x04,
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
