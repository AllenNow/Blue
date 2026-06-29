// BlueSDK.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// SDK 公开 API 入口（单例）
// 所有公开 API 通过此类访问，支持 Swift 和 Objective-C 调用
// 连接成功后自动完成密钥认证（phoneMac 持久化存储在 Keychain）

import Foundation
import CoreBluetooth

/// BlueSDK 主入口，采用单例模式
/// 使用方式：`BlueSDKManager.shared.initialize()`
@objc public final class BlueSDKManager: NSObject {

    // MARK: - 单例

    @objc public static let shared = BlueSDKManager()

    // MARK: - 内部组件

    private var isInitialized = false
    private let logger = BlueLogger.shared
    private let connectionManager = ConnectionManager()
    private let scanner = BLEScanner()
    private var authManager: AuthManager?
    private var deviceManager: DeviceManager?
    private var alarmManager: AlarmManager?
    private var medicationManager: MedicationManager?
    private var audioManager: AudioManager?

    // MARK: - 自动认证状态

    private static let keychainPhoneMacKey = "com.blue.sdk.phoneMac"
    private var connectedPeripheral: CBPeripheral?
    private var lastTimeSyncDate: Date?

    /// 固定密钥（2字节十六进制字符串，如 "05FA"）。
    /// 推荐通过 BlueSDKConfig 初始化时设置。运行时修改此值是线程安全的。
    public var fixedAuthKey: String? {
        get { config.fixedAuthKey }
        set {
            config = BlueSDKConfig(
                fixedAuthKey: newValue,
                logLevel: config.logLevel,
                autoAuthEnabled: config.autoAuthEnabled,
                autoReconnect: config.autoReconnect,
                maxReconnectAttempts: config.maxReconnectAttempts
            )
        }
    }

    /// SDK 配置（通过 initialize 时传入，运行时可修改 customPhoneMac 等字段）
    public var config: BlueSDKConfig = BlueSDKConfig()

    // MARK: - 公开回调

    /// 主 delegate（向后兼容）
    public weak var delegate: BlueSDKDelegate?

    /// 多播观察者列表 — 支持多个地方同时监听事件
    private var observers = NSHashTable<AnyObject>.weakObjects()

    /// 添加事件观察者（弱引用，无需手动移除）
    public func addObserver(_ observer: BlueSDKDelegate) {
        observers.add(observer as AnyObject)
    }

    /// 移除事件观察者
    public func removeObserver(_ observer: BlueSDKDelegate) {
        observers.remove(observer as AnyObject)
    }

    /// 通知所有观察者（含主 delegate，自动去重）
    private func notifyObservers(_ block: (BlueSDKDelegate) -> Void) {
        if let d = delegate { block(d) }
        for obj in observers.allObjects {
            if let obs = obj as? BlueSDKDelegate, obs !== delegate { block(obs) }
        }
    }

    private override init() {
        super.init()
        setupConnectionManager()
    }

    // MARK: - 生命周期（FR32、FR33）

    /// 初始化 SDK（耗时 ≤ 100ms，NFR04）
    /// - Parameter config: SDK 配置项（可选，默认使用自动密钥模式）
    public func initialize(config: BlueSDKConfig = BlueSDKConfig()) {
        guard !isInitialized else { return }
        self.config = config
        isInitialized = true
        let queue = connectionManager.getCommandQueue()
        authManager       = AuthManager(commandQueue: queue)
        deviceManager     = DeviceManager(commandQueue: queue)
        alarmManager      = AlarmManager(commandQueue: queue)
        medicationManager = MedicationManager(commandQueue: queue)
        audioManager      = AudioManager(commandQueue: queue)
        logger.logLevel = config.logLevel
        SDKLocale.setLanguage(config.language)
        logger.info("BlueSDK initialized")
    }

    /// 销毁 SDK，释放所有 BLE 资源（FR33）
    @objc public func destroy() {
        guard isInitialized else { return }
        connectionManager.disconnect()
        connectedPeripheral = nil
        lastTimeSyncDate = nil
        isInitialized = false
        logger.info("BlueSDK destroyed")
    }

    // MARK: - 日志配置（FR34、FR35）

    @objc public func setLogLevel(_ level: LogLevel) {
        logger.logLevel = level
    }

    public func setLogHandler(_ handler: BlueLogHandler?) {
        logger.logHandler = handler
    }

