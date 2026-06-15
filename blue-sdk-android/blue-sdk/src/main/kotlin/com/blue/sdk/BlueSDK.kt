// BlueSDK.kt
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// SDK 公开 API 入口（单例）
// 使用方式：BlueSDK.getInstance(context).initialize()

package com.blue.sdk

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.Context
import com.blue.sdk.enums.ConnectionState
import com.blue.sdk.manager.PermissionManager
import com.blue.sdk.enums.LogLevel
import com.blue.sdk.enums.PermissionStatus
import com.blue.sdk.enums.SoundType
import com.blue.sdk.enums.TimeFormat
import com.blue.sdk.enums.VolumeLevel
import com.blue.sdk.error.BlueError
import com.blue.sdk.internal.BlueLogHandler
import com.blue.sdk.internal.BlueLogger
import com.blue.sdk.internal.CallbackDispatcher
import com.blue.sdk.internal.KeyStorage
import com.blue.sdk.manager.AlarmManager
import com.blue.sdk.manager.AudioManager
import com.blue.sdk.manager.AuthManager
import com.blue.sdk.manager.ConnectionManager
import com.blue.sdk.manager.DeviceManager
import com.blue.sdk.manager.MedicationManager
import com.blue.sdk.model.AlarmInfo
import com.blue.sdk.model.AlarmConfig
import com.blue.sdk.transport.CommandCode
import com.blue.sdk.transport.DPIDConstants
import com.blue.sdk.transport.FrameBuilder
import java.util.Date

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
    private val scanner = com.blue.sdk.transport.BLEScanner()

    /** 当前连接的目标设备 */
    private var targetDevice: BluetoothDevice? = null

    /** 时间同步节流：上次同步时间戳 */
    private var lastTimeSyncMs: Long = 0L
    private val TIME_SYNC_THROTTLE_MS = 30_000L

    /** 事件监听器 */
    @Volatile var listener: BlueSDKListener? = null

    /** SDK 配置（通过 initialize 时传入） */
    private var config: BlueSDKConfig = BlueSDKConfig()

    // MARK: - 生命周期（FR32、FR33）

    /**
     * 初始化 SDK（耗时 ≤ 100ms，NFR04）
     * 必须在使用任何其他 API 前调用
     * @param config SDK 配置项（可选，默认使用自动密钥模式）
     */
    fun initialize(config: BlueSDKConfig = BlueSDKConfig()) {
        if (isInitialized) return
        this.config = config
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

    /**
     * 开始扫描 LX-PD02 设备（旧版双回调，已废弃）
     * @deprecated 使用 startScan(timeoutMs, callback) 替代
     */
    @Deprecated("使用 startScan(timeoutMs, callback) 替代", ReplaceWith("startScan(callback = { event -> })"))
    fun startScan(
        onDeviceFound: (com.blue.sdk.model.ScannedDevice) -> Unit,
        onError: (BlueError) -> Unit
    ) {
        if (!requireInitialized { }) return
        val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = btManager?.adapter ?: run {
            onError(BlueError.BleError(Exception("BluetoothAdapter unavailable")))
            return
        }
        scanner.startScan(adapter, onDeviceFound, onError)
    }

    /**
     * 开始扫描 LX-PD02 设备（FR01）
     * 使用统一的 ScanEvent 回调模式
     * @param timeoutMs 扫描超时时间（毫秒），0 表示不超时
     * @param callback 扫描事件回调（主线程），包含 DeviceFound / Error / Stopped 三种事件
     */
    fun startScan(
        timeoutMs: Long = 10_000L,
        callback: (com.blue.sdk.model.ScanEvent) -> Unit
    ) {
        if (!requireInitialized { }) return
        val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = btManager?.adapter ?: run {
            callback(com.blue.sdk.model.ScanEvent.Error(BlueError.BleError(Exception("BluetoothAdapter unavailable"))))
            return
        }
        scanner.startScan(adapter,
            { device -> callback(com.blue.sdk.model.ScanEvent.DeviceFound(device)) },
            { error -> callback(com.blue.sdk.model.ScanEvent.Error(error)) }
        )
        // 超时自动停止
        if (timeoutMs > 0) {
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                if (scanner.isScanning) {
                    stopScan()
                    callback(com.blue.sdk.model.ScanEvent.Stopped)
                }
            }, timeoutMs)
        }
    }

    /** 停止扫描（FR01）*/
    fun stopScan() {
        val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        btManager?.adapter?.let { scanner.stopScan(it) }
    }

    /**
     * 连接指定设备（FR02）
     * @param device 由 startScan 回调返回的 ScannedDevice
     */
    fun connect(device: com.blue.sdk.model.ScannedDevice) {
        if (!requireInitialized { }) return
        val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = btManager?.adapter ?: return
        val peripheral = adapter.getRemoteDevice(device.deviceId) ?: return
        targetDevice = peripheral
        connectionManager.connect(peripheral)
    }

    /** 断开连接（FR03）*/
    fun disconnect() {
        if (!requireInitialized { }) return
        connectionManager.disconnect()
    }

    /** 取消正在进行的自动重连 */
    fun cancelReconnection() {
        if (!requireInitialized { }) return
        connectionManager.cancelReconnection()
    }

    // MARK: - 认证（Epic 3）

    /**
     * 发送密钥包完成设备认证（FR08）— 内部使用
     * @param phoneMac 手机 MAC 地址（6字节）
     * @param deviceMac 设备 MAC 地址（6字节）
     * @param completion 认证结果回调（主线程）
     */
    internal fun authenticate(
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

    /**
     * 使用指定密钥直接认证（对齐 iOS authenticateWithKey）
     * @param keyHigh 密钥高字节
     * @param keyLow 密钥低字节
     * @param completion 认证结果回调（主线程）
     */
    fun authenticateWithKey(keyHigh: Byte, keyLow: Byte, completion: (Result<Unit>) -> Unit) {
        if (!requireInitialized(completion)) return
        val keyBytes = byteArrayOf(keyHigh, keyLow)
        BlueLogger.debug("发送指定密钥认证（密钥值已脱敏）")
        val frame = FrameBuilder.build(CommandCode.AUTH_KEY, keyBytes)
        connectionManager.commandQueue.enqueue(CommandCode.AUTH_KEY, frame) { result ->
            result.fold(
                onSuccess = { response ->
                    val success = response.data.firstOrNull()?.toInt() == 0x01
                    if (success) {
                        connectionManager.transitionTo(ConnectionState.AUTHENTICATED)
                        CallbackDispatcher.dispatch { listener?.onAuthResult(true, null) }
                        completion(Result.success(Unit))
                    } else {
                        val err = BlueError.AuthFailed
                        CallbackDispatcher.dispatch { listener?.onAuthResult(false, err) }
                        completion(Result.failure(err))
                    }
                },
                onFailure = { error ->
                    val blueError = error as BlueError
                    CallbackDispatcher.dispatch { listener?.onAuthResult(false, blueError) }
                    completion(Result.failure(blueError))
                }
            )
        }
    }

    /**
     * 清除本地绑定（删除 SharedPreferences 中的 phoneMac）
     * 对应 iOS 版本的 clearBinding()
     * @param completion 操作完成回调（默认空回调，向后兼容）
     */
    fun clearBinding(completion: (Result<Unit>) -> Unit = {}) {
        KeyStorage.clear(context)
        BlueLogger.info("已清除本地绑定")
        completion(Result.success(Unit))
    }

    /**
     * 恢复出厂设置（发送 0x76 0x01 0x00 0x01 0x01 通过 CMD=0x06）
     * @param completion 操作结果回调
     */
    fun restoreFactory(completion: (Result<Unit>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        val data = byteArrayOf(0x76, 0x01, 0x00, 0x01, 0x01)
        val frame = FrameBuilder.build(CommandCode.SEND_COMMAND, data)
        connectionManager.commandQueue.enqueue(CommandCode.SEND_COMMAND, frame) { result ->
            result.fold(
                onSuccess = { completion(Result.success(Unit)) },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    // MARK: - 设备信息与时间同步（Epic 4）

    fun queryDeviceInfo(completion: (Result<com.blue.sdk.model.DeviceInfo>) -> Unit) {
        if (!requireInitialized(completion)) return
        deviceManager.queryDeviceInfo(completion)
    }

    fun syncTime(date: Date = Date(), completion: (Result<Unit>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        deviceManager.syncTime(date.time, completion)
    }

    // MARK: - 闹钟管理（Epic 5）

    @Deprecated("使用 setAlarm(index, hour, minute, days) 替代", ReplaceWith("setAlarm(index, hour, minute, WeekDay.fromMask(weekMask).toSet(), completion)"))
    fun setAlarm(index: Int, hour: Int, minute: Int, weekMask: Int = 0x7F, completion: (Result<AlarmInfo>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        alarmManager.setAlarm(index, hour, minute, weekMask, completion)
    }

    /**
     * 设置闹钟（类型安全版本）
     * @param index 闹钟槽位（1~7）
     * @param hour 小时（0~23）
     * @param minute 分钟（0~59）
     * @param days 重复星期，默认每天
     * @param completion 结果回调
     */
    fun setAlarm(index: Int, hour: Int, minute: Int, days: Set<com.blue.sdk.enums.WeekDay>, completion: (Result<AlarmInfo>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        alarmManager.setAlarm(index, hour, minute, com.blue.sdk.enums.WeekDay.toMask(days), completion)
    }

    fun deleteAlarm(index: Int, completion: (Result<Unit>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        alarmManager.deleteAlarm(index, completion)
    }

    fun clearAllAlarms(completion: (Result<Unit>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        alarmManager.clearAllAlarms(completion)
    }

    /**
     * 批量设置闹钟（便利方法）
     * 内部串行发送，全部成功后回调 success，任一失败即回调 failure
     * @param alarms 闹钟配置列表
     * @param completion 全部完成后回调，成功返回设置好的 AlarmInfo 列表
     */
    fun setAlarms(alarms: List<AlarmConfig>, completion: (Result<List<AlarmInfo>>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        if (alarms.isEmpty()) { completion(Result.success(emptyList())); return }
        val results = mutableListOf<AlarmInfo>()
        fun setNext(index: Int) {
            if (index >= alarms.size) {
                completion(Result.success(results))
                return
            }
            val alarm = alarms[index]
            alarmManager.setAlarm(alarm.index, alarm.hour, alarm.minute, alarm.resolvedWeekMask()) { result ->
                result.fold(
                    onSuccess = { info ->
                        results.add(info)
                        setNext(index + 1)
                    },
                    onFailure = { completion(Result.failure(it as BlueError)) }
                )
            }
        }
        setNext(0)
    }

    // MARK: - 用药事件（Epic 6）

    fun sendMedicationNotification(status: com.blue.sdk.enums.MedicationStatus, completion: (Result<Unit>) -> Unit) {
        if (!requireInitialized(completion) || !requireAuthenticated(completion)) return
        medicationManager.sendMedicationNotification(status.protocolValue.toByte(), completion)
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

    // MARK: - 自动认证（对齐 iOS）

    /**
     * 固定密钥（4字符十六进制字符串如 "05FA"）。
     * 推荐通过 BlueSDKConfig 初始化时设置。运行时修改此值是线程安全的。
     */
    @Volatile var fixedAuthKey: String?
        get() = config.fixedAuthKey
        set(value) { config = config.copy(fixedAuthKey = value) }

    /**
     * 连接成功后自动认证
     * 如果设置了 fixedAuthKey 则直接使用，否则用 phoneMac + deviceMac 自动计算
     */
    private fun autoAuthenticate() {
        if (!config.autoAuthEnabled) {
            BlueLogger.debug("自动认证已禁用（config.autoAuthEnabled=false）")
            return
        }
        val fixedKey = config.fixedAuthKey
        if (fixedKey != null && fixedKey.length == 4) {
            // 固定密钥模式
            val keyHigh = fixedKey.substring(0, 2).toInt(16).toByte()
            val keyLow = fixedKey.substring(2, 4).toInt(16).toByte()
            val keyBytes = byteArrayOf(keyHigh, keyLow)
            BlueLogger.debug("使用固定密钥 $fixedKey 认证")
            val frame = FrameBuilder.build(CommandCode.AUTH_KEY, keyBytes)
            connectionManager.commandQueue.enqueue(CommandCode.AUTH_KEY, frame) { result ->
                result.fold(
                    onSuccess = { response ->
                        val success = response.data.firstOrNull()?.toInt() == 0x01
                        if (success) {
                            connectionManager.transitionTo(ConnectionState.AUTHENTICATED)
                            BlueLogger.info("认证成功（固定密钥）")
                            CallbackDispatcher.dispatch { listener?.onAuthResult(true, null) }
                        } else {
                            BlueLogger.error("固定密钥认证失败")
                            connectionManager.disconnect()
                            CallbackDispatcher.dispatch { listener?.onAuthResult(false, BlueError.AuthFailed) }
                        }
                    },
                    onFailure = { error ->
                        val blueError = error as BlueError
                        CallbackDispatcher.dispatch { listener?.onAuthResult(false, blueError) }
                    }
                )
            }
        } else {
            // 自动计算模式
            val phoneMac = KeyStorage.getOrCreatePhoneMac(context)
            val deviceMacStr = targetDevice?.address ?: return
            val deviceMac = macStringToBytes(deviceMacStr)
            BlueLogger.info("自动认证：phoneMac=${bytesToHex(phoneMac)}, deviceMac=$deviceMacStr")
            authManager.authenticate(phoneMac, deviceMac) { result ->
                result.fold(
                    onSuccess = {
                        connectionManager.transitionTo(ConnectionState.AUTHENTICATED)
                        BlueLogger.info("自动认证成功")
                        CallbackDispatcher.dispatch { listener?.onAuthResult(true, null) }
                    },
                    onFailure = { error ->
                        val blueError = error as BlueError
                        if (blueError == BlueError.AuthFailed) {
                            connectionManager.disconnect()
                        }
                        CallbackDispatcher.dispatch { listener?.onAuthResult(false, blueError) }
                    }
                )
            }
        }
    }

    /**
     * 自动时间同步响应（30秒节流）
     */
    private fun autoSyncTime() {
        val now = System.currentTimeMillis()
        if (now - lastTimeSyncMs < TIME_SYNC_THROTTLE_MS) {
            BlueLogger.debug("时间同步节流：距上次同步不足30秒，跳过")
            return
        }
        lastTimeSyncMs = now
        if (connectionManager.state == ConnectionState.AUTHENTICATED) {
            deviceManager.syncTime(now) { result ->
                result.fold(
                    onSuccess = { BlueLogger.info("自动时间同步完成") },
                    onFailure = { BlueLogger.warn("自动时间同步失败：${it.message}") }
                )
            }
        }
    }

    /** MAC 字符串（"AA:BB:CC:DD:EE:FF"）转 6 字节数组 */
    private fun macStringToBytes(mac: String): ByteArray {
        return mac.split(":").map { it.toInt(16).toByte() }.toByteArray()
    }

    private fun bytesToHex(bytes: ByteArray): String {
        return bytes.joinToString(":") { "%02X".format(it) }
    }

    // MARK: - 连接管理器事件处理

    private fun setupConnectionManager() {
        connectionManager.onStateChanged = { state ->
            CallbackDispatcher.dispatch { listener?.onConnectionStateChanged(state) }
            // 连接成功后自动认证
            if (state == ConnectionState.CONNECTED) {
                // 延迟 500ms 再认证，等设备初始 AT 垃圾数据吐完
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    autoAuthenticate()
                }, 500)
            }
        }
        connectionManager.onError = { error ->
            BlueLogger.error("连接错误：${error.message}")
            CallbackDispatcher.dispatch { listener?.onError(error) }
        }
        connectionManager.onReconnecting = { attempt, max ->
            CallbackDispatcher.dispatch { listener?.onReconnecting(attempt, max) }
        }
        connectionManager.onReconnectFailed = {
            CallbackDispatcher.dispatch { listener?.onReconnectFailed() }
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
                // 自动响应时间同步（30秒节流）
                autoSyncTime()
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
                val alarm3Int = DPIDConstants.ALARM_3.toInt() and 0xFF
                if (dpidInt == alarm3Int && data.size >= 11) {
                    val statusByte = data[10].toInt() and 0xFF
                    val alarmInfo = AlarmManager.parseAlarmInfo(data, index)
                    if (alarmInfo != null) {
                        when (statusByte) {
                            0x00 -> CallbackDispatcher.dispatch { listener?.onAlarmRinging(index, alarmInfo) }
                            0x01 -> CallbackDispatcher.dispatch { listener?.onAlarmTimeout(index, alarmInfo) }
                            else -> {
                                val status = com.blue.sdk.enums.MedicationStatus.fromByte(data[10])
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
            dpid == DPIDConstants.LOW_BAT -> {
                BlueLogger.info("设备上报低电状态")
                CallbackDispatcher.dispatch { listener?.onLowBattery() }
            }
            else -> BlueLogger.debug("未处理的上报 DPID：0x${"%02X".format(dpidInt)}")
        }
    }
}
