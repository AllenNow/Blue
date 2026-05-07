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
import com.blue.sdk.model.AlarmInfo
import com.blue.sdk.transport.CommandCode
import com.blue.sdk.transport.DPIDConstants

/**
 * BlueSDK 主入口，采用单例模式
 * 使用方式：`BlueSDK.getInstance(context).initialize()`
 */
class BlueSDK private constructor(private val context: Context) {

    companion object {
        @Volatile private var instance: BlueSDK? = null

        /** 获取 SDK 单例实例 */
        @JvmStatic
        fun getInstance(context: Context): BlueSDK {
            return instance ?: synchronized(this) {
                instance ?: BlueSDK(context.applicationContext).also { instance = it }
            }
        }
    }

    // MARK: - 内部组件

    @Volatile private var isInitialized = false
    private lateinit var connectionManager: ConnectionManager
    private lateinit var authManager: AuthManager
    private lateinit var deviceManager: DeviceManager
    private lateinit var alarmManager: AlarmManager
    private lateinit var medicationManager: MedicationManager
    private lateinit var audioManager: AudioManager

    /** 事件监听器 */
    @Volatile var listener: BlueSDKListener? = null

    // MARK: - 生命周期（FR32、FR33）

    /**
     * 初始化 SDK（耗时 ≤ 100ms，NFR04）
     * 必须在使用任何其他 API 前调用
     */
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

    /** 销毁 SDK，释放所有 BLE 资源（FR33）*/
    fun destroy() {
        if (!isInitialized) return
        connectionManager.disconnect()
        isInitialized = false
        BlueLogger.info("BlueSDK 已销毁")
    }

    // MARK: - 日志配置（FR34、FR35）

    fun setLogLevel(level: LogLevel) { BlueLogger.logLevel = level }
    fun setLogHandler(handler: BlueLogHandler?) { BlueLogger.logHandler = handler }

    // MARK: - 连接管理（Epic 2）

    /** 查询蓝牙权限状态（FR07）*/
    fun checkPermissions(): PermissionStatus {
        return PermissionManager.checkPermission(context)
    }

    /** 当前连接状态（FR06）*/
    val connectionState: ConnectionState get() = connectionManager.state

    /** 断开连接（FR03）*/
    fun disconnect() {
        if (!requireInitialized { }) return
        connectionManager.disconnect()
    }

    // MARK: - 认证（Epic 3）

    /**
     * 发送密钥包完成设备认证（FR08）
     * @param phoneMac 手机 MAC 地址（6字节）
     * @param deviceMac 设备 MAC 地址（6字节）
     * @param completion 认证结果回调（主线程）
     */
    fun authenticate(
        phoneMac: ByteArray,
        deviceMac: ByteArray,
        completion: (Result<Unit>) -> Unit
    ) {
        if (!requireInitialized(completion)) return
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

    // MARK: - 设备信息与时间同步（Epic 4）

    fun queryDeviceInfo(completion: (Result<com.blue.sdk.model.DeviceInfo>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        deviceManager.queryDeviceInfo(completion)
    }

    fun syncTime(timeMs: Long = System.currentTimeMillis(), completion: (Result<Unit>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        deviceManager.syncTime(timeMs, completion)
    }

    // MARK: - 闹钟管理（Epic 5）

    fun setAlarm(index: Int, hour: Int, minute: Int, weekMask: Int = 0x7F, completion: (Result<AlarmInfo>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        alarmManager.setAlarm(index, hour, minute, weekMask, completion)
    }

    fun deleteAlarm(index: Int, completion: (Result<Unit>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        alarmManager.deleteAlarm(index, completion)
    }

    fun clearAllAlarms(completion: (Result<Unit>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        alarmManager.clearAllAlarms(completion)
    }

    // MARK: - 用药事件（Epic 6）

    fun sendMedicationNotification(status: Byte, completion: (Result<Unit>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        medicationManager.sendMedicationNotification(status, completion)
    }

    // MARK: - 音频与系统设置（Epic 7）

    fun setVolume(level: VolumeLevel, completion: (Result<Unit>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        audioManager.setVolume(level, completion)
    }

    fun setSoundType(type: SoundType, completion: (Result<Unit>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        audioManager.setSoundType(type, completion)
    }

    fun setSilence(enabled: Boolean, completion: (Result<Unit>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        audioManager.setSilence(enabled, completion)
    }

    fun setAlertDuration(minutes: Int, completion: (Result<Unit>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        audioManager.setAlertDuration(minutes, completion)
    }

    fun setTimeFormat(format: TimeFormat, completion: (Result<Unit>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        audioManager.setTimeFormat(format, completion)
    }

    // MARK: - 内部工具

    private fun <T> requireInitialized(completion: (Result<T>) -> Unit): Boolean {
        if (!isInitialized) {
            completion(Result.failure(BlueError.NotInitialized))
            return false
        }
        return true
    }

    private fun requireInitialized(block: () -> Unit): Boolean {
        if (!isInitialized) { block(); return false }
        return true
    }

    private fun <T> requireAuthenticated(completion: (Result<T>) -> Unit): Boolean {
        if (connectionManager.state != ConnectionState.AUTHENTICATED) {
            completion(Result.failure(BlueError.NotAuthenticated))
            return false
        }
        return true
    }

    // MARK: - 连接管理器事件处理

    private fun setupConnectionManager() {
        connectionManager.onStateChanged = { state ->
            listener?.onConnectionStateChanged(state)
        }
        connectionManager.onDataReceived = { frame ->
            handleIncomingFrame(frame)
        }
    }

    private fun handleIncomingFrame(frame: com.blue.sdk.transport.ParsedFrame) {
        val cmdInt = frame.cmd.toInt() and 0xFF
        when {
            cmdInt == (CommandCode.TIME_SYNC.toInt() and 0xFF) -> {
                CallbackDispatcher.dispatch { listener?.onTimeSyncRequested() }
            }
            cmdInt == (CommandCode.DEVICE_REPORT.toInt() and 0xFF) -> {
                handleDeviceReport(frame.data)
            }
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
                // 0x68（alarm3）同时用于用药事件上报，通过 byte9 状态值区分
                val alarm3Int = DPIDConstants.ALARM_3.toInt() and 0xFF
                if (dpidInt == alarm3Int && data.size >= 11) {
                    MedicationManager.parseMedicationEvent(data)?.let { (idx, status) ->
                        CallbackDispatcher.dispatch { listener?.onMedicationResult(idx, status) }
                        return
                    }
                }
                // 普通闹钟配置上报
                AlarmManager.parseAlarmInfo(data, index)?.let { alarm ->
                    CallbackDispatcher.dispatch { listener?.onAlarmUpdated(alarm) }
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
            else -> BlueLogger.debug("未处理的上报 DPID：0x${"%02X".format(dpidInt)}")
        }
    }
}
