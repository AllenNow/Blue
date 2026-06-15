// BlueSDK.kt
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// SDK 公开 API 入口（单例）
// 使用方式：BlueSDK.getInstance(context).initialize()

package com.blue.sdk

import android.bluetooth.BluetoothManager
import android.content.Context
import com.blue.sdk.enums.ConnectionState
import com.blue.sdk.enums.LogLevel
import com.blue.sdk.enums.MedicationStatus
import com.blue.sdk.enums.PermissionStatus
import com.blue.sdk.enums.SoundType
import com.blue.sdk.enums.TimeFormat
import com.blue.sdk.enums.VolumeLevel
import com.blue.sdk.error.BlueError
import com.blue.sdk.internal.BlueLogHandler
import com.blue.sdk.internal.BlueLogger
import com.blue.sdk.internal.CallbackDispatcher
import com.blue.sdk.manager.AlarmManager
import com.blue.sdk.manager.AudioManager
import com.blue.sdk.manager.AuthManager
import com.blue.sdk.manager.ConnectionManager
import com.blue.sdk.manager.DeviceManager
import com.blue.sdk.manager.MedicationManager
import com.blue.sdk.manager.PermissionManager
import com.blue.sdk.model.AlarmInfo
import com.blue.sdk.transport.CommandCode
import com.blue.sdk.transport.DPIDConstants
import com.blue.sdk.transport.FrameBuilder

/**
 * BlueSDK 主入口，采用单例模式
 */
class BlueSDK private constructor(private val context: Context) {

    companion object {
        @Volatile private var instance: BlueSDK? = null

        @JvmStatic
        fun getInstance(context: Context): BlueSDK {
            return instance ?: synchronized(this) {
                instance ?: BlueSDK(context.applicationContext).also { instance = it }
            }
        }
    }

    // 内部组件
    @Volatile private var isInitialized = false
    private lateinit var connectionManager: ConnectionManager
    private lateinit var authManager: AuthManager
    private lateinit var deviceManager: DeviceManager
    private lateinit var alarmManager: AlarmManager
    private lateinit var medicationManager: MedicationManager
    private lateinit var audioManager: AudioManager
    private val scanner = com.blue.sdk.transport.BLEScanner()

    @Volatile var listener: BlueSDKListener? = null

    // MARK: - 生命周期

    fun initialize() {
        if (isInitialized) return
        connectionManager = ConnectionManager(context)
        val queue = connectionManager.commandQueue
        authManager       = AuthManager(queue)
        deviceManager     = DeviceManager(queue)
        alarmManager      = AlarmManager(queue)
        medicationManager = MedicationManager(queue)
        audioManager      = AudioManager(queue)
        setupConnectionManager()
        isInitialized = true
        BlueLogger.info("BlueSDK 初始化完成")
    }

    fun destroy() {
        if (!isInitialized) return
        connectionManager.disconnect()
        isInitialized = false
        BlueLogger.info("BlueSDK 已销毁")
    }

    // MARK: - 日志

    fun setLogLevel(level: LogLevel) { BlueLogger.logLevel = level }
    fun setLogHandler(handler: BlueLogHandler?) { BlueLogger.logHandler = handler }

    // MARK: - 连接管理

    fun checkPermissions(): PermissionStatus = PermissionManager.checkPermission(context)

    val connectionState: ConnectionState get() = connectionManager.state

    fun startScan(
        onDeviceFound: (com.blue.sdk.model.ScannedDevice) -> Unit,
        onError: (BlueError) -> Unit
    ) {
        if (!requireInit { }) return
        val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = btManager?.adapter ?: run {
            onError(BlueError.BleError(Exception("BluetoothAdapter unavailable")))
            return
        }
        scanner.startScan(adapter, onDeviceFound, onError)
    }

    fun stopScan() {
        val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        btManager?.adapter?.let { scanner.stopScan(it) }
    }

    fun connect(device: com.blue.sdk.model.ScannedDevice) {
        if (!requireInit { }) return
        val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = btManager?.adapter ?: return
        val peripheral = adapter.getRemoteDevice(device.deviceId) ?: return
        connectionManager.connect(peripheral)
    }

    fun disconnect() {
        if (!requireInit { }) return
        connectionManager.disconnect()
    }

    // MARK: - 认证

