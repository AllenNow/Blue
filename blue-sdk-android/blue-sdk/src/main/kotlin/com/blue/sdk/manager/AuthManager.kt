// AuthManager.kt
// BlueSDK - 身份认证管理器（FR08~FR11）

package com.blue.sdk.manager

import com.blue.sdk.error.BlueError
import com.blue.sdk.internal.BlueLogger
import com.blue.sdk.internal.CommandQueue
import com.blue.sdk.transport.CommandCode
import com.blue.sdk.transport.FrameBuilder

internal class AuthManager(private val commandQueue: CommandQueue) {

    /**
     * 发送密钥包完成设备认证（FR08）
     * 密钥算法：手机 MAC 6字节 + 设备 MAC 6字节全部累加，取 16-bit 总和的高低两字节
     * 密钥值不写入任何日志（NFR06、NFR07）
     */
    fun authenticate(
        phoneMac: ByteArray,
        deviceMac: ByteArray,
        completion: (Result<Unit>) -> Unit
    ) {
        if (phoneMac.size != 6 || deviceMac.size != 6) {
            completion(Result.failure(BlueError.InvalidParameter))
            return
        }
        // 计算密钥：12字节全部累加得到 16-bit 总和（密钥值不输出到日志）
        val sum = (phoneMac.toList() + deviceMac.toList()).fold(0) { acc, byte ->
            acc + (byte.toInt() and 0xFF)
        }
        val keyBytes = byteArrayOf(
            ((sum shr 8) and 0xFF).toByte(),
            (sum and 0xFF).toByte()
        )
        BlueLogger.debug("Sending auth key packet (key value redacted)")
        val frame = FrameBuilder.build(CommandCode.AUTH_KEY, keyBytes)
        commandQueue.enqueue(CommandCode.AUTH_KEY, frame) { result ->
            result.fold(
                onSuccess = { response ->
                    val success = response.data.firstOrNull()?.toInt() == 0x01
                    if (success) completion(Result.success(Unit))
                    else completion(Result.failure(BlueError.AuthFailed))
                },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    companion object {
        /** 计算密钥（仅供测试使用）
         *  算法：12字节全部累加得到 16-bit 总和，返回 [高字节, 低字节]
         */
        internal fun calculateKey(phoneMac: ByteArray, deviceMac: ByteArray): ByteArray {
            val sum = (phoneMac.toList() + deviceMac.toList()).fold(0) { acc, byte ->
                acc + (byte.toInt() and 0xFF)
            }
            return byteArrayOf(
                ((sum shr 8) and 0xFF).toByte(),
                (sum and 0xFF).toByte()
            )
        }
    }
}
