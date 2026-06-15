// ConnectionManager.kt
// BlueSDK - 连接状态机（ARCH-07）

package com.blue.sdk.manager

import android.bluetooth.BluetoothDevice
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.blue.sdk.enums.ConnectionState
import com.blue.sdk.error.BlueError
import com.blue.sdk.internal.BlueLogger
import com.blue.sdk.internal.CallbackDispatcher
import com.blue.sdk.internal.CommandQueue
import com.blue.sdk.transport.BLEConnector
import com.blue.sdk.transport.BLEConnectorDelegate
import com.blue.sdk.transport.CommandCode
import com.blue.sdk.transport.ParsedFrame
import com.blue.sdk.transport.StreamFrameParser
import java.util.Timer
import java.util.TimerTask

internal class ConnectionManager(private val context: Context) {

    companion object {
        private val RECONNECT_DELAYS = longArrayOf(2000L, 4000L, 8000L)
        private const val MAX_RECONNECT_ATTEMPTS = 5
        private const val CONNECTION_TIMEOUT_MS = 15000L
    }

    private val connector = BLEConnector()
    private val streamParser = StreamFrameParser()
    val commandQueue = CommandQueue()

    @Volatile private var _state: ConnectionState = ConnectionState.DISCONNECTED
    val state: ConnectionState get() = _state

    private var targetDevice: BluetoothDevice? = null
    private var reconnectAttempts = 0
    private var reconnectTimer: Timer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var connectionTimeoutRunnable: Runnable? = null

    var onStateChanged: ((ConnectionState) -> Unit)? = null
    var onError: ((BlueError) -> Unit)? = null
    var onDataReceived: ((ParsedFrame) -> Unit)? = null
    var onReconnecting: ((attempt: Int, maxAttempts: Int) -> Unit)? = null
    var onReconnectFailed: (() -> Unit)? = null

    init {
        // 流式解析器回调
        streamParser.onFrameParsed = { frame -> handleParsedFrame(frame) }

        connector.delegate = object : BLEConnectorDelegate {
            override fun onConnected() {
                cancelConnectionTimeout()
                reconnectAttempts = 0
                cancelReconnect()
                transitionTo(ConnectionState.CONNECTED)
            }
            override fun onDisconnected(error: Exception?) {
                cancelConnectionTimeout()
                commandQueue.clear()
                streamParser.reset()
                if (_state == ConnectionState.DISCONNECTED) return
                if (error != null) startReconnect()
                else transitionTo(ConnectionState.DISCONNECTED)
            }
            override fun onDataReceived(data: ByteArray) {
                // 通过流式解析器处理粘包/分包
                streamParser.receive(data)
            }
        }
        commandQueue.sendBlock = { bytes -> connector.write(bytes) }
    }

    private fun handleParsedFrame(frame: ParsedFrame) {
        val cmdInt = frame.cmd.toInt() and 0xFF
        // 时间同步帧始终作为上报处理
        if (cmdInt == (CommandCode.TIME_SYNC.toInt() and 0xFF)) {
            onDataReceived?.invoke(frame)
            return
        }
        // 其他帧（含 CMD=0x07）先尝试 CommandQueue 匹配，匹配失败则作为上报
        if (!commandQueue.handleResponse(frame)) {
            onDataReceived?.invoke(frame)
        }
    }

    fun connect(device: BluetoothDevice) {
        if (_state != ConnectionState.DISCONNECTED) return
        targetDevice = device
        transitionTo(ConnectionState.CONNECTING)
        connector.connect(context, device)
        startConnectionTimeout()
    }

    fun disconnect() {
        cancelConnectionTimeout()
        cancelReconnect()
        reconnectAttempts = 0
        connector.disconnect()
        commandQueue.clear()
        streamParser.reset()
        transitionTo(ConnectionState.DISCONNECTED)
    }

    /** 所有状态变更通过此方法（ARCH-07）*/
    fun transitionTo(newState: ConnectionState) {
        if (_state == newState) return
        BlueLogger.info("连接状态变更：$_state → $newState")
        _state = newState
        CallbackDispatcher.dispatch { onStateChanged?.invoke(newState) }
    }

    // MARK: - 连接超时

    private fun startConnectionTimeout() {
        cancelConnectionTimeout()
        val runnable = Runnable {
            if (_state == ConnectionState.CONNECTING) {
                BlueLogger.warn("连接超时（${CONNECTION_TIMEOUT_MS}ms），断开连接")
                connector.disconnect()
                commandQueue.clear()
                streamParser.reset()
                transitionTo(ConnectionState.DISCONNECTED)
                CallbackDispatcher.dispatch { onError?.invoke(BlueError.Timeout) }
            }
        }
        connectionTimeoutRunnable = runnable
        handler.postDelayed(runnable, CONNECTION_TIMEOUT_MS)
    }

    private fun cancelConnectionTimeout() {
        connectionTimeoutRunnable?.let { handler.removeCallbacks(it) }
        connectionTimeoutRunnable = null
    }

    // MARK: - 重连

    private fun startReconnect() {
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            BlueLogger.warn("重连次数已达上限，停止重连")
            transitionTo(ConnectionState.DISCONNECTED)
            CallbackDispatcher.dispatch { onReconnectFailed?.invoke() }
            CallbackDispatcher.dispatch { onError?.invoke(BlueError.Disconnected) }
            return
        }
        val delayIndex = minOf(reconnectAttempts, RECONNECT_DELAYS.size - 1)
        val delay = RECONNECT_DELAYS[delayIndex]
        reconnectAttempts++
        BlueLogger.info("第 $reconnectAttempts 次重连，${delay}ms 后尝试")
        transitionTo(ConnectionState.RECONNECTING)
        CallbackDispatcher.dispatch { onReconnecting?.invoke(reconnectAttempts, MAX_RECONNECT_ATTEMPTS) }
        reconnectTimer = Timer()
        reconnectTimer?.schedule(object : TimerTask() {
            override fun run() {
                targetDevice?.let { connector.connect(context, it) }
            }
        }, delay)
    }

    /** 取消正在进行的自动重连 */
    fun cancelReconnection() {
        if (_state == ConnectionState.RECONNECTING) {
            BlueLogger.info("手动取消重连")
            cancelReconnect()
            reconnectAttempts = 0
            transitionTo(ConnectionState.DISCONNECTED)
        }
    }

    private fun cancelReconnect() {
        reconnectTimer?.cancel()
        reconnectTimer = null
    }
}
