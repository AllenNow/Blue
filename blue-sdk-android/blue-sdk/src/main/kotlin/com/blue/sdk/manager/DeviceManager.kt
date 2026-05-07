// DeviceManager.kt
// BlueSDK - 设备信息查询与时间同步（FR12~FR14）

package com.blue.sdk.manager

import com.blue.sdk.error.BlueError
import com.blue.sdk.internal.CommandQueue
import com.blue.sdk.model.DeviceInfo
import com.blue.sdk.transport.CommandCode
import com.blue.sdk.transport.FrameBuilder
import java.util.Calendar

internal class DeviceManager(private val commandQueue: CommandQueue) {

    fun queryDeviceInfo(completion: (Result<DeviceInfo>) -> Unit) {
        val frame = FrameBuilder.build(CommandCode.QUERY_DEVICE_INFO)
        commandQueue.enqueue(CommandCode.QUERY_DEVICE_INFO, frame) { result ->
            result.fold(
                onSuccess = { response ->
                    val version = String(response.data, Charsets.US_ASCII).ifEmpty { "Unknown" }
                    completion(Result.success(DeviceInfo(firmwareVersion = version, deviceId = "")))
                },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    /**
     * 向设备下发当前系统时间（FR14）
     *
     * ⚠️ TODO: 时间同步帧格式待硬件方确认
     * 协议文档示例帧：55 AA 00 E1 00 0B 00 00 01 0C 1E 0F 34 1F 01 03 20 9C
     * 疑点：年份字段、字节总数、时区编码均与预期不符，待确认后修复
     */
    fun syncTime(timeMs: Long = System.currentTimeMillis(), completion: (Result<Unit>) -> Unit) {
        val data = buildTimeSyncData(timeMs)
        val frame = FrameBuilder.build(CommandCode.TIME_SYNC, data)
        commandQueue.enqueue(CommandCode.TIME_SYNC, frame) { result ->
            result.fold(
                onSuccess = { completion(Result.success(Unit)) },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    private fun buildTimeSyncData(timeMs: Long): ByteArray {
        val cal = Calendar.getInstance().apply { timeInMillis = timeMs }
        val year    = cal.get(Calendar.YEAR)
        val month   = cal.get(Calendar.MONTH) + 1
        val day     = cal.get(Calendar.DAY_OF_MONTH)
        val hour    = cal.get(Calendar.HOUR_OF_DAY)
        val minute  = cal.get(Calendar.MINUTE)
        val second  = cal.get(Calendar.SECOND)
        // Calendar.DAY_OF_WEEK: 1=周日，协议 bit0=周日
        val weekday = cal.get(Calendar.DAY_OF_WEEK) - 1
        val tzOffsetMin = cal.timeZone.getOffset(timeMs) / 60000
        return byteArrayOf(
            ((year shr 8) and 0xFF).toByte(),
            (year and 0xFF).toByte(),
            month.toByte(),
            day.toByte(),
            hour.toByte(),
            minute.toByte(),
            second.toByte(),
            weekday.toByte(),
            ((tzOffsetMin shr 8) and 0xFF).toByte(),
            (tzOffsetMin and 0xFF).toByte()
        )
    }
}
