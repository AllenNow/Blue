// BlueSDK.kt
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// SDK 公开 API 入口（单例）
// 使用方式：BlueSDK.getInstance(context).initialize()
// 连接成功后自动完成密钥认证（phoneMac 持久化存储在 KeystoreHelper）

package com.blue.sdk

import android.bluetooth.BluetoothManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.blue.sdk.enums.ConnectionState
import com.blue.sdk.enums.LogLevel
import com.blue.sdk.enums.MedicationStatus
import com.blue.sdk.enums.PermissionStatus
import com.blue.sdk.enums.SoundType
import com.blue.sdk.enums.TimeFormat
import com.blue.sdk.enums.VolumeLevel
import com.blue.sdk.enums.WeekDays
import com.blue.sdk.error.BlueError
import com.blue.sdk.internal.BlueLogHandler
import com.blue.sdk.internal.BlueLogger
import com.blue.sdk.internal.CallbackDispatcher
import com.blue.sdk.internal.KeystoreHelper
import com.blue.sdk.internal.SDKLocale
import com.blue.sdk.manager.AlarmManager
import com.blue.sdk.manager.AudioManager
import com.blue.sdk.manager.AuthManager
import com.blue.sdk.manager.ConnectionManager
import com.blue.sdk.manager.DeviceManager
import com.blue.sdk.manager.MedicationManager
import com.blue.sdk.manager.PermissionManager
import com.blue.sdk.model.AlarmConfig
import com.blue.sdk.model.AlarmInfo
import com.blue.sdk.model.ScanEvent
import com.blue.sdk.model.ScannedDevice
import com.blue.sdk.transport.CommandCode
import com.blue.sdk.transport.DPIDConstants
import com.blue.sdk.transport.FrameBuilder
import java.util.UUID

/**
 * BlueSDK 主入口，采用单例模式
 */
class BlueSDK private constructor(private val context: Context) {

