// BlueDeviceConnection.kt
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 单设备连接实例：封装一个设备的完整连接生命周期
// 包含独立的 ConnectionManager、AuthManager、CommandQueue 及所有业务 Manager
// 多设备模式下，每个已连接设备对应一个 BlueDeviceConnection 实例

package com.blue.sdk

import android.content.Context
import com.blue.sdk.enums.ConnectionState
import com.blue.sdk.enums.MedicationStatus
import com.blue.sdk.enums.SoundType
import com.blue.sdk.enums.TimeFormat
import com.blue.sdk.enums.VolumeLevel
import com.blue.sdk.error.BlueError
import com.blue.sdk.internal.BlueLogger
import com.blue.sdk.internal.CallbackDispatcher
import com.blue.sdk.manager.AlarmManager
import com.blue.sdk.manager.AudioManager
import com.blue.sdk.manager.AuthManager
import com.blue.sdk.manager.ConnectionManager
import com.blue.sdk.manager.DeviceManager
import com.blue.sdk.manager.MedicationManager
import com.blue.sdk.model.AlarmInfo
import com.blue.sdk.model.DeviceInfo
import com.blue.sdk.model.ScannedDevice
import com.blue.sdk.transport.CommandCode
import com.blue.sdk.transport.DPIDConstants
import com.blue.sdk.transport.FrameBuilder
import com.blue.sdk.transport.ParsedFrame

/**
 * 单设备连接代理 — 将设备事件向上传递给 BlueSDK 多设备管理器
 */
internal interface BlueDeviceConnectionDelegate {
    fun onDeviceStateChanged(connection: BlueDeviceConnection, state: ConnectionState)
    fun onDeviceAuthResult(connection: BlueDeviceConnection, success: Boolean, error: BlueError?)
    fun onDeviceError(connection: BlueDeviceConnection, error: BlueError)
    fun onDeviceReconnecting(connection: BlueDeviceConnection, attempt: Int, maxAttempts: Int)
    fun onDeviceReconnectFailed(connection: BlueDeviceConnection)
    fun onDeviceFrameReceived(connection: BlueDeviceConnection, frame: ParsedFrame)
}

/**
 * 单设备连接实例
 * 封装一个 LX-PD02 设备的完整连接、认证、指令队列及所有业务能力
 */
