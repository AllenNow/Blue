// AlarmManager.kt
// BlueSDK - 闹钟管理器（FR15~FR19）

package com.blue.sdk.manager

import com.blue.sdk.error.BlueError
import com.blue.sdk.internal.CommandQueue
import com.blue.sdk.model.AlarmInfo
import com.blue.sdk.transport.CommandCode
import com.blue.sdk.transport.DPIDConstants
import com.blue.sdk.transport.FrameBuilder

internal class AlarmManager(private val commandQueue: CommandQueue) {

    fun setAlarm(
        index: Int,
        hour: Int,
        minute: Int,
        weekMask: Int = 0x7F,
        completion: (Result<AlarmInfo>) -> Unit
    ) {
        val dpid = DPIDConstants.alarmDPID(index) ?: run {
            completion(Result.failure(BlueError.InvalidParameter)); return
        }
        val data = byteArrayOf(dpid, 0x00, 0x00, 0x07, 0x01,
            hour.toByte(), minute.toByte(), weekMask.toByte(), 0x00, 0x00, 0x00)
        val frame = FrameBuilder.build(CommandCode.SEND_COMMAND, data)
        commandQueue.enqueue(CommandCode.SEND_COMMAND, frame) { result ->
            result.fold(
                onSuccess = { completion(Result.success(AlarmInfo(index, hour, minute, weekMask, 0))) },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    fun deleteAlarm(index: Int, completion: (Result<Unit>) -> Unit) {
        val dpid = DPIDConstants.alarmDPID(index) ?: run {
            completion(Result.failure(BlueError.InvalidParameter)); return
        }
        val data = byteArrayOf(dpid, 0x00, 0x00, 0x07,
            0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(),
            0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte())
        val frame = FrameBuilder.build(CommandCode.SEND_COMMAND, data)
        commandQueue.enqueue(CommandCode.SEND_COMMAND, frame) { result ->
            result.fold(
                onSuccess = { completion(Result.success(Unit)) },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    fun clearAllAlarms(completion: (Result<Unit>) -> Unit) {
        val data = byteArrayOf(DPIDConstants.EMPTY_ALL_ALARMS, 0x00, 0x00, 0x01, 0x01)
        val frame = FrameBuilder.build(CommandCode.SEND_COMMAND, data)
        commandQueue.enqueue(CommandCode.SEND_COMMAND, frame) { result ->
            result.fold(
                onSuccess = { completion(Result.success(Unit)) },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    companion object {
        fun parseAlarmInfo(data: ByteArray, index: Int): AlarmInfo? {
            if (data.size < 11) return null
            return AlarmInfo(
                index = index,
                hour = data[5].toInt() and 0xFF,
                minute = data[6].toInt() and 0xFF,
                weekMask = data[7].toInt() and 0xFF,
                advanceStatus = data[10].toInt() and 0xFF
            )
        }
    }
}
