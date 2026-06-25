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
        // DPID 0x70 清空所有闹钟，单条指令
        val data = byteArrayOf(DPIDConstants.EMPTY_ALL_ALARMS, 0x01, 0x00, 0x01, 0x01)
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
            // 最少需要 8 字节才能解析基本闹钟信息（DPID+type/len+enabled+hour+minute+weekMask）
            if (data.size < 8) return null
            val hour = data[5].toInt() and 0xFF
            val minute = data[6].toInt() and 0xFF
            val weekMask = data[7].toInt() and 0xFF
            val ringingState = if (data.size > 9) data[9].toInt() and 0xFF else 0
            val eventStatus = if (data.size > 10) data[10].toInt() and 0xFF else 0
            return AlarmInfo(
                index = index,
                hour = hour,
                minute = minute,
                weekMask = weekMask,
                ringingState = ringingState,
                eventStatus = eventStatus
            )
        }
    }
}
