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
     * 密钥算法：手机 MAC + 设备 MAC 逐字节累加取低字节
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
        // 计算密钥（密钥值不输出到日志）
        val keyBytes = ByteArray(6) { i ->
            ((phoneMac[i].toInt() and 0xFF) + (deviceMac[i].toInt() and 0xFF) and 0xFF).toByte()
        }
        BlueLogger.debug("发送认证密钥包（密钥值已脱敏）")
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
        /** 计算密钥（仅供测试使用）*/
        internal fun calculateKey(phoneMac: ByteArray, deviceMac: ByteArray): ByteArray =
            ByteArray(6) { i ->
                ((phoneMac[i].toInt() and 0xFF) + (deviceMac[i].toInt() and 0xFF) and 0xFF).toByte()
            }
    }
}