    companion object {
        @Volatile private var instance: BlueSDK? = null
        private const val KEYSTORE_PHONE_MAC_KEY = "com.blue.sdk.phoneMac"

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
    private val handler = Handler(Looper.getMainLooper())

    // 自动认证状态
    private var connectedDevice: ScannedDevice? = null
    private var lastTimeSyncMs: Long = 0L

    /** SDK 配置（运行时可修改 customPhoneMac 等字段） */
    @Volatile var config: BlueSDKConfig = BlueSDKConfig()

    /**
     * 固定密钥（2字节十六进制字符串，如 "05FA"）。
     * 推荐通过 BlueSDKConfig 初始化时设置。运行时修改此值是线程安全的。
     */
    var fixedAuthKey: String?
        get() = config.fixedAuthKey
        set(value) {
            config = config.copy(fixedAuthKey = value)
        }

    @Volatile var listener: BlueSDKListener? = null

    /** 多播观察者列表 — 支持多个地方同时监听事件 */
    private val observers = mutableListOf<BlueSDKListener>()

    /** 添加事件观察者 */
    fun addObserver(observer: BlueSDKListener) {
        synchronized(observers) { if (!observers.contains(observer)) observers.add(observer) }
    }

    /** 移除事件观察者 */
    fun removeObserver(observer: BlueSDKListener) {
        synchronized(observers) { observers.remove(observer) }
    }

    /** 通知所有观察者（含主 listener，自动去重） */
    private fun notifyObservers(block: (BlueSDKListener) -> Unit) {
        val main = listener
        main?.let { block(it) }
        synchronized(observers) { observers.toList() }.forEach {
            if (it !== main) block(it)  // 避免 listener 同时在 observers 中导致重复回调
        }
    }

    // MARK: - 生命周期（FR32、FR33）

    /**
     * 初始化 SDK
     * @param config SDK 配置项（可选，默认使用自动密钥模式）
     */
    fun initialize(config: BlueSDKConfig = BlueSDKConfig()) {
        if (isInitialized) return
        this.config = config
        KeystoreHelper.init(context)
        connectionManager = ConnectionManager(context)
        val queue = connectionManager.commandQueue
        authManager       = AuthManager(queue)
        deviceManager     = DeviceManager(queue)
        alarmManager      = AlarmManager(queue)
        medicationManager = MedicationManager(queue)
        audioManager      = AudioManager(queue)
        setupConnectionManager()
        BlueLogger.logLevel = config.logLevel
        SDKLocale.setLanguage(config.language)
        isInitialized = true
        BlueLogger.info("BlueSDK 初始化完成")
    }

    /** 销毁 SDK，释放所有 BLE 资源（FR33）*/
    fun destroy() {
        if (!isInitialized) return
        connectionManager.disconnect()
        connectedDevice = null
        lastTimeSyncMs = 0L
        isInitialized = false
        BlueLogger.info("BlueSDK 已销毁")
    }

    // MARK: - 日志配置（FR34、FR35）

    fun setLogLevel(level: LogLevel) { BlueLogger.logLevel = level }
    fun setLogHandler(handler: BlueLogHandler?) { BlueLogger.logHandler = handler }

    /** 运行时切换 SDK 语言（影响错误描述和恢复建议） */
    fun setLanguage(language: BlueSDKLanguage) { SDKLocale.setLanguage(language) }

    /** 查询当前 SDK 是否使用中文 */
    val isZh: Boolean get() = SDKLocale.isZh

    /**
     * 导出 SDK 运行日志（Story 10.4）
     * 最近 1000 条日志，含时间戳、级别、标签，密钥已脱敏
     * @param maxLines 最大导出行数，null 表示全部
     * @return 日志文本
     */
    fun exportLog(maxLines: Int? = null): String = BlueLogger.exportLog(maxLines)

    /** 清空日志缓冲区 */
    fun clearLogBuffer() { BlueLogger.clearLogBuffer() }

    // MARK: - 连接管理（Epic 2）

    /** 查询蓝牙权限状态（FR07）*/
    fun checkPermissions(): PermissionStatus = PermissionManager.checkPermission(context)

    /** 当前连接状态（FR06）*/
    val connectionState: ConnectionState get() = connectionManager.state

    /** 当前设备时间格式（设备上报后自动更新，默认 24H）
     *  App 界面展示时间时应跟随此值选择 12/24 小时制 */
    @Volatile var currentTimeFormat: TimeFormat = TimeFormat.HOUR_24
        private set

    /**
     * 开始扫描 LX-PD02 设备（FR01）
     * 使用统一的 ScanEvent 回调模式
     * @param timeoutMs 扫描超时时间（毫秒），0 表示不超时。默认 10000ms
     * @param callback 扫描事件回调（主线程），包含 DeviceFound / Error / Stopped 三种事件
     */
    fun startScan(
        timeoutMs: Long = 10000L,
        callback: (ScanEvent) -> Unit
    ) {
        if (!requireInit { }) { callback(ScanEvent.Error(BlueError.NotInitialized)); return }
        val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = btManager?.adapter ?: run {
            callback(ScanEvent.Error(BlueError.BleError(Exception("BluetoothAdapter unavailable"))))
            return
        }
        scanner.startScan(
            adapter,
            onDeviceFound = { device -> callback(ScanEvent.DeviceFound(device)) },
            onError = { error -> callback(ScanEvent.Error(error)) }
        )
        // 超时自动停止
        if (timeoutMs > 0) {
            handler.postDelayed({
                if (scanner.isScanning) {
                    stopScan()
                    callback(ScanEvent.Stopped)
                }
            }, timeoutMs)
        }
    }

    /** 停止扫描（FR01）*/
    fun stopScan() {
        val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        btManager?.adapter?.let { scanner.stopScan(it) }
    }

    /** 连接指定设备（FR02）连接成功后 SDK 内部自动完成密钥认证 */
    fun connect(device: ScannedDevice) {
        if (!requireInit { }) return
        connectedDevice = device
        connectionManager.connect(device.bluetoothDevice)
    }

    /**
     * 解绑设备
     * 向设备发送解绑指令（CMD=0xA1），成功应答后清除本地密钥并断开连接
     */
    fun clearBinding(completion: (Result<Unit>) -> Unit = {}) {
        if (!isInitialized) {
            completion(Result.failure(BlueError.NotInitialized))
            return
        }
        // 已连接时发送解绑指令
        if (connectionManager.state == ConnectionState.AUTHENTICATED || connectionManager.state == ConnectionState.CONNECTED) {
            val frame = FrameBuilder.build(CommandCode.UNBIND)
            connectionManager.commandQueue.enqueue(CommandCode.UNBIND, frame) { result ->
                result.fold(
                    onSuccess = {
                        // 设备应答成功，断开连接
                        connectedDevice = null
                        connectionManager.disconnect()
                        BlueLogger.info("解绑成功，连接已断开")
                        completion(Result.success(Unit))
                    },
                    onFailure = { error ->
                        BlueLogger.error("解绑指令失败：${(error as BlueError).message}")
                        completion(Result.failure(error))
                    }
                )
            }
        } else {
            connectedDevice = null
            BlueLogger.info("设备未连接，解绑完成")
            completion(Result.success(Unit))
        }
    }

    /**
     * 获取当前本地认证密钥的十六进制字符串
     * 如果设置了 fixedAuthKey 返回固定密钥；否则返回自动生成的 phoneMac
     * 用于界面展示当前使用的认证密钥
     */
    val currentAuthKeyDisplay: String get() {
        val fixed = config.fixedAuthKey
        if (fixed != null && fixed.length == 4) return "Fixed: $fixed"
        val custom = config.customPhoneMac
        if (custom != null && custom.length == 12) {
            return custom.chunked(2).joinToString(":")
        }
        val phoneMac = getOrCreatePhoneMac()
        return phoneMac.joinToString(":") { b -> "%02X".format(b) }
    }

    /** 断开连接（FR03）*/
    fun disconnect() {
        if (!requireInit { }) return
        connectedDevice = null
        connectionManager.disconnect()
    }

    /** 发送原始指令数据（调试用）*/
    fun sendRawData(data: ByteArray, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        val frame = FrameBuilder.build(CommandCode.SEND_COMMAND, data)
        connectionManager.commandQueue.enqueue(CommandCode.SEND_COMMAND, frame) { result ->
            result.fold(
                onSuccess = { completion(Result.success(Unit)) },
                onFailure = { completion(Result.failure(it as BlueError)) }
            )
        }
    }

    /** 取消正在进行的自动重连 */
    fun cancelReconnection() {
        connectionManager.cancelReconnection()
    }

    // MARK: - 认证（Epic 3）

    /**
     * 使用指定密钥值直接认证（用于恢复已绑定设备）
     */
    fun authenticateWithKey(
        keyHigh: Byte,
        keyLow: Byte,
        completion: (Result<Unit>) -> Unit
    ) {
        if (!requireInitR(completion)) return
        val keyBytes = byteArrayOf(keyHigh, keyLow)
        BlueLogger.info("手动密钥认证：key=${"%02X%02X".format(keyHigh, keyLow)}")
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

    /**
     * 发送密钥包完成设备认证（FR08）
     * SDK 内置自动认证，如需指定密钥请使用 BlueSDKConfig.fixedAuthKey 或 authenticateWithKey()
     */
    fun authenticate(phoneMac: ByteArray, deviceMac: ByteArray, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion)) return
        performAuth(phoneMac, deviceMac, completion)
    }

