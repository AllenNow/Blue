// MedicationManager.kt
// BlueSDK - 用药事件管理器（FR20~FR24）

package com.blue.sdk.manager

import com.blue.sdk.error.BlueError
import com.blue.sdk.internal.CommandQueue
import com.blue.sdk.model.MedicationRecord
import com.blue.sdk.enums.MedicationStatus
import com.blue.sdk.transport.CommandCode
import com.blue.sdk.transport.DPIDConstants
import com.blue.sdk.transport.FrameBuilder
import java.util.Calendar

internal class MedicationManager(private val commandQueue: CommandQueue) {

    fun sendMedicationNotification(status: Byte, completion: (Result<Unit>) -> Unit) {
        // 用药结果通知使用 0x6F（SOUND_TYPE_SETTING 同值，协议文档注释有歧义，以示例帧为准）
        val data = byteArrayOf(0x6F.toByte(), 0x00, 0x00, 0x01, status)
        val frame = FrameBuilder.build(CommandCode.SEND_COMMAND, data)
        commandQueue.enqueue(CommandCode.SEND_COMMAND, frame) { result ->
            result.fold(
                onSuccess = { completion(Result.success(Unit)) },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    companion object {
        fun parseMedicationEvent(data: ByteArray): Pair<Int, MedicationStatus>? {
            if (data.size < 11) return null
            // alarmIndex 直接从 DPID（data[0]）推导
            val alarmIndex = DPIDConstants.alarmIndex(data[0]) ?: return null
            val status = MedicationStatus.fromByte(data[10]) ?: return null
            return Pair(alarmIndex, status)
        }

        fun parseMedicationRecord(data: ByteArray): MedicationRecord? {
            // data[4] 是关联的闹钟 DPID
            if (data.size < 13) return null
            val alarmIndex = DPIDConstants.alarmIndex(data[4]) ?: return null
            val year   = ((data[5].toInt() and 0xFF) shl 8) or (data[6].toInt() and 0xFF)
            val month  = data[7].toInt() and 0xFF
            val day    = data[8].toInt() and 0xFF
            val hour   = data[9].toInt() and 0xFF
            val minute = data[10].toInt() and 0xFF
            val status = MedicationStatus.fromByte(data[11]) ?: return null
            val cal = Calendar.getInstance().apply {
                set(year, month - 1, day, hour, minute, 0)
                set(Calendar.MILLISECOND, 0)
            }
            return MedicationRecord(
                timestamp = cal.timeInMillis,
                alarmIndex = alarmIndex,
                status = status
            )
        }
    }
}
