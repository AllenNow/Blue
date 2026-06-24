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

    fun queryAlarm(index: Int, completion: (Result<AlarmInfo>) -> Unit) {
        val dpid = DPIDConstants.alarmDPID(index) ?: run {
            completion(Result.failure(BlueError.InvalidParameter)); return
        }
        val data = byteArrayOf(dpid)
        val frame = FrameBuilder.build(CommandCode.SEND_COMMAND, data)
        commandQueue.enqueue(CommandCode.SEND_COMMAND, frame) { result ->
            result.fold(
                onSuccess = { response ->
                    parseAlarmInfo(response.data, index)?.let {
                        completion(Result.success(it))
                    } ?: completion(Result.failure(BlueError.ProtocolError))
                },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    fun clearAllAlarms(completion: (Result<Unit>) -> Unit) {
        // 逐个删除 1~7 号闹钟槽位（DPID 0x70 实际是提醒持续时间，非清空闹钟）
        fun deleteNext(index: Int) {
            if (index > 7) {
                completion(Result.success(Unit))
                return
            }
            deleteAlarm(index) { result ->
                result.fold(
                    onSuccess = { deleteNext(index + 1) },
                    onFailure = { completion(Result.failure(it)) }
                )
            }
        }
        deleteNext(1)
    }

    companion object {
        fun parseAlarmInfo(data: ByteArray, index: Int): AlarmInfo? {
            if (data.size < 11) return null
            return AlarmInfo(
                index = index,
                hour = data[5].toInt() and 0xFF,
                minute = data[6].toInt() and 0xFF,
                weekMask = data[7].toInt() and 0xFF,
                ringingState = data[9].toInt() and 0xFF,
                eventStatus = data[10].toInt() and 0xFF
            )
        }
    }
}
