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

    /**
     * 查询设备基础信息（FR12）
     * 应答格式：[MAC 6字节][...][固件版本 ASCII]
     * 示例：6F 74 36 74 74 64 35 6A 31 2E 30 2E 30
     *       MAC=6F:74:36:74:74:64, 固件版本="1.0.0"
     */
    fun queryDeviceInfo(completion: (Result<DeviceInfo>) -> Unit) {
        val frame = FrameBuilder.build(CommandCode.QUERY_DEVICE_INFO)
        commandQueue.enqueue(CommandCode.QUERY_DEVICE_INFO, frame) { result ->
            result.fold(
                onSuccess = { response ->
                    val data = response.data
                    if (data.size < 6) {
                        completion(Result.failure(BlueError.InvalidParameter))
                        return@fold
                    }
                    // 前 6 字节为设备 MAC 地址
                    val macBytes = data.copyOfRange(0, 6)
                    val macAddress = macBytes.joinToString(":") { "%02X".format(it) }
                    // 从第7字节开始查找固件版本（匹配 "x.x.x" 格式）
                    val remaining = data.copyOfRange(6, data.size)
                    val asciiStr = String(remaining, Charsets.US_ASCII)
                    val version = DeviceInfo.parseFirmwareVersion(asciiStr)
                    completion(Result.success(DeviceInfo(
                        firmwareVersion = version,
                        macAddress = macAddress
                    )))
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

    /**
     * 构建时间同步数据字节
     * 格式（11字节）：[0x00][0x00][年偏移(从2018)][月][日][时][分][秒][星期(1=周一~7=周日)][时区高][时区低]
     */
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