    fun authenticate(phoneMac: ByteArray, deviceMac: ByteArray, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion)) return
        authManager.authenticate(phoneMac, deviceMac) { result ->
            result.fold(
                onSuccess = {
                    connectionManager.transitionTo(ConnectionState.AUTHENTICATED)
                    CallbackDispatcher.dispatch { listener?.onAuthResult(true, null) }
                    completion(Result.success(Unit))
                },
                onFailure = { error ->
                    val blueError = error as BlueError
                    if (blueError == BlueError.AuthFailed) {
                        connectionManager.disconnect()
                        CallbackDispatcher.dispatch { listener?.onAuthResult(false, blueError) }
                    }
                    completion(Result.failure(blueError))
                }
            )
        }
    }

    // MARK: - 设备信息与时间同步

    fun queryDeviceInfo(completion: (Result<com.blue.sdk.model.DeviceInfo>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        deviceManager.queryDeviceInfo(completion)
    }

    fun syncTime(timeMs: Long = System.currentTimeMillis(), completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        deviceManager.syncTime(timeMs, completion)
    }

    // MARK: - 闹钟管理

    fun setAlarm(index: Int, hour: Int, minute: Int, weekMask: Int = 0x7F, completion: (Result<AlarmInfo>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        alarmManager.setAlarm(index, hour, minute, weekMask, completion)
    }

    fun deleteAlarm(index: Int, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        alarmManager.deleteAlarm(index, completion)
    }

    fun clearAllAlarms(completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        alarmManager.clearAllAlarms(completion)
    }

    // MARK: - 用药事件

    fun sendMedicationNotification(status: Byte, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        medicationManager.sendMedicationNotification(status, completion)
    }

    // MARK: - 音频与系统设置

    fun setVolume(level: VolumeLevel, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        audioManager.setVolume(level, completion)
    }

    fun setSoundType(type: SoundType, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        audioManager.setSoundType(type, completion)
    }

    fun setSilence(enabled: Boolean, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        audioManager.setSilence(enabled, completion)
    }

    fun setAlertDuration(minutes: Int, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        audioManager.setAlertDuration(minutes, completion)
    }

    fun setTimeFormat(format: TimeFormat, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        audioManager.setTimeFormat(format, completion)
    }

    // MARK: - 系统控制

    fun restoreFactory(completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        val data = byteArrayOf(DPIDConstants.RESTORE_FACTORY, 0x01, 0x00, 0x01, 0x01)
        val frame = FrameBuilder.build(CommandCode.SEND_COMMAND, data)
        connectionManager.commandQueue.enqueue(CommandCode.SEND_COMMAND, frame) { result ->
            result.fold(
                onSuccess = {
                    connectionManager.disconnect()
                    completion(Result.success(Unit))
                },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    // MARK: - 内部工具

    private fun requireInit(block: () -> Unit): Boolean {
        if (!isInitialized) { block(); return false }
        return true
    }

    private fun <T> requireInitR(completion: (Result<T>) -> Unit): Boolean {
        if (!isInitialized) { completion(Result.failure(BlueError.NotInitialized)); return false }
        return true
    }

    private fun <T> requireAuthR(completion: (Result<T>) -> Unit): Boolean {
        if (connectionManager.state != ConnectionState.AUTHENTICATED) {
            completion(Result.failure(BlueError.NotAuthenticated)); return false
        }
        return true
    }

    // MARK: - 事件处理

    private fun setupConnectionManager() {
        connectionManager.onStateChanged = { state ->
            CallbackDispatcher.dispatch { listener?.onConnectionStateChanged(state) }
        }
        connectionManager.onDataReceived = { frame -> handleIncomingFrame(frame) }
    }

    private fun handleIncomingFrame(frame: com.blue.sdk.transport.ParsedFrame) {
        val cmdInt = frame.cmd.toInt() and 0xFF
        when {
            cmdInt == (CommandCode.TIME_SYNC.toInt() and 0xFF) ->
                CallbackDispatcher.dispatch { listener?.onTimeSyncRequested() }
            cmdInt == (CommandCode.DEVICE_REPORT.toInt() and 0xFF) ->
                handleDeviceReport(frame.data)
        }
    }

    private fun handleDeviceReport(data: ByteArray) {
        val dpid = data.firstOrNull() ?: return
        val dpidInt = dpid.toInt() and 0xFF
        val a1 = DPIDConstants.ALARM_1.toInt() and 0xFF
        val a7 = DPIDConstants.ALARM_7.toInt() and 0xFF

        when {
            dpidInt in a1..a7 -> {
                val index = dpidInt - a1 + 1
                val alarm3Int = DPIDConstants.ALARM_3.toInt() and 0xFF
                if (dpidInt == alarm3Int && data.size >= 11) {
                    val statusByte = data[10].toInt() and 0xFF
                    val alarmInfo = AlarmManager.parseAlarmInfo(data, index)
                    if (alarmInfo != null) {
                        when (statusByte) {
                            0x00 -> CallbackDispatcher.dispatch { listener?.onAlarmRinging(index, alarmInfo) }
                            0x01 -> CallbackDispatcher.dispatch { listener?.onAlarmTimeout(index, alarmInfo) }
                            else -> {
                                val status = MedicationStatus.fromByte(data[10])
                                if (status != null) {
                                    CallbackDispatcher.dispatch { listener?.onMedicationResult(index, status) }
                                }
                            }
                        }
                    }
                } else {
                    AlarmManager.parseAlarmInfo(data, index)?.let { alarm ->
                        CallbackDispatcher.dispatch { listener?.onAlarmUpdated(alarm) }
                    }
                }
            }
            dpid == DPIDConstants.ALARM_RECORD -> {
                MedicationManager.parseMedicationRecord(data)?.let { record ->
                    CallbackDispatcher.dispatch { listener?.onMedicationRecordReported(record) }
                }
            }
            dpid == DPIDConstants.TYPE_OF_SOUND -> {
                AudioManager.parseSoundType(data)?.let { type ->
                    CallbackDispatcher.dispatch { listener?.onSoundTypeChanged(type) }
                }
            }
            dpid == DPIDConstants.TIME_FORMAT -> {
                AudioManager.parseTimeFormat(data)?.let { format ->
                    CallbackDispatcher.dispatch { listener?.onTimeFormatChanged(format) }
                }
            }
            dpidInt == (DPIDConstants.LOW_BAT.toInt() and 0xFF) -> {
                CallbackDispatcher.dispatch { listener?.onLowBattery() }
            }
            else -> BlueLogger.debug("未处理的上报 DPID：0x${"%02X".format(dpidInt)}")
        }
    }
}
