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
        // 用药结果通知使用 DPID 0x6F（NOTIFICATION_OF_RESULTS）
        val data = byteArrayOf(DPIDConstants.NOTIFICATION_OF_RESULTS, 0x00, 0x00, 0x01, status)
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
            val alarmIndex = DPIDConstants.alarmIndex(data[0]) ?: return null
            val status = MedicationStatus.fromByte(data[10]) ?: return null
            return Pair(alarmIndex, status)
        }

        /**
         * 解析用药记录上报帧（DPID=0x65）
         * 数据格式（15字节）：
         *   [0]=DPID(0x65) [1-3]=type/len(00 00 0B)
         *   [4]=闹钟DP点 [5-6]=年(高低) [7]=月 [8]=日
         *   [9]=闹钟小时 [10]=闹钟分钟 [11]=响铃小时 [12]=响铃分钟
         *   [13]=状态(01取药/02超时/03漏服/04提前) [14]=提前标志
         */
        fun parseMedicationRecord(data: ByteArray): MedicationRecord? {
            if (data.size < 14) return null

            val alarmDPID = data[4]
            val alarmIndex = DPIDConstants.alarmIndex(alarmDPID) ?: return null

            val yearHigh = data[5].toInt() and 0xFF
            val yearLow = data[6].toInt() and 0xFF
            val year = (yearHigh shl 8) or yearLow
            val month = data[7].toInt() and 0xFF
            val day = data[8].toInt() and 0xFF
            val alarmHour = data[9].toInt() and 0xFF
            val alarmMinute = data[10].toInt() and 0xFF
            val eventHour = data[11].toInt() and 0xFF
            val eventMinute = data[12].toInt() and 0xFF
            val statusByte = data[13]

            val status = MedicationStatus.fromByte(statusByte) ?: return null

            val cal = Calendar.getInstance().apply {
                set(year, month - 1, day, eventHour, eventMinute, 0)
                set(Calendar.MILLISECOND, 0)
            }
            // 使用帧中的日期+时分作为基础，加上当前秒和毫秒确保同一分钟内的记录不重复
            val baseTime = cal.timeInMillis
            val currentSecMs = System.currentTimeMillis() % 60000 // 当前秒+毫秒部分
            return MedicationRecord(
                timestamp = baseTime + currentSecMs,
                alarmIndex = alarmIndex,
                alarmHour = alarmHour,
                alarmMinute = alarmMinute,
                status = status
            )
        }
    }
}