class BlueDeviceConnection internal constructor(
    private val context: Context,
    /** 设备唯一标识（MAC 地址字符串） */
    val deviceId: String,
    /** 设备广播名称 */
    val deviceName: String,
    private val bluetoothDevice: android.bluetooth.BluetoothDevice,
    internal var config: BlueSDKConfig
) {

    /** 当前连接状态 */
    val connectionState: ConnectionState get() = connectionManager.state

    /** 当前设备时间格式（设备上报后自动更新，默认 24H） */
    @Volatile
    var currentTimeFormat: TimeFormat = TimeFormat.HOUR_24
        internal set

    // 内部组件
    internal val connectionManager = ConnectionManager(context)
    internal val authManager = AuthManager(connectionManager.commandQueue)
    internal val deviceManager = DeviceManager(connectionManager.commandQueue)
    internal val alarmManager = AlarmManager(connectionManager.commandQueue)
    internal val medicationManager = MedicationManager(connectionManager.commandQueue)
    internal val audioManager = AudioManager(connectionManager.commandQueue)

    internal var delegate: BlueDeviceConnectionDelegate? = null
    private var lastTimeSyncMs: Long = 0L

    internal constructor(context: Context, device: ScannedDevice, config: BlueSDKConfig) : this(
        context = context,
        deviceId = device.deviceId,
        deviceName = device.deviceName,
        bluetoothDevice = device.bluetoothDevice,
        config = config
    )

    init {
        setupConnectionManager()
    }

    // MARK: - 连接管理

    /** 发起连接 */
    internal fun connect() {
        connectionManager.connect(bluetoothDevice)
    }

    /** 主动断开 */
    internal fun disconnect() {
        connectionManager.disconnect()
    }

    /** 取消自动重连 */
    fun cancelReconnection() {
        connectionManager.cancelReconnection()
    }

    // MARK: - 认证

    /** 自动认证（连接成功后内部调用） */
    internal fun autoAuthenticate(phoneMacProvider: () -> ByteArray) {
        if (!config.autoAuthEnabled) {
            BlueLogger.debug("[$deviceName] 自动认证已禁用")
            return
        }

        BlueLogger.info("[$deviceName] 连接成功，发起密钥认证...")

        // 固定密钥模式
        val fixedKey = config.fixedAuthKey
        if (fixedKey != null && fixedKey.length == 4) {
            val keyHigh = fixedKey.substring(0, 2).toIntOrNull(16)?.toByte()
            val keyLow = fixedKey.substring(2, 4).toIntOrNull(16)?.toByte()
            if (keyHigh != null && keyLow != null) {
                BlueLogger.debug("[$deviceName] 使用固定密钥认证")
                val keyBytes = byteArrayOf(keyHigh, keyLow)
                val frame = FrameBuilder.build(CommandCode.AUTH_KEY, keyBytes)
                connectionManager.commandQueue.enqueue(CommandCode.AUTH_KEY, frame) { result ->
                    result.fold(
                        onSuccess = { response ->
                            if (response.data.firstOrNull()?.toInt() == 0x01) {
                                connectionManager.transitionTo(ConnectionState.AUTHENTICATED)
                                BlueLogger.info("[$deviceName] 认证成功（固定密钥）")
                                delegate?.onDeviceAuthResult(this, true, null)
                            } else {
                                BlueLogger.error("[$deviceName] 固定密钥认证失败")
                                connectionManager.disconnect()
                                delegate?.onDeviceAuthResult(this, false, BlueError.AuthFailed)
                            }
                        },
                        onFailure = { error ->
                            BlueLogger.error("[$deviceName] 认证指令发送失败：${error.message}")
                        }
                    )
                }
                return
            }
        }

        // 自动计算模式
        val phoneMac = phoneMacProvider()
        val deviceMac = getDeviceMac()
        performAuth(phoneMac, deviceMac)
    }

    /** 手动密钥认证 */
    fun authenticateWithKey(keyHigh: Byte, keyLow: Byte, completion: (Result<Unit>) -> Unit) {
        val keyBytes = byteArrayOf(keyHigh, keyLow)
        val frame = FrameBuilder.build(CommandCode.AUTH_KEY, keyBytes)
        connectionManager.commandQueue.enqueue(CommandCode.AUTH_KEY, frame) { result ->
            result.fold(
                onSuccess = { response ->
                    if (response.data.firstOrNull()?.toInt() == 0x01) {
                        connectionManager.transitionTo(ConnectionState.AUTHENTICATED)
                        completion(Result.success(Unit))
                    } else {
                        connectionManager.disconnect()
                        completion(Result.failure(BlueError.AuthFailed))
                    }
                },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    // MARK: - 业务 API

    /** 查询设备信息 */
    fun queryDeviceInfo(completion: (Result<DeviceInfo>) -> Unit) {
        if (!requireAuth(completion)) return
        deviceManager.queryDeviceInfo(completion)
    }

    /** 时间同步 */
    fun syncTime(timeMs: Long = System.currentTimeMillis(), completion: (Result<Unit>) -> Unit) {
        if (!requireAuth(completion)) return
        deviceManager.syncTime(timeMs, completion)
    }

    /** 设置闹钟 */
    fun setAlarm(index: Int, hour: Int, minute: Int, weekMask: Int = 0x7F, completion: (Result<AlarmInfo>) -> Unit) {
        if (!requireAuth(completion)) return
        alarmManager.setAlarm(index, hour, minute, weekMask, completion)
    }

    /** 查询闹钟 */
    fun queryAlarm(index: Int, completion: (Result<AlarmInfo>) -> Unit) {
        if (!requireAuth(completion)) return
        alarmManager.queryAlarm(index, completion)
    }

    /** 删除闹钟 */
    fun deleteAlarm(index: Int, completion: (Result<Unit>) -> Unit) {
        if (!requireAuth(completion)) return
        alarmManager.deleteAlarm(index, completion)
    }

    /** 清空所有闹钟 */
    fun clearAllAlarms(completion: (Result<Unit>) -> Unit) {
        if (!requireAuth(completion)) return
        alarmManager.clearAllAlarms(completion)
    }

    /** 下发用药结果通知 */
    fun sendMedicationNotification(status: MedicationStatus, completion: (Result<Unit>) -> Unit) {
        if (!requireAuth(completion)) return
        medicationManager.sendMedicationNotification(status.protocolValue.toByte(), completion)
    }

    /** 设置音量 */
    fun setVolume(level: VolumeLevel, completion: (Result<Unit>) -> Unit) {
        if (!requireAuth(completion)) return
        audioManager.setVolume(level, completion)
    }

    /** 设置铃声类型 */
    fun setSoundType(type: SoundType, completion: (Result<Unit>) -> Unit) {
        if (!requireAuth(completion)) return
        audioManager.setSoundType(type, completion)
    }

    /** 设置静音 */
    fun setSilence(enabled: Boolean, completion: (Result<Unit>) -> Unit) {
        if (!requireAuth(completion)) return
        audioManager.setSilence(enabled, completion)
    }

    /** 设置提醒持续时长 */
    fun setAlertDuration(minutes: Int, completion: (Result<Unit>) -> Unit) {
        if (!requireAuth(completion)) return
        audioManager.setAlertDuration(minutes, completion)
    }

    /** 设置时间格式 */
    fun setTimeFormat(format: TimeFormat, completion: (Result<Unit>) -> Unit) {
        if (!requireAuth(completion)) return
        audioManager.setTimeFormat(format, completion)
    }

    /** 恢复出厂设置 */
    fun restoreFactory(completion: (Result<Unit>) -> Unit) {
        if (!requireAuth(completion)) return
        val data = byteArrayOf(DPIDConstants.RESTORE_FACTORY, 0x01, 0x00, 0x01, 0x01)
        val frame = FrameBuilder.build(CommandCode.SEND_COMMAND, data)
        connectionManager.commandQueue.enqueue(CommandCode.SEND_COMMAND, frame) { result ->
            result.fold(
                onSuccess = { completion(Result.success(Unit)) },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    /** 发送原始指令 */
    fun sendRawData(data: ByteArray, completion: (Result<Unit>) -> Unit) {
        if (!requireAuth(completion)) return
        val frame = FrameBuilder.build(CommandCode.SEND_COMMAND, data)
        connectionManager.commandQueue.enqueue(CommandCode.SEND_COMMAND, frame) { result ->
            result.fold(
                onSuccess = { completion(Result.success(Unit)) },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    /** 解绑设备 */
    fun clearBinding(completion: (Result<Unit>) -> Unit) {
        if (connectionState == ConnectionState.AUTHENTICATED || connectionState == ConnectionState.CONNECTED) {
            val frame = FrameBuilder.build(CommandCode.UNBIND)
            connectionManager.commandQueue.enqueue(CommandCode.UNBIND, frame) { result ->
                result.fold(
                    onSuccess = {
                        connectionManager.disconnect()
                        BlueLogger.info("[$deviceName] 解绑成功")
                        completion(Result.success(Unit))
                    },
                    onFailure = { completion(Result.failure(it as BlueError)) }
                )
            }
        } else {
            BlueLogger.info("[$deviceName] 设备未连接，无需解绑")
            completion(Result.success(Unit))
        }
    }

    // MARK: - 内部工具

    private fun <T> requireAuth(completion: (Result<T>) -> Unit): Boolean {
        if (connectionManager.state != ConnectionState.AUTHENTICATED) {
            completion(Result.failure(BlueError.NotAuthenticated))
            return false
        }
        return true
    }

    private fun getDeviceMac(): ByteArray {
        return try {
            deviceId.split(":").map { it.toInt(16).toByte() }.toByteArray()
        } catch (e: Exception) {
            val hash = deviceId.hashCode()
            byteArrayOf(
                (hash shr 24).toByte(), (hash shr 16).toByte(), (hash shr 8).toByte(),
                hash.toByte(), 0x00, 0x01
            )
        }
    }

    private fun performAuth(phoneMac: ByteArray, deviceMac: ByteArray) {
        authManager.authenticate(phoneMac, deviceMac) { result ->
            result.fold(
                onSuccess = {
                    connectionManager.transitionTo(ConnectionState.AUTHENTICATED)
                    BlueLogger.info("[$deviceName] 认证成功")
                    delegate?.onDeviceAuthResult(this, true, null)
                },
                onFailure = { error ->
                    val blueError = error as BlueError
                    BlueLogger.error("[$deviceName] 认证失败：${blueError.message}")
                    if (blueError == BlueError.AuthFailed) {
                        connectionManager.disconnect()
                    }
                    delegate?.onDeviceAuthResult(this, false, blueError)
                }
            )
        }
    }

    // MARK: - ConnectionManager 事件绑定

    private fun setupConnectionManager() {
        connectionManager.onStateChanged = { state ->
            delegate?.onDeviceStateChanged(this, state)
        }
        connectionManager.onError = { error ->
            delegate?.onDeviceError(this, error)
        }
        connectionManager.onReconnecting = { attempt, maxAttempts ->
            delegate?.onDeviceReconnecting(this, attempt, maxAttempts)
        }
        connectionManager.onReconnectFailed = {
            delegate?.onDeviceReconnectFailed(this)
        }
        connectionManager.onDataReceived = { frame ->
            handleIncomingFrame(frame)
        }
    }

    private fun handleIncomingFrame(frame: ParsedFrame) {
        val cmdInt = frame.cmd.toInt() and 0xFF
        // 时间同步请求 — 节流 30 秒
        if (cmdInt == (CommandCode.TIME_SYNC.toInt() and 0xFF)) {
            val now = System.currentTimeMillis()
            if (now - lastTimeSyncMs >= 30000L) {
                lastTimeSyncMs = now
                BlueLogger.info("[$deviceName] 设备请求时间同步，自动下发")
                deviceManager.syncTime { _ -> }
            } else {
                BlueLogger.debug("[$deviceName] 时间同步请求已节流")
            }
        }
        // 转发给上层处理
        delegate?.onDeviceFrameReceived(this, frame)
    }
}
