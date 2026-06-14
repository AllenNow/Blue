// DeviceManager.kt
// BlueSDK - 设备信息查询与时间同步（FR12~FR14）

package com.blue.sdk.manager

import com.blue.sdk.error.BlueError
import com.blue.sdk.internal.CommandQueue
import com.blue.sdk.model.DeviceInfo
import com.blue.sdk.transport.CommandCode
import com.blue.sdk.transport.FrameBuilder
import java.util.Calendar
import java.util.TimeZone

internal class DeviceManager(private val commandQueue: CommandQueue) {

    fun queryDeviceInfo(completion: (Result<DeviceInfo>) -> Unit) {
        val frame = FrameBuilder.build(CommandCode.QUERY_DEVICE_INFO)
        commandQueue.enqueue(CommandCode.QUERY_DEVICE_INFO, frame) { result ->
            result.fold(
                onSuccess = { response ->
                    val version = String(response.data, Charsets.US_ASCII).ifEmpty { "Unknown" }
                    completion(Result.success(DeviceInfo(firmwareVersion = version, macAddress = "")))
                },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    /**
     * 向设备下发当前系统时间（FR14）
     * 使用 sendDirect 直接发送，不经过指令队列排队等待应答
     */
    fun syncTime(timeMs: Long = System.currentTimeMillis(), completion: (Result<Unit>) -> Unit) {
        val data = buildTimeSyncData(timeMs)
        val frame = FrameBuilder.build(CommandCode.TIME_SYNC, data)
        commandQueue.sendDirect(frame)
        completion(Result.success(Unit))
    }

    private fun buildTimeSyncData(timeMs: Long): ByteArray {
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = timeMs
        
        val year = calendar.get(Calendar.YEAR)
        val yearOffset = (year - 2018).coerceIn(0, 255).toByte()
        val month = (calendar.get(Calendar.MONTH) + 1).toByte()
        val day = calendar.get(Calendar.DAY_OF_MONTH).toByte()
        val hour = calendar.get(Calendar.HOUR_OF_DAY).toByte()
        val minute = calendar.get(Calendar.MINUTE).toByte()
        val second = calendar.get(Calendar.SECOND).toByte()
        // 星期：Calendar.SUNDAY=1...SATURDAY=7 → 协议 1=周一...7=周日
        val calWeekday = calendar.get(Calendar.DAY_OF_WEEK)
        val weekday = (if (calWeekday == Calendar.SUNDAY) 7 else calWeekday - 1).toByte()
        
        // 时区偏移（分钟）
        val tzOffset = TimeZone.getDefault().getOffset(timeMs) / 60000
        val tzHigh = ((tzOffset shr 8) and 0xFF).toByte()
        val tzLow = (tzOffset and 0xFF).toByte()
        
        return byteArrayOf(0x00, 0x00, yearOffset, month, day, hour, minute, second, weekday, tzHigh, tzLow)
    }
}
