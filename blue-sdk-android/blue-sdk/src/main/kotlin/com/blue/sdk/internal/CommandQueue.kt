// CommandQueue.kt
// BlueSDK - 指令串行队列（ARCH-04）
// 同一时刻只允许一条指令在等待应答，支持多指令 FIFO 排队
// 超时 5 秒自动重试，最多重试 3 次（NFR02）

package com.blue.sdk.internal

import android.os.Handler
import android.os.Looper
import com.blue.sdk.error.BlueError
import com.blue.sdk.transport.CommandCode
import com.blue.sdk.transport.FrameConstants
import com.blue.sdk.transport.ParsedFrame
import java.util.LinkedList

internal class CommandQueue {

    companion object {
        const val DEFAULT_TIMEOUT_MS = 5000L
        const val DEFAULT_MAX_RETRIES = 3
    }

    private data class PendingCommand(
        val cmd: Byte,
        val frame: ByteArray,
        val retryCount: Int,
        val maxRetries: Int,
        val timeoutMs: Long,
        val completion: (Result<ParsedFrame>) -> Unit
    )

    private var pendingCommand: PendingCommand? = null   // 当前等待应答的指令
    private val waitingQueue = LinkedList<PendingCommand>() // FIFO 等待队列
    private val lock = Any()
    private val handler = Handler(Looper.getMainLooper())
    private var timeoutRunnable: Runnable? = null

    /** 发送指令的实际执行块（由 BLEConnector 注入）*/
    var sendBlock: ((ByteArray) -> Unit)? = null

    fun enqueue(
        cmd: Byte,
        frame: ByteArray,
        timeoutMs: Long = DEFAULT_TIMEOUT_MS,
        maxRetries: Int = DEFAULT_MAX_RETRIES,
        completion: (Result<ParsedFrame>) -> Unit
    ) {
        synchronized(lock) {
            val command = PendingCommand(cmd, frame, 0, maxRetries, timeoutMs, completion)
            if (pendingCommand == null) {
                pendingCommand = command
                send(command)
            } else {
                waitingQueue.add(command)
            }
        }
    }

    /**
     * 直接发送帧，不经过队列排队和等待应答（用于时间同步等 fire-and-forget 场景）
     */
    fun sendDirect(frame: ByteArray) {
        BlueLogger.debug("直接发送: ${frame.size} 字节")
        sendBlock?.invoke(frame)
    }

    fun handleResponse(frame: ParsedFrame): Boolean {
        synchronized(lock) {
            val pending = pendingCommand ?: return false
            val cmdInt = pending.cmd.toInt() and 0xFF
            val respInt = frame.cmd.toInt() and 0xFF
            val isMatch = respInt == cmdInt + 1 || respInt == cmdInt
            if (!isMatch) return false
            
            // 对于 sendCommand(0x06) 的应答(0x07)，需匹配 DPID 避免主动上报帧误匹配
            if (cmdInt == (CommandCode.SEND_COMMAND.toInt() and 0xFF) &&
                respInt == (CommandCode.DEVICE_REPORT.toInt() and 0xFF)) {
                val pendingDPID = if (pending.frame.size > FrameConstants.DATA_OFFSET)
                    pending.frame[FrameConstants.DATA_OFFSET] else null
                val responseDPID = frame.data.firstOrNull()
                if (pendingDPID != null && responseDPID != null && pendingDPID != responseDPID) {
                    return false
                }
            }

            cancelTimeout()
            pendingCommand = null
            pending.completion(Result.success(frame))
            sendNext()
            return true
        }
    }

    fun clear() {
        synchronized(lock) {
            cancelTimeout()
            pendingCommand?.let { it.completion(Result.failure(BlueError.Disconnected)) }
            pendingCommand = null
            waitingQueue.forEach { it.completion(Result.failure(BlueError.Disconnected)) }
            waitingQueue.clear()
        }
    }

    private fun send(command: PendingCommand) {
        BlueLogger.debug("发送指令: 0x${"%02X".format(command.cmd.toInt() and 0xFF)} (重试${command.retryCount})")
        val block = sendBlock
        if (block == null) {
            // 没有连接，立即回调 Disconnected 错误
            pendingCommand = null
            command.completion(Result.failure(BlueError.Disconnected))
            sendNext()
            return
        }
        block.invoke(command.frame)
        scheduleTimeout(command)
    }

    private fun sendNext() {
        if (waitingQueue.isEmpty()) return
        val next = waitingQueue.poll() ?: return
        pendingCommand = next
        // 指令间隔至少 200ms
        handler.postDelayed({ send(next) }, 200)
    }

    private fun scheduleTimeout(command: PendingCommand) {
        cancelTimeout()
        val runnable = Runnable { handleTimeout() }
        timeoutRunnable = runnable
        handler.postDelayed(runnable, command.timeoutMs)
    }

    private fun handleTimeout() {
        synchronized(lock) {
            val command = pendingCommand ?: return
            if (command.retryCount < command.maxRetries) {
                val retried = command.copy(retryCount = command.retryCount + 1)
                pendingCommand = retried
                send(retried)
            } else {
                pendingCommand = null
                command.completion(Result.failure(BlueError.Timeout))
                sendNext()
            }
        }
    }

    private fun cancelTimeout() {
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
    }
}
