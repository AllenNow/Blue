// ConnectionManager.kt
// BlueSDK - 连接状态机（ARCH-07）

package com.blue.sdk.manager

import android.bluetooth.BluetoothDevice
import android.content.Context
import com.blue.sdk.enums.ConnectionState
import com.blue.sdk.error.BlueError
import com.blue.sdk.internal.BlueLogger
import com.blue.sdk.internal.CallbackDispatcher
import com.blue.sdk.internal.CommandQueue
import com.blue.sdk.transport.BLEConnector
import com.blue.sdk.transport.BLEConnectorDelegate
import com.blue.sdk.transport.CommandCode
import com.blue.sdk.transport.FrameParser
import java.util.Timer
import java.util.TimerTask

internal class ConnectionManager(private val context: Context) {

    companion object {
        private val RECONNECT_DELAYS = longArrayOf(2000L, 4000L, 8000L)
        private const val MAX_RECONNECT_ATTEMPTS = 5
    }

    private val connector = BLEConnector()
    val commandQueue = CommandQueue()

    @Volatile private var _state: ConnectionState = ConnectionState.DISCONNECTED
    val state: ConnectionState get() = _state

    private var targetDevice: BluetoothDevice? = null
    private var reconnectAttempts = 0
    private var reconnectTimer: Timer? = null

    var onStateChanged: ((ConnectionState) -> Unit)? = null
    var onError: ((BlueError) -> Unit)? = null
    var onDataReceived: ((com.blue.sdk.transport.ParsedFrame) -> Unit)? = null

    init {
        connector.delegate = object : BLEConnectorDelegate {
            override fun onConnected() {
                reconnectAttempts = 0
                cancelReconnect()
                transitionTo(ConnectionState.CONNECTED)
            }
            override fun onDisconnected(error: Exception?) {
                commandQueue.clear()
                if (_state == ConnectionState.DISCONNECTED) return
                if (error != null) startReconnect()
                else transitionTo(ConnectionState.DISCONNECTED)
            }
            override fun onDataReceived(data: ByteArray) {
                val frame = FrameParser.parse(data) ?: run {
                    BlueLogger.warn("帧解析失败，已丢弃")
                    return
                }
                val cmdInt = frame.cmd.toInt() and 0xFF
                if (cmdInt == (CommandCode.DEVICE_REPORT.toInt() and 0xFF) ||
                    cmdInt == (CommandCode.TIME_SYNC.toInt() and 0xFF)) {
                    onDataReceived?.invoke(frame)
                    return
                }
                if (!commandQueue.handleResponse(frame)) {
                    onDataReceived?.invoke(frame)
                }
            }
        }
        commandQueue.sendBlock = { bytes -> connector.write(bytes) }
    }

    fun connect(device: BluetoothDevice) {
        if (_state != ConnectionState.DISCONNECTED) return
        targetDevice = device
        transitionTo(ConnectionState.CONNECTING)
        connector.connect(context, device)
    }

    fun disconnect() {
        cancelReconnect()
        reconnectAttempts = 0
        connector.disconnect()
        commandQueue.clear()
        transitionTo(ConnectionState.DISCONNECTED)
    }

    /** 所有状态变更通过此方法（ARCH-07）*/
    fun transitionTo(newState: ConnectionState) {
        if (_state == newState) return
        BlueLogger.info("连接状态变更：$_state → $newState")
        _state = newState
        CallbackDispatcher.dispatch { onStateChanged?.invoke(newState) }
    }

    private fun startReconnect() {
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            BlueLogger.warn("重连次数已达上限，停止重连")
            transitionTo(ConnectionState.DISCONNECTED)
            CallbackDispatcher.dispatch { onError?.invoke(BlueError.Disconnected) }
            return
        }
        val delayIndex = minOf(reconnectAttempts, RECONNECT_DELAYS.size - 1)
        val delay = RECONNECT_DELAYS[delayIndex]
        reconnectAttempts++
        BlueLogger.info("第 $reconnectAttempts 次重连，${delay}ms 后尝试")
        transitionTo(ConnectionState.RECONNECTING)
        reconnectTimer = Timer()
        reconnectTimer?.schedule(object : TimerTask() {
            override fun run() {
                targetDevice?.let { connector.connect(context, it) }
            }
        }, delay)
    }

    private fun cancelReconnect() {
        reconnectTimer?.cancel()
        reconnectTimer = null
    }
}