    /// 运行时切换 SDK 语言（影响错误描述和恢复建议）
    public func setLanguage(_ language: BlueSDKLanguage) {
        SDKLocale.setLanguage(language)
    }

    /// 导出 SDK 运行日志（Story 10.4）
    /// 最近 1000 条日志，含时间戳、级别、标签，密钥已脱敏
    /// - Parameter maxLines: 最大导出行数，nil 表示全部
    /// - Returns: 日志文本
    public func exportLog(maxLines: Int? = nil) -> String {
        return logger.exportLog(maxLines: maxLines)
    }

    /// 清空日志缓冲区
    @objc public func clearLogBuffer() {
        logger.clearLogBuffer()
    }

    // MARK: - 连接管理（Epic 2）

    /// 查询蓝牙权限状态（FR07）
    @objc public func checkPermissions() -> PermissionStatus {
        return PermissionManager.checkPermission()
    }

    /// 当前连接状态（FR06）
    @objc public var connectionState: ConnectionState {
        return connectionManager.state
    }

    /// 当前设备时间格式（设备上报后自动更新，默认 24H）
    /// App 界面展示时间时应跟随此值选择 12/24 小时制
    public private(set) var currentTimeFormat: TimeFormat = .hour24

    /// 开始扫描 LX-PD02 设备（旧版双回调，已废弃）
    @available(*, deprecated, message: "使用 startScan(timeout:callback:) 替代")
    public func startScan(
        onDeviceFound: @escaping (ScannedDevice) -> Void,
        onError: @escaping (BlueError) -> Void
    ) {
        guard requireInitialized(callback: onError) else { return }
        scanner.startScan(onDeviceFound: onDeviceFound, onError: onError)
    }

