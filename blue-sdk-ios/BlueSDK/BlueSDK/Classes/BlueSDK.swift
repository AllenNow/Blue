// BlueSDK.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// SDK 公开 API 入口（单例）
// 所有公开 API 通过此类访问，支持 Swift 和 Objective-C 调用
// 连接成功后自动完成密钥认证（phoneMac 持久化存储在 Keychain）

import Foundation
import CoreBluetooth
import UIKit

/// BlueSDK 主入口，采用单例模式
/// 使用方式：`BlueSDK.shared.initialize()`
@objc public final class BlueSDK: NSObject {

    // MARK: - 单例

    @objc public static let shared = BlueSDK()

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

    /// SDK 配置（通过 initialize 时传入）
    private var config: BlueSDKConfig = BlueSDKConfig()

    // MARK: - 公开回调

    public weak var delegate: BlueSDKDelegate?

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
        logger.info("BlueSDK 初始化完成")
    }

    /// 销毁 SDK，释放所有 BLE 资源（FR33）
    @objc public func destroy() {
        guard isInitialized else { return }
        connectionManager.disconnect()
        isInitialized = false
        logger.info("BlueSDK 已销毁")
    }

    // MARK: - 日志配置（FR34、FR35）

    @objc public func setLogLevel(_ level: LogLevel) {
        logger.logLevel = level
    }

    public func setLogHandler(_ handler: BlueLogHandler?) {
        logger.logHandler = handler
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

    /// 清除本地绑定密钥（用于重新配对）
    /// 清除后下次连接会生成新的 phoneMac，需配合设备恢复出厂使用
    /// - Parameter completion: 操作完成回调（默认空回调，向后兼容）
    public func clearBinding(completion: @escaping (Result<Void, BlueError>) -> Void = { _ in }) {
        KeychainHelper.delete(forKey: BlueSDK.keychainPhoneMacKey)
        logger.info("本地绑定密钥已清除")
        completion(.success(()))
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
        logger.info("手动密钥认证：key=\(String(format: "%02X%02X", keyHigh, keyLow))")
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
                completion(.failure(error as! BlueError))
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
    /// 注意：此方法可在认证前调用（用于获取设备 MAC 计算密钥）
    public func queryDeviceInfo(completion: @escaping (Result<DeviceInfo, BlueError>) -> Void) {
        guard requireInitialized(callback: { completion(.failure($0)) }) else { return }
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
        audioManager?.setTimeFormat(format, completion: completion)
    }

    /// 恢复出厂设置
    /// 设备会清除所有闹钟配置和绑定密钥
    public func restoreFactory(completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        let data: [UInt8] = [DPIDConstants.restoreFactory, 0x01, 0x00, 0x01, 0x01]
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

    // MARK: - 自动认证逻辑

    /// 获取或生成 phoneMac（6字节），持久化存储在 Keychain
    private func getOrCreatePhoneMac() -> [UInt8] {
        // 尝试从 Keychain 读取
        if let stored = KeychainHelper.load(forKey: BlueSDK.keychainPhoneMacKey), stored.count == 6 {
            return [UInt8](stored)
        }

        // 首次使用，从 identifierForVendor 生成 6 字节
        var mac: [UInt8]
        if let uuid = UIDevice.current.identifierForVendor {
            let uuidBytes = withUnsafeBytes(of: uuid.uuid) { Array($0) } // 16字节
            mac = Array(uuidBytes.prefix(6))
        } else {
            // 极端情况下 identifierForVendor 为 nil，随机生成
            mac = (0..<6).map { _ in UInt8.random(in: 0...255) }
        }

        // 存入 Keychain
        let data = Data(mac)
        KeychainHelper.save(data: data, forKey: BlueSDK.keychainPhoneMacKey)
        logger.info("phoneMac 已生成并存入 Keychain")
        return mac
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
            logger.debug("自动认证已禁用（config.autoAuthEnabled=false）")
            return
        }
        guard let peripheral = connectedPeripheral else {
            logger.error("自动认证失败：无连接设备")
            return
        }

        logger.info("连接成功，自动发起密钥认证...")

        // 判断是否使用固定密钥
        if let fixedKey = config.fixedAuthKey, fixedKey.count == 4,
           let keyHigh = UInt8(fixedKey.prefix(2), radix: 16),
           let keyLow = UInt8(fixedKey.suffix(2), radix: 16) {
            // 固定密钥模式
            let keyBytes: [UInt8] = [keyHigh, keyLow]
            logger.debug("使用固定密钥 \(fixedKey) 认证")
            let frame = FrameBuilder.build(cmd: CommandCode.authKey, data: keyBytes)
            connectionManager.getCommandQueue().enqueue(cmd: CommandCode.authKey, frame: frame) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    if response.data.first == 0x01 {
                        self.connectionManager.transitionTo(.authenticated)
                        self.logger.info("认证成功（固定密钥）")
                        CallbackDispatcher.shared.dispatch {
                            self.delegate?.blueSDK(self, didAuthenticateWithSuccess: true, error: nil)
                        }
                    } else {
                        self.logger.error("固定密钥认证失败")
                        self.connectedPeripheral = nil
                        self.connectionManager.disconnect()
                        CallbackDispatcher.shared.dispatch {
                            self.delegate?.blueSDK(self, didAuthenticateWithSuccess: false, error: .authFailed)
                        }
                    }
                case .failure(let error):
                    self.logger.error("认证指令发送失败：\(error)")
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
                    self.logger.info("自动认证成功")
                case .failure(let error):
                    self.logger.error("自动认证失败：\(error.localizedDescription)")
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
                    self.delegate?.blueSDK(self, didAuthenticateWithSuccess: true, error: nil)
                }
                completion(.success(()))
            case .failure(let error):
                self.logger.error("performAuth 失败：\(error.localizedDescription)")
                if error == .authFailed {
                    // 认证失败，停止自动重连，保持断开状态
                    self.connectedPeripheral = nil
                    self.connectionManager.disconnect()
                }
                CallbackDispatcher.shared.dispatch {
                    self.delegate?.blueSDK(self, didAuthenticateWithSuccess: false, error: error)
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
                self.delegate?.blueSDK(self, didChangeConnectionState: state)
            }

            // 连接成功后自动认证（仅当有目标设备时，认证失败断开后不再重试）
            if state == .connected, self.connectedPeripheral != nil {
                self.autoAuthenticate()
            }
        }

        connectionManager.onError = { [weak self] error in
            guard let self = self else { return }
            self.logger.error("连接错误：\(error.localizedDescription)")
            CallbackDispatcher.shared.dispatch {
                self.delegate?.blueSDK(self, didEncounterError: error)
            }
        }

        connectionManager.onReconnecting = { [weak self] attempt, maxAttempts in
            guard let self = self else { return }
            CallbackDispatcher.shared.dispatch {
                self.delegate?.blueSDK(self, didStartReconnecting: attempt, maxAttempts: maxAttempts)
            }
        }

        connectionManager.onReconnectFailed = { [weak self] in
            guard let self = self else { return }
            CallbackDispatcher.shared.dispatch {
                self.delegate?.blueSDKDidFailReconnection(self)
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
                logger.debug("时间同步请求已节流，跳过")
            } else {
                lastTimeSyncDate = now
                logger.info("设备请求时间同步，自动下发")
                deviceManager?.syncTime { _ in }
            }
            CallbackDispatcher.shared.dispatch { [weak self] in
                guard let self = self else { return }
                self.delegate?.blueSDKDidRequestTimeSync(self)
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
                        self.delegate?.blueSDK(self, didUpdateAlarm: alarm)
                    }
                }
                return
            }
            // byte9(data[9]) 区分事件类型：0x00=响铃开始, 非0=用药事件
            let eventByte = data[9]
            let statusByte = data[10]
            if let alarm = AlarmManager.parseAlarmInfo(from: data, index: index) {
                if eventByte == 0x00 && statusByte != 0x00 {
                    // 响铃开始（byte9=0x00, byte10=闹钟编号标识）
                    CallbackDispatcher.shared.dispatch { [weak self] in
                        guard let self = self else { return }
                        self.delegate?.blueSDK(self, didAlarmRinging: index, alarmInfo: alarm)
                    }
                } else if eventByte == 0x01 {
                    // 超时或取药事件
                    if let status = MedicationStatus.from(byte: statusByte) {
                        CallbackDispatcher.shared.dispatch { [weak self] in
                            guard let self = self else { return }
                            self.delegate?.blueSDK(self, didReceiveMedicationResult: index, status: status)
                        }
                    } else {
                        CallbackDispatcher.shared.dispatch { [weak self] in
                            guard let self = self else { return }
                            self.delegate?.blueSDK(self, didAlarmTimeout: index, alarmInfo: alarm)
                        }
                    }
                } else {
                    // 普通闹钟配置变更
                    CallbackDispatcher.shared.dispatch { [weak self] in
                        guard let self = self else { return }
                        self.delegate?.blueSDK(self, didUpdateAlarm: alarm)
                    }
                }
            }

        case DPIDConstants.alarmRecord:
            if let record = MedicationManager.parseMedicationRecord(from: data) {
                CallbackDispatcher.shared.dispatch { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.blueSDK(self, didReceiveMedicationRecord: record)
                }
            }

        case DPIDConstants.typeOfSound:
            if let soundType = AudioManager.parseSoundType(from: data) {
                CallbackDispatcher.shared.dispatch { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.blueSDK(self, didChangeSoundType: soundType)
                }
            }

        case DPIDConstants.timeFormat:
            if let format = AudioManager.parseTimeFormat(from: data) {
                CallbackDispatcher.shared.dispatch { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.blueSDK(self, didChangeTimeFormat: format)
                }
            }

        case DPIDConstants.lowBat:
            logger.info("设备上报低电状态")
            CallbackDispatcher.shared.dispatch { [weak self] in
                guard let self = self else { return }
                self.delegate?.blueSDKDidReportLowBattery(self)
            }

        default:
            logger.debug("未处理的上报 DPID：\(String(format: "0x%02X", dpid))")
        }
    }
}