    // MARK: - 设备信息与时间同步（Epic 4）

    /**
     * 查询设备信息（FR12）
     * 注意：此方法可在认证前调用（用于获取设备 MAC 计算密钥）
     */
    fun queryDeviceInfo(completion: (Result<com.blue.sdk.model.DeviceInfo>) -> Unit) {
        if (!requireInitR(completion) || !requireConnectedR(completion)) return
        deviceManager.queryDeviceInfo(completion)
    }

    /** 下发当前系统时间（FR14）*/
    fun syncTime(timeMs: Long = System.currentTimeMillis(), completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        deviceManager.syncTime(timeMs, completion)
    }

    // MARK: - 闹钟管理（Epic 5）

    /**
     * 设置闹钟（FR15）— 类型安全版本
     * @param index 闹钟槽位（1~7）
     * @param hour 小时（0~23）
     * @param minute 分钟（0~59）
     * @param days 重复星期，默认每天
     * @param completion 结果回调
     */
    fun setAlarm(index: Int, hour: Int, minute: Int, days: WeekDays = WeekDays.ALL, completion: (Result<AlarmInfo>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        alarmManager.setAlarm(index, hour, minute, days.rawValue, completion)
    }

    /**
     * 设置闹钟（FR15）— weekMask 版本
     * @param index 闹钟槽位（1~7）
     * @param hour 小时（0~23）
     * @param minute 分钟（0~59）
     * @param weekMask 星期掩码（bit0=周一...bit6=周日，0x7F=每天）
     * @param completion 结果回调
     */
    fun setAlarm(index: Int, hour: Int, minute: Int, weekMask: Int, completion: (Result<AlarmInfo>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        alarmManager.setAlarm(index, hour, minute, weekMask, completion)
    }

    /** 查询闹钟（FR15）*/
    fun queryAlarm(index: Int, completion: (Result<AlarmInfo>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        alarmManager.queryAlarm(index, completion)
    }

    /** 删除闹钟（FR16）*/
    fun deleteAlarm(index: Int, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        alarmManager.deleteAlarm(index, completion)
    }

    /** 清空所有闹钟（FR17）*/
    fun clearAllAlarms(completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        alarmManager.clearAllAlarms(completion)
    }

    /**
     * 批量设置闹钟（便利方法）
     * 内部串行发送，全部成功后回调 success，任一失败即回调 failure
     * @param alarms 闹钟配置列表
     * @param completion 全部完成后回调，成功返回设置好的 AlarmInfo 列表
     */
    fun setAlarms(alarms: List<AlarmConfig>, completion: (Result<List<AlarmInfo>>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        if (alarms.isEmpty()) { completion(Result.success(emptyList())); return }

        val results = mutableListOf<AlarmInfo>()
        fun setNext(index: Int) {
            if (index >= alarms.size) {
                completion(Result.success(results.toList()))
                return
            }
            val alarm = alarms[index]
            alarmManager.setAlarm(alarm.index, alarm.hour, alarm.minute, alarm.weekMask) { result ->
                result.fold(
                    onSuccess = { info ->
                        results.add(info)
                        setNext(index + 1)
                    },
                    onFailure = { completion(Result.failure(it)) }
                )
            }
        }
        setNext(0)
    }

    // MARK: - 用药事件（Epic 6）

    /** 下发用药结果通知（FR24）*/
    fun sendMedicationNotification(status: MedicationStatus, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        medicationManager.sendMedicationNotification(status.protocolValue.toByte(), completion)
    }

    // MARK: - 音频与系统设置（Epic 7）

    /** 设置音量（FR25）*/
    fun setVolume(level: VolumeLevel, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        audioManager.setVolume(level, completion)
    }

    /** 设置铃声类型（FR26）*/
    fun setSoundType(type: SoundType, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        audioManager.setSoundType(type, completion)
    }

    /** 设置静音（FR28）*/
    fun setSilence(enabled: Boolean, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        audioManager.setSilence(enabled, completion)
    }

    /** 设置提醒持续时长（FR29）*/
    fun setAlertDuration(minutes: Int, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        audioManager.setAlertDuration(minutes, completion)
    }

    /** 设置时间格式（FR30）*/
    fun setTimeFormat(format: TimeFormat, completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        audioManager.setTimeFormat(format, completion)
    }

    // MARK: - 系统控制（Epic 9）

    /**
     * 恢复出厂设置（Story 9.1）
     * 注意：恢复后 SDK 会自动断开连接并重置内部状态
     */
    fun restoreFactory(completion: (Result<Unit>) -> Unit) {
        if (!requireInitR(completion) || !requireAuthR(completion)) return
        val data = byteArrayOf(DPIDConstants.RESTORE_FACTORY, 0x01, 0x00, 0x01, 0x01)
        val frame = FrameBuilder.build(CommandCode.SEND_COMMAND, data)
        connectionManager.commandQueue.enqueue(CommandCode.SEND_COMMAND, frame) { result ->
            result.fold(
                onSuccess = {
                    BlueLogger.info("恢复出厂成功，设备已确认")
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

    private fun <T> requireConnectedR(completion: (Result<T>) -> Unit): Boolean {
        val s = connectionManager.state
        if (s == ConnectionState.DISCONNECTED || s == ConnectionState.CONNECTING) {
            completion(Result.failure(BlueError.Disconnected)); return false
        }
        return true
    }

    // MARK: - 自动认证逻辑

    /**
     * 获取或生成 phoneMac（6字节）
     * 优先级：config.customPhoneMac > ANDROID_ID 确定性生成
     */
    private fun getOrCreatePhoneMac(): ByteArray {
        // 1. 集成方自定义 phoneMac
        val custom = config.customPhoneMac
        if (custom != null && custom.length == 12) {
            val bytes = custom.chunked(2).mapNotNull { it.toIntOrNull(16)?.toByte() }.toByteArray()
            if (bytes.size == 6) return bytes
        }

        // 2. 基于 ANDROID_ID 确定性生成
        val androidId = android.provider.Settings.Secure.getString(
            context.contentResolver,
            android.provider.Settings.Secure.ANDROID_ID
        ) ?: "0000000000000000"

        val digest = java.security.MessageDigest.getInstance("SHA-256")
        digest.update("BlueSDK_phoneMac_$androidId".toByteArray())
        val hash = digest.digest()
        return hash.copyOf(6)
    }

    /**
     * 从设备 MAC 地址字符串提取 6 字节
     */
    private fun getDeviceMac(deviceId: String): ByteArray {
        return try {
            deviceId.split(":").map { it.toInt(16).toByte() }.toByteArray()
        } catch (e: Exception) {
            // 如果解析失败，使用 deviceId hash 生成 6 字节
            val hash = deviceId.hashCode()
            byteArrayOf(
                (hash shr 24).toByte(), (hash shr 16).toByte(), (hash shr 8).toByte(),
                hash.toByte(), 0x00, 0x01
            )
        }
    }

    /**
     * 连接成功后自动执行认证
     * 如果设置了 fixedAuthKey 则直接使用，否则用 phoneMac + deviceMac 自动计算
     */
    private fun autoAuthenticate() {
        if (!config.autoAuthEnabled) {
            BlueLogger.debug("自动认证已禁用（config.autoAuthEnabled=false）")
            return
        }
        val device = connectedDevice ?: run {
            BlueLogger.error("自动认证失败：无连接设备")
            return
        }

        BlueLogger.info("连接成功，自动发起密钥认证...")

        val fixedKey = config.fixedAuthKey
        if (fixedKey != null && fixedKey.length == 4) {
            val keyHigh = fixedKey.substring(0, 2).toIntOrNull(16)?.toByte()
            val keyLow = fixedKey.substring(2, 4).toIntOrNull(16)?.toByte()
            if (keyHigh != null && keyLow != null) {
                // 固定密钥模式
                val keyBytes = byteArrayOf(keyHigh, keyLow)
                BlueLogger.debug("使用固定密钥 $fixedKey 认证")
                val frame = FrameBuilder.build(CommandCode.AUTH_KEY, keyBytes)
                connectionManager.commandQueue.enqueue(CommandCode.AUTH_KEY, frame) { result ->
                    result.fold(
                        onSuccess = { response ->
                            if (response.data.firstOrNull()?.toInt() == 0x01) {
                                connectionManager.transitionTo(ConnectionState.AUTHENTICATED)
                                BlueLogger.info("认证成功（固定密钥）")
                                CallbackDispatcher.dispatch {
                                    notifyObservers { it.onAuthResult(true, null)}
                                }
                            } else {
                                BlueLogger.error("固定密钥认证失败")
                                connectedDevice = null
                                CallbackDispatcher.dispatch {
                                    notifyObservers { it.onAuthResult(false, BlueError.AuthFailed)}
                                }
                                connectionManager.disconnect()
                            }
                        },
                        onFailure = { error ->
                            BlueLogger.error("认证指令发送失败：${error.message}")
                        }
                    )
                }
                return
            }
        }

        // 自动计算模式
        val phoneMac = getOrCreatePhoneMac()
        val deviceMac = getDeviceMac(device.deviceId)
        performAuth(phoneMac, deviceMac) { result ->
            result.fold(
                onSuccess = { BlueLogger.info("自动认证成功") },
                onFailure = { BlueLogger.error("自动认证失败：${it.message}") }
            )
        }
    }

    /** 执行认证（内部公共逻辑）*/
    private fun performAuth(phoneMac: ByteArray, deviceMac: ByteArray, completion: (Result<Unit>) -> Unit) {
        authManager.authenticate(phoneMac, deviceMac) { result ->
            result.fold(
                onSuccess = {
                    connectionManager.transitionTo(ConnectionState.AUTHENTICATED)
                    CallbackDispatcher.dispatch { notifyObservers { it.onAuthResult(true, null) } }
                    completion(Result.success(Unit))
                },
                onFailure = { error ->
                    val blueError = error as BlueError
                    BlueLogger.error("performAuth 失败：${blueError.message}")
                    if (blueError == BlueError.AuthFailed) {
                        connectedDevice = null
                    }
                    CallbackDispatcher.dispatch { notifyObservers { it.onAuthResult(false, blueError) } }
                    if (blueError == BlueError.AuthFailed) {
                        connectionManager.disconnect()
                    }
                    completion(Result.failure(blueError))
                }
            )
        }
    }

    // MARK: - 连接管理器事件处理

    private fun setupConnectionManager() {
        connectionManager.onStateChanged = { state ->
            CallbackDispatcher.dispatch { notifyObservers { it.onConnectionStateChanged(state) } }
            // 连接成功后自动认证
            if (state == ConnectionState.CONNECTED && connectedDevice != null) {
                autoAuthenticate()
            }
        }

        connectionManager.onError = { error ->
            BlueLogger.error("连接错误：${error.message}")
            CallbackDispatcher.dispatch { notifyObservers { it.onError(error) } }
        }

        connectionManager.onReconnecting = { attempt, maxAttempts ->
            CallbackDispatcher.dispatch { notifyObservers { it.onReconnecting(attempt, maxAttempts) } }
        }

        connectionManager.onReconnectFailed = {
            CallbackDispatcher.dispatch { notifyObservers { it.onReconnectFailed() } }
        }

        connectionManager.onDataReceived = { frame -> handleIncomingFrame(frame) }
    }

    private fun handleIncomingFrame(frame: com.blue.sdk.transport.ParsedFrame) {
        val cmdInt = frame.cmd.toInt() and 0xFF
        when {
            cmdInt == (CommandCode.TIME_SYNC.toInt() and 0xFF) -> {
                // 设备请求时间同步，节流处理：30秒内只响应一次
                val now = System.currentTimeMillis()
                if (now - lastTimeSyncMs >= 30000L) {
                    lastTimeSyncMs = now
                    BlueLogger.info("设备请求时间同步，自动下发")
                    deviceManager.syncTime { _ -> }
                } else {
                    BlueLogger.debug("时间同步请求已节流，跳过")
                }
                CallbackDispatcher.dispatch { notifyObservers { it.onTimeSyncRequested() } }
            }
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
                if (data.size >= 11) {
                    // byte9(data[9]) 区分事件类型：0x00=响铃开始, 非0=用药事件
                    val eventByte = data[9].toInt() and 0xFF
                    val statusByte = data[10].toInt() and 0xFF
                    val alarmInfo = AlarmManager.parseAlarmInfo(data, index)
                    if (alarmInfo != null) {
                        if (eventByte == 0x00 && statusByte != 0x00) {
                            // 响铃开始
                            CallbackDispatcher.dispatch { notifyObservers { it.onAlarmRinging(index, alarmInfo) } }
                        } else if (eventByte == 0x01) {
                            // 超时或取药事件
                            val status = MedicationStatus.fromByte(data[10])
                            if (status != null) {
                                CallbackDispatcher.dispatch { notifyObservers { it.onMedicationResult(index, status) } }
                            } else {
                                CallbackDispatcher.dispatch { notifyObservers { it.onAlarmTimeout(index, alarmInfo) } }
                            }
                        } else {
                            // 普通闹钟配置变更
                            CallbackDispatcher.dispatch { notifyObservers { it.onAlarmUpdated(alarmInfo) } }
                        }
                    }
                } else {
                    // 数据不足 11 字节，解析为普通闹钟配置上报
                    AlarmManager.parseAlarmInfo(data, index)?.let { alarm ->
                        CallbackDispatcher.dispatch { notifyObservers { it.onAlarmUpdated(alarm) } }
                    }
                }
            }

            dpid == DPIDConstants.ALARM_RECORD -> {
                MedicationManager.parseMedicationRecord(data)?.let { record ->
                    CallbackDispatcher.dispatch { notifyObservers { it.onMedicationRecordReported(record) } }
                }
            }
            dpid == DPIDConstants.TYPE_OF_SOUND -> {
                AudioManager.parseSoundType(data)?.let { type ->
                    CallbackDispatcher.dispatch { notifyObservers { it.onSoundTypeChanged(type) } }
                }
            }
            dpid == DPIDConstants.TIME_FORMAT -> {
                AudioManager.parseTimeFormat(data)?.let { format ->
                    currentTimeFormat = format
                    CallbackDispatcher.dispatch { notifyObservers { it.onTimeFormatChanged(format) } }
                }
            }
            dpidInt == (DPIDConstants.LOW_BAT.toInt() and 0xFF) -> {
                BlueLogger.info("设备上报低电状态")
                CallbackDispatcher.dispatch { notifyObservers { it.onLowBattery() } }
            }
            dpidInt == (DPIDConstants.NOTIFICATION_OF_RESULTS.toInt() and 0xFF) -> {
                // 用药结果通知：data[4] = 01响铃/02超时/03已取药
                val notifType = if (data.size >= 5) data[4].toInt() and 0xFF else 0
                if (notifType in 1..3) {
                    BlueLogger.info("用药通知：type=$notifType")
                    CallbackDispatcher.dispatch { notifyObservers { it.onMedicationNotification(notifType) } }
                }
            }
            else -> BlueLogger.debug("未处理的上报 DPID：0x${"%02X".format(dpidInt)}")
        }
    }
}