    /// 开始扫描 LX-PD02 设备（FR01）
    /// 使用统一的 ScanEvent 回调模式
    /// - Parameters:
    ///   - timeout: 扫描超时时间（秒），0 表示不超时。默认 10 秒
    ///   - callback: 扫描事件回调（主线程），包含 .deviceFound / .error / .stopped 三种事件
    public func startScan(
        timeout: TimeInterval = 10,
        callback: @escaping (ScanEvent) -> Void
    ) {
        guard requireInitialized(callback: { error in callback(.error(error)) }) else { return }
        scanner.startScan(
            onDeviceFound: { device in callback(.deviceFound(device)) },
            onError: { error in callback(.error(error)) }
        )
        // 超时自动停止
        if timeout > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let self = self, self.scanner.isScanning else { return }
                self.stopScan()
                callback(.stopped)
            }
        }
    }

    /// 停止扫描（FR01）
    @objc public func stopScan() {
        scanner.stopScan()
    }

    /// 连接指定设备（FR02）
    /// 连接成功后 SDK 内部自动完成密钥认证
    public func connect(_ device: ScannedDevice) {
        guard requireInitialized(callback: { _ in }) else { return }
        connectedPeripheral = device.peripheral
        connectionManager.connect(peripheral: device.peripheral)
    }

    /// 通过设备 UUID 直接连接（无需重新扫描）
    /// 适用于已绑定设备的快速重连场景
    /// - Parameters:
    ///   - identifier: 设备的 UUID 字符串（ScannedDevice.deviceId）
    ///   - completion: 如果设备未找到返回错误，找到后自动发起连接（结果通过 delegate 回调）
    public func connect(byIdentifier identifier: String, completion: ((BlueError?) -> Void)? = nil) {
        guard requireInitialized(callback: { _ in completion?(.notInitialized) }) else { return }
        guard let uuid = UUID(uuidString: identifier) else {
            completion?(.invalidParameter)
            return
        }
        let peripherals = BLECentralManager.shared.centralManager.retrievePeripherals(withIdentifiers: [uuid])
        if let peripheral = peripherals.first {
            connectedPeripheral = peripheral
            connectionManager.connect(peripheral: peripheral)
            completion?(nil)
        } else {
            // 尝试从已连接设备恢复
            let connected = BLECentralManager.shared.centralManager.retrieveConnectedPeripherals(withServices: [])
            if let peripheral = connected.first(where: { $0.identifier == uuid }) {
                connectedPeripheral = peripheral
                connectionManager.connect(peripheral: peripheral)
                completion?(nil)
            } else {
                completion?(.deviceNotFound)
            }
        }
    }

    /// 解绑设备
    /// 向设备发送解绑指令（CMD=0xA1），成功应答后清除本地密钥并断开连接
    /// - Parameter completion: 操作完成回调
    public func clearBinding(completion: @escaping (Result<Void, BlueError>) -> Void = { _ in }) {
        guard requireInitialized(callback: { completion(.failure($0)) }) else { return }

        // 已连接时发送解绑指令
        let state = connectionManager.state
        if state == .authenticated || state == .connected {
            let frame = FrameBuilder.build(cmd: CommandCode.unbind)
            connectionManager.getCommandQueue().enqueue(cmd: CommandCode.unbind, frame: frame) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success:
                    // 设备应答成功，断开连接（保留本地 phoneMac）
                    self.connectedPeripheral = nil
                    self.connectionManager.disconnect()
                    self.logger.info("Unbind success, disconnected")
                    completion(.success(()))
                case .failure(let error):
                    self.logger.error("Unbind command failed: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        } else {
            // 未连接时直接完成
            connectedPeripheral = nil
            logger.info("Device not connected, unbind done")
            completion(.success(()))
        }
    }

    /// 获取当前本地认证密钥的十六进制字符串
    /// 优先级：fixedAuthKey > customPhoneMac > Keychain phoneMac
    /// 用于界面展示当前使用的认证密钥
    public var currentAuthKeyDisplay: String {
        if let fixed = config.fixedAuthKey, fixed.count == 4 {
            return "Fixed: \(fixed)"
        }
        if let custom = config.customPhoneMac, custom.count == 12 {
            // 格式化为 XX:XX:XX:XX:XX:XX
            let formatted = stride(from: 0, to: 12, by: 2).map { i in
                let start = custom.index(custom.startIndex, offsetBy: i)
                let end = custom.index(start, offsetBy: 2)
                return String(custom[start..<end])
            }.joined(separator: ":")
            return formatted
        }
        if let data = KeychainHelper.load(forKey: BlueSDKManager.keychainPhoneMacKey), data.count == 6 {
            return [UInt8](data).map { String(format: "%02X", $0) }.joined(separator: ":")
        }
        return "N/A"
    }

    /// 断开连接（FR03）
    @objc public func disconnect() {
        requireInitialized { _ in }
        connectedPeripheral = nil
        connectionManager.disconnect()
    }

    /// 取消正在进行的自动重连
    public func cancelReconnection() {
        connectionManager.cancelReconnection()
    }

    // MARK: - 认证（Epic 3）

    /// 使用指定密钥值直接认证（用于恢复已绑定设备）
    public func authenticateWithKey(
        keyHigh: UInt8,
        keyLow: UInt8,
        completion: @escaping (Result<Void, BlueError>) -> Void
    ) {
        guard requireInitialized(callback: { completion(.failure($0)) }) else { return }
        let keyBytes: [UInt8] = [keyHigh, keyLow]
        logger.info("Manual auth: key=\(String(format: "%02X%02X", keyHigh, keyLow))")
        let frame = FrameBuilder.build(cmd: CommandCode.authKey, data: keyBytes)
        connectionManager.getCommandQueue().enqueue(cmd: CommandCode.authKey, frame: frame) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                if response.data.first == 0x01 {
                    self.connectionManager.transitionTo(.authenticated)
                    completion(.success(()))
                } else {
                    self.connectionManager.disconnect()
                    completion(.failure(.authFailed))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 发送密钥包完成设备认证（FR08）— 内部使用
    /// SDK 内置自动认证，如需指定密钥请使用 BlueSDKConfig.fixedAuthKey 或 authenticateWithKey()
    internal func authenticate(
        phoneMac: [UInt8],
        deviceMac: [UInt8],
        completion: @escaping (Result<Void, BlueError>) -> Void
    ) {
        guard requireInitialized(callback: { completion(.failure($0)) }) else { return }
        performAuth(phoneMac: phoneMac, deviceMac: deviceMac, completion: completion)
    }

    // MARK: - 设备信息与时间同步（Epic 4）

    /// 查询设备信息（FR12）
    /// 注意：此方法可在认证前调用，但需要 BLE 已连接
    public func queryDeviceInfo(completion: @escaping (Result<DeviceInfo, BlueError>) -> Void) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireConnected(callback: { completion(.failure($0)) }) else { return }
        deviceManager?.queryDeviceInfo(completion: completion)
    }

    /// 下发当前系统时间（FR14）
    public func syncTime(date: Date = Date(), completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        deviceManager?.syncTime(date: date, completion: completion)
    }

    // MARK: - 闹钟管理（Epic 5）

    /// 设置闹钟（FR15）
    /// - Note: 推荐使用 `setAlarm(index:hour:minute:days:completion:)` 类型安全版本
    @available(*, deprecated, message: "使用 setAlarm(index:hour:minute:days:completion:) 替代")
    public func setAlarm(
        index: Int,
        hour: Int,
        minute: Int,
        weekMask: Int = 0x7F,
        completion: @escaping (Result<AlarmInfo, BlueError>) -> Void
    ) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        alarmManager?.setAlarm(index: index, hour: hour, minute: minute, weekMask: weekMask, completion: completion)
    }

    /// 设置闹钟（类型安全版本）
    /// - Parameters:
    ///   - index: 闹钟槽位（1~7）
    ///   - hour: 小时（0~23）
    ///   - minute: 分钟（0~59）
    ///   - days: 重复星期，默认每天
    ///   - completion: 结果回调
    public func setAlarm(
        index: Int,
        hour: Int,
        minute: Int,
        days: WeekDays = .all,
        completion: @escaping (Result<AlarmInfo, BlueError>) -> Void
    ) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        alarmManager?.setAlarm(index: index, hour: hour, minute: minute, weekMask: days.rawValue, completion: completion)
    }

    /// 删除闹钟（FR16）
    public func deleteAlarm(index: Int, completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        alarmManager?.deleteAlarm(index: index, completion: completion)
    }

    /// 清空所有闹钟（FR17）
    public func clearAllAlarms(completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        alarmManager?.clearAllAlarms(completion: completion)
    }

    /// 批量设置闹钟（便利方法）
    /// 内部串行发送，全部成功后回调 success，任一失败即回调 failure
    /// - Parameters:
    ///   - alarms: 闹钟配置列表
    ///   - completion: 全部完成后回调，成功返回设置好的 AlarmInfo 列表
    public func setAlarms(
        _ alarms: [AlarmConfig],
        completion: @escaping (Result<[AlarmInfo], BlueError>) -> Void
    ) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        guard !alarms.isEmpty else { completion(.success([])); return }

        var results: [AlarmInfo] = []
        func setNext(index: Int) {
            if index >= alarms.count {
                completion(.success(results))
                return
            }
            let alarm = alarms[index]
            alarmManager?.setAlarm(index: alarm.index, hour: alarm.hour, minute: alarm.minute, weekMask: alarm.weekMask) { result in
                switch result {
                case .success(let info):
                    results.append(info)
                    setNext(index: index + 1)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        setNext(index: 0)
    }

    // MARK: - 用药事件（Epic 6）

    /// 下发用药结果通知（FR24）
    public func sendMedicationNotification(
        status: MedicationStatus,
        completion: @escaping (Result<Void, BlueError>) -> Void
    ) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        medicationManager?.sendMedicationNotification(status: UInt8(status.rawValue), completion: completion)
    }

    // MARK: - 音频与系统设置（Epic 7）

    /// 设置音量（FR25）
    public func setVolume(_ level: VolumeLevel, completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        audioManager?.setVolume(level, completion: completion)
    }

    /// 设置铃声类型（FR26）
    public func setSoundType(_ type: SoundType, completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        audioManager?.setSoundType(type, completion: completion)
    }

    /// 设置静音（FR28）
    public func setSilence(_ enabled: Bool, completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        audioManager?.setSilence(enabled, completion: completion)
    }

    /// 设置提醒持续时长（FR29）
    public func setAlertDuration(_ minutes: Int, completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        audioManager?.setAlertDuration(minutes, completion: completion)
    }

    /// 设置时间格式（FR30）
    public func setTimeFormat(_ format: TimeFormat, completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        audioManager?.setTimeFormat(format) { [weak self] result in
            if case .success = result { self?.currentTimeFormat = format }
            completion(result)
        }
    }

    // MARK: - 系统控制（Epic 9）

    /// 恢复出厂设置（Story 9.1）
    /// 恢复出厂设置
    /// 发送后设备会立即重启断开 BLE，不等待应答（fire-and-forget）
    public func restoreFactory(completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        let data: [UInt8] = [DPIDConstants.restoreFactory, 0x01, 0x00, 0x01, 0x01]
        let frame = FrameBuilder.build(cmd: CommandCode.sendCommand, data: data)
        // 恢复出厂后设备会立即重启并断开 BLE，不等待应答
        connectionManager.getCommandQueue().sendDirect(frame: frame)
        logger.info("Factory reset sent (fire-and-forget)")
        completion(.success(()))
    }

    /// Send raw command data (debug only)
    /// ⚠️ This method bypasses protocol validation. Use only for debugging and protocol testing.
    /// For production, use the typed API methods (setAlarm, setVolume, etc.)
    /// - Parameters:
    ///   - data: Raw data bytes (without frame header/CRC, SDK wraps as CMD=0x06 frame)
    ///   - completion: Result callback
    @available(*, deprecated, message: "Debug only — use typed API methods for production")
    public func sendRawData(data: [UInt8], completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        let frame = FrameBuilder.build(cmd: CommandCode.sendCommand, data: data)
        connectionManager.getCommandQueue().enqueue(cmd: CommandCode.sendCommand, frame: frame) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 查询指定闹钟槽位当前配置（FR15）
    public func queryAlarm(index: Int, completion: @escaping (Result<AlarmInfo, BlueError>) -> Void) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        alarmManager?.queryAlarm(index: index, completion: completion)
    }

    // MARK: - 内部工具

    @discardableResult
    internal func requireInitialized(callback: (BlueError) -> Void) -> Bool {
        guard isInitialized else { callback(.notInitialized); return false }
        return true
    }

    @discardableResult
    internal func requireAuthenticated(callback: (BlueError) -> Void) -> Bool {
        guard connectionManager.state == .authenticated else { callback(.notAuthenticated); return false }
        return true
    }

    @discardableResult
    internal func requireConnected(callback: (BlueError) -> Void) -> Bool {
        let s = connectionManager.state
        guard s != .disconnected && s != .connecting else { callback(.disconnected); return false }
        return true
    }

    // MARK: - 自动认证逻辑

    /// 获取或生成 phoneMac（6字节）
    /// 优先级：config.customPhoneMac > Keychain 缓存 > UUID 自动生成
    private func getOrCreatePhoneMac() -> [UInt8] {
        // 1. 集成方自定义 phoneMac（12字符十六进制，如 "A1B2C3D4E5F6"）
        if let custom = config.customPhoneMac, custom.count == 12 {
            let bytes = stride(from: 0, to: 12, by: 2).compactMap { i -> UInt8? in
                let start = custom.index(custom.startIndex, offsetBy: i)
                let end = custom.index(start, offsetBy: 2)
                return UInt8(custom[start..<end], radix: 16)
            }
            if bytes.count == 6 { return bytes }
        }

        // 2. 从 Keychain 读取已存储的 phoneMac
        if let storedData = KeychainHelper.load(forKey: BlueSDKManager.keychainPhoneMacKey), storedData.count == 6 {
            return Array(storedData)
        }
        
        // 3. UUID 自动生成并存入 Keychain
        let uuid = UUID()
        let uuidBytes = withUnsafeBytes(of: uuid.uuid) { Array($0) }
        let phoneMac = Array(uuidBytes.prefix(6))
        
        KeychainHelper.save(data: Data(phoneMac), forKey: BlueSDKManager.keychainPhoneMacKey)
        
        return phoneMac
    }

    /// 从 peripheral UUID 提取 6 字节作为 deviceMac
    private func getDeviceMac(from peripheral: CBPeripheral) -> [UInt8] {
        let uuidBytes = withUnsafeBytes(of: peripheral.identifier.uuid) { Array($0) }
        return Array(uuidBytes.prefix(6))
    }

    /// 连接成功后自动执行认证
    /// 如果设置了 fixedAuthKey 则直接使用，否则用 phoneMac + deviceMac 自动计算
    private func autoAuthenticate() {
        guard config.autoAuthEnabled else {
            logger.debug("Auto-auth disabled (config.autoAuthEnabled=false)")
            return
        }
        guard let peripheral = connectedPeripheral else {
            logger.error("Auto-auth failed: no connected device")
            return
        }

        logger.info("Connected, starting auto-auth...")

        // 判断是否使用固定密钥
        if let fixedKey = config.fixedAuthKey, fixedKey.count == 4,
           let keyHigh = UInt8(fixedKey.prefix(2), radix: 16),
           let keyLow = UInt8(fixedKey.suffix(2), radix: 16) {
            // 固定密钥模式
            let keyBytes: [UInt8] = [keyHigh, keyLow]
            logger.debug("Using fixed key \(fixedKey)")
            let frame = FrameBuilder.build(cmd: CommandCode.authKey, data: keyBytes)
            connectionManager.getCommandQueue().enqueue(cmd: CommandCode.authKey, frame: frame) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    if response.data.first == 0x01 {
                        self.connectionManager.transitionTo(.authenticated)
                        self.logger.info("Auth success (fixed key)")
                        CallbackDispatcher.shared.dispatch {
                            self.notifyObservers { $0.blueSDK(self, didAuthenticateWithSuccess: true, error: nil)}
                        }
                    } else {
                        self.logger.error("Fixed key auth failed")
                        self.connectedPeripheral = nil
                        self.connectionManager.disconnect()
                        CallbackDispatcher.shared.dispatch {
                            self.notifyObservers { $0.blueSDK(self, didAuthenticateWithSuccess: false, error: .authFailed)}
                        }
                    }
                case .failure(let error):
                    self.logger.error("Auth command failed: \(error)")
                }
            }
        } else {
            // 自动计算模式
            let phoneMac = getOrCreatePhoneMac()
            let deviceMac = getDeviceMac(from: peripheral)
            performAuth(phoneMac: phoneMac, deviceMac: deviceMac) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success:
                    self.logger.info("Auto-auth success")
                case .failure(let error):
                    self.logger.error("Auto-auth failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 执行认证（内部公共逻辑）
    private func performAuth(
        phoneMac: [UInt8],
        deviceMac: [UInt8],
        completion: @escaping (Result<Void, BlueError>) -> Void
    ) {
        authManager?.authenticate(phoneMac: phoneMac, deviceMac: deviceMac) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.connectionManager.transitionTo(.authenticated)
                CallbackDispatcher.shared.dispatch {
                    self.notifyObservers { $0.blueSDK(self, didAuthenticateWithSuccess: true, error: nil)}
                }
                completion(.success(()))
            case .failure(let error):
                self.logger.error("performAuth failed: \(error.localizedDescription)")
                if error == .authFailed {
                    self.connectedPeripheral = nil
                }
                CallbackDispatcher.shared.dispatch {
                    self.notifyObservers { $0.blueSDK(self, didAuthenticateWithSuccess: false, error: error)}
                }
                if error == .authFailed {
                    self.connectionManager.disconnect()
                }
                completion(.failure(error))
            }
        }
    }

    // MARK: - 连接管理器事件处理

    private func setupConnectionManager() {
        connectionManager.onStateChanged = { [weak self] state in
            guard let self = self else { return }
            CallbackDispatcher.shared.dispatch {
                self.notifyObservers { $0.blueSDK(self, didChangeConnectionState: state)}
            }

            // 连接成功后自动认证（仅当有目标设备时，认证失败断开后不再重试）
            if state == .connected, self.connectedPeripheral != nil {
                self.autoAuthenticate()
            }
        }

        connectionManager.onError = { [weak self] error in
            guard let self = self else { return }
            self.logger.error("Connection error: \(error.localizedDescription)")
            CallbackDispatcher.shared.dispatch {
                self.notifyObservers { $0.blueSDK(self, didEncounterError: error)}
            }
        }

        connectionManager.onReconnecting = { [weak self] attempt, maxAttempts in
            guard let self = self else { return }
            CallbackDispatcher.shared.dispatch {
                self.notifyObservers { $0.blueSDK(self, didStartReconnecting: attempt, maxAttempts: maxAttempts)}
            }
        }

        connectionManager.onReconnectFailed = { [weak self] in
            guard let self = self else { return }
            CallbackDispatcher.shared.dispatch {
                self.notifyObservers { $0.blueSDKDidFailReconnection(self) }
            }
        }

        connectionManager.onDataReceived = { [weak self] frame in
            self?.handleIncomingFrame(frame)
        }
    }

    private func handleIncomingFrame(_ frame: ParsedFrame) {
        switch frame.cmd {
        case CommandCode.timeSync:
            // 设备请求时间同步，节流处理：30秒内只响应一次
            let now = Date()
            if let last = lastTimeSyncDate, now.timeIntervalSince(last) < 30 {
                logger.debug("Time sync throttled, skipped")
            } else {
                lastTimeSyncDate = now
                logger.info("Device requests time sync, auto-sending")
                deviceManager?.syncTime { _ in }
            }
            CallbackDispatcher.shared.dispatch { [weak self] in
                guard let self = self else { return }
                self.notifyObservers { $0.blueSDKDidRequestTimeSync(self) }
            }

        case CommandCode.deviceReport:
            guard let dpid = frame.data.first else { return }
            handleDeviceReport(dpid: dpid, data: frame.data)

        default:
            break
        }
    }

    private func handleDeviceReport(dpid: UInt8, data: [UInt8]) {
        switch dpid {
        case DPIDConstants.alarm1...DPIDConstants.alarm7:
            let index = Int(dpid - DPIDConstants.alarm1) + 1
            guard data.count >= 11 else {
                // 数据不足，尝试解析为普通闹钟配置上报
                if let alarm = AlarmManager.parseAlarmInfo(from: data, index: index) {
                    CallbackDispatcher.shared.dispatch { [weak self] in
                        guard let self = self else { return }
                        self.notifyObservers { $0.blueSDK(self, didUpdateAlarm: alarm)}
                    }
                }
                return
            }
            // 闹钟 DPID 上报只关注使能位(data[4])和时间位(data[5-7])
            // 后三位状态(data[8-10])由 0x6F 通知帧和 0x65 记录帧负责
            if let alarm = AlarmManager.parseAlarmInfo(from: data, index: index) {
                CallbackDispatcher.shared.dispatch { [weak self] in
                    guard let self = self else { return }
                    self.notifyObservers { $0.blueSDK(self, didUpdateAlarm: alarm)}
                }
            }

        case DPIDConstants.alarmRecord:
            if let record = MedicationManager.parseMedicationRecord(from: data) {
                // 同时触发用药结果回调（带闹钟索引）和完整记录回调
                CallbackDispatcher.shared.dispatch { [weak self] in
                    guard let self = self else { return }
                    self.notifyObservers { $0.blueSDK(self, didReceiveMedicationResult: record.alarmIndex, status: record.status)}
                    self.notifyObservers { $0.blueSDK(self, didReceiveMedicationRecord: record)}
                }
            }

        case DPIDConstants.typeOfSound:
            if let soundType = AudioManager.parseSoundType(from: data) {
                CallbackDispatcher.shared.dispatch { [weak self] in
                    guard let self = self else { return }
                    self.notifyObservers { $0.blueSDK(self, didChangeSoundType: soundType)}
                }
            }

        case DPIDConstants.alertDuration:
            if let minutes = AudioManager.parseAlertDuration(from: data) {
                logger.info("Alert duration changed: \(minutes) min")
                CallbackDispatcher.shared.dispatch { [weak self] in
                    guard let self = self else { return }
                    self.notifyObservers { $0.blueSDK(self, didChangeAlertDuration: minutes)}
                }
            }

        case DPIDConstants.timeFormat:
            if let format = AudioManager.parseTimeFormat(from: data) {
                currentTimeFormat = format
                CallbackDispatcher.shared.dispatch { [weak self] in
                    guard let self = self else { return }
                    self.notifyObservers { $0.blueSDK(self, didChangeTimeFormat: format)}
                }
            }

        case DPIDConstants.lowBat:
            logger.info("Device reports low battery")
            CallbackDispatcher.shared.dispatch { [weak self] in
                guard let self = self else { return }
                self.notifyObservers { $0.blueSDKDidReportLowBattery(self) }
            }

        case DPIDConstants.notificationOfResults:
            // 用药结果通知（设备上报）：data[4] = 01响铃/02超时/03已取药
            if data.count >= 5 {
                let notifType = Int(data[4])
                if notifType >= 1 && notifType <= 3 {
                    logger.info("Medication notification: type=\(notifType)")
                    let typed = MedicationNotificationType(rawValue: notifType)
                    CallbackDispatcher.shared.dispatch { [weak self] in
                        guard let self = self else { return }
                        if let typed = typed {
                            self.notifyObservers { $0.blueSDK(self, didReceiveMedicationNotification: typed) }
                        }
                        self.notifyObservers { $0.blueSDK(self, didReceiveMedicationNotificationRaw: notifType) }
                    }
                }
            }

        default:
            logger.debug("Unhandled report DPID: \(String(format: "0x%02X", dpid))")
        }
    }
}
