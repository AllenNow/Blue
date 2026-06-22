// BlueDeviceConnection.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 单设备连接实例：封装一个设备的完整连接生命周期
// 包含独立的 ConnectionManager、AuthManager、CommandQueue 及所有业务 Manager
// 多设备模式下，每个已连接设备对应一个 BlueDeviceConnection 实例

import Foundation
import CoreBluetooth

/// 单设备连接代理 — 将设备事件向上传递给 BlueSDK 多设备管理器
protocol BlueDeviceConnectionDelegate: AnyObject {
    func deviceConnection(_ connection: BlueDeviceConnection, didChangeState state: ConnectionState)
    func deviceConnection(_ connection: BlueDeviceConnection, didAuthenticateWithSuccess success: Bool, error: BlueError?)
    func deviceConnection(_ connection: BlueDeviceConnection, didEncounterError error: BlueError)
    func deviceConnection(_ connection: BlueDeviceConnection, didStartReconnecting attempt: Int, maxAttempts: Int)
    func deviceConnectionDidFailReconnection(_ connection: BlueDeviceConnection)
    func deviceConnection(_ connection: BlueDeviceConnection, didReceiveFrame frame: ParsedFrame)
}

/// 单设备连接实例
/// 封装一个 LX-PD02 设备的完整连接、认证、指令队列及所有业务能力
public final class BlueDeviceConnection {

    // MARK: - 公开属性

    /// 设备唯一标识（UUID 字符串）
    public let deviceId: String

    /// 设备名称（广播名）
    public let deviceName: String

    /// 当前连接状态
    public var connectionState: ConnectionState {
        return connectionManager.state
    }

    /// 当前设备时间格式（设备上报后自动更新，默认 24H）
    public private(set) var currentTimeFormat: TimeFormat = .hour24

    // MARK: - 内部组件

    internal let connectionManager: ConnectionManager
    internal let authManager: AuthManager
    internal let deviceManager: DeviceManager
    internal let alarmManager: AlarmManager
    internal let medicationManager: MedicationManager
    internal let audioManager: AudioManager

    private let peripheral: CBPeripheral
    private let logger = BlueLogger.shared
    private var lastTimeSyncDate: Date?

    weak var delegate: BlueDeviceConnectionDelegate?

    // MARK: - 认证配置（从 BlueSDK 配置继承）

    internal var config: BlueSDKConfig

    // MARK: - 初始化

    internal init(device: ScannedDevice, config: BlueSDKConfig) {
        self.deviceId = device.deviceId
        self.deviceName = device.deviceName
        self.peripheral = device.peripheral
        self.config = config

        self.connectionManager = ConnectionManager()
        let queue = connectionManager.getCommandQueue()
        self.authManager = AuthManager(commandQueue: queue)
        self.deviceManager = DeviceManager(commandQueue: queue)
        self.alarmManager = AlarmManager(commandQueue: queue)
        self.medicationManager = MedicationManager(commandQueue: queue)
        self.audioManager = AudioManager(commandQueue: queue)

        setupConnectionManager()
    }

    /// 通过 peripheral + identifier 直接构造（用于 retrievePeripherals 恢复场景）
    internal init(peripheral: CBPeripheral, config: BlueSDKConfig) {
        self.deviceId = peripheral.identifier.uuidString
        self.deviceName = peripheral.name ?? "Unknown"
        self.peripheral = peripheral
        self.config = config

        self.connectionManager = ConnectionManager()
        let queue = connectionManager.getCommandQueue()
        self.authManager = AuthManager(commandQueue: queue)
        self.deviceManager = DeviceManager(commandQueue: queue)
        self.alarmManager = AlarmManager(commandQueue: queue)
        self.medicationManager = MedicationManager(commandQueue: queue)
        self.audioManager = AudioManager(commandQueue: queue)

        setupConnectionManager()
    }

    // MARK: - 连接管理

    /// 发起连接
    internal func connect() {
        connectionManager.connect(peripheral: peripheral)
    }

    /// 主动断开
    internal func disconnect() {
        connectionManager.disconnect()
    }

    /// 取消自动重连
    internal func cancelReconnection() {
        connectionManager.cancelReconnection()
    }

    // MARK: - 认证

    /// 自动认证（连接成功后内部调用）
    internal func autoAuthenticate(phoneMacProvider: () -> [UInt8]) {
        guard config.autoAuthEnabled else {
            logger.debug("[\(deviceName)] 自动认证已禁用")
            return
        }

        logger.info("[\(deviceName)] 连接成功，发起密钥认证...")

        // 固定密钥模式
        if let fixedKey = config.fixedAuthKey, fixedKey.count == 4,
           let keyHigh = UInt8(fixedKey.prefix(2), radix: 16),
           let keyLow = UInt8(fixedKey.suffix(2), radix: 16) {
            let keyBytes: [UInt8] = [keyHigh, keyLow]
            logger.debug("[\(deviceName)] 使用固定密钥认证")
            let frame = FrameBuilder.build(cmd: CommandCode.authKey, data: keyBytes)
            connectionManager.getCommandQueue().enqueue(cmd: CommandCode.authKey, frame: frame) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    if response.data.first == 0x01 {
                        self.connectionManager.transitionTo(.authenticated)
                        self.logger.info("[\(self.deviceName)] 认证成功（固定密钥）")
                        self.delegate?.deviceConnection(self, didAuthenticateWithSuccess: true, error: nil)
                    } else {
                        self.logger.error("[\(self.deviceName)] 固定密钥认证失败")
                        self.connectionManager.disconnect()
                        self.delegate?.deviceConnection(self, didAuthenticateWithSuccess: false, error: .authFailed)
                    }
                case .failure(let error):
                    self.logger.error("[\(self.deviceName)] 认证指令发送失败：\(error)")
                }
            }
            return
        }

        // 自动计算模式
        let phoneMac = phoneMacProvider()
        let deviceMac = getDeviceMac()
        performAuth(phoneMac: phoneMac, deviceMac: deviceMac)
    }

    /// 手动密钥认证
    internal func authenticateWithKey(keyHigh: UInt8, keyLow: UInt8, completion: @escaping (Result<Void, BlueError>) -> Void) {
        let keyBytes: [UInt8] = [keyHigh, keyLow]
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

    // MARK: - 业务 API（全部要求已认证）

    /// 查询设备信息
    public func queryDeviceInfo(completion: @escaping (Result<DeviceInfo, BlueError>) -> Void) {
        guard requireAuthenticated(completion: completion) else { return }
        deviceManager.queryDeviceInfo(completion: completion)
    }

    /// 时间同步
    public func syncTime(date: Date = Date(), completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireAuthenticated(completion: completion) else { return }
        deviceManager.syncTime(date: date, completion: completion)
    }

    /// 设置闹钟
    public func setAlarm(index: Int, hour: Int, minute: Int, weekMask: Int = 0x7F, completion: @escaping (Result<AlarmInfo, BlueError>) -> Void) {
        guard requireAuthenticated(completion: completion) else { return }
        alarmManager.setAlarm(index: index, hour: hour, minute: minute, weekMask: weekMask, completion: completion)
    }

    /// 删除闹钟
    public func deleteAlarm(index: Int, completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireAuthenticated(completion: completion) else { return }
        alarmManager.deleteAlarm(index: index, completion: completion)
    }

    /// 清空所有闹钟
    public func clearAllAlarms(completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireAuthenticated(completion: completion) else { return }
        alarmManager.clearAllAlarms(completion: completion)
    }

    /// 查询闹钟
    public func queryAlarm(index: Int, completion: @escaping (Result<AlarmInfo, BlueError>) -> Void) {
        guard requireAuthenticated(completion: completion) else { return }
        alarmManager.queryAlarm(index: index, completion: completion)
    }

    /// 下发用药结果通知
    public func sendMedicationNotification(status: MedicationStatus, completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireAuthenticated(completion: completion) else { return }
        medicationManager.sendMedicationNotification(status: UInt8(status.rawValue), completion: completion)
    }

    /// 设置音量
    public func setVolume(_ level: VolumeLevel, completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireAuthenticated(completion: completion) else { return }
        audioManager.setVolume(level, completion: completion)
    }

    /// 设置铃声类型
    public func setSoundType(_ type: SoundType, completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireAuthenticated(completion: completion) else { return }
        audioManager.setSoundType(type, completion: completion)
    }

    /// 设置静音
    public func setSilence(_ enabled: Bool, completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireAuthenticated(completion: completion) else { return }
        audioManager.setSilence(enabled, completion: completion)
    }

    /// 设置提醒持续时长
    public func setAlertDuration(_ minutes: Int, completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireAuthenticated(completion: completion) else { return }
        audioManager.setAlertDuration(minutes, completion: completion)
    }

    /// 设置时间格式
    public func setTimeFormat(_ format: TimeFormat, completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireAuthenticated(completion: completion) else { return }
        audioManager.setTimeFormat(format) { [weak self] result in
            if case .success = result { self?.currentTimeFormat = format }
            completion(result)
        }
    }

    /// 恢复出厂设置
    public func restoreFactory(completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireAuthenticated(completion: completion) else { return }
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

    /// 发送原始指令
    public func sendRawData(data: [UInt8], completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard requireAuthenticated(completion: completion) else { return }
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

    /// 解绑设备
    public func clearBinding(completion: @escaping (Result<Void, BlueError>) -> Void) {
        let state = connectionManager.state
        if state == .authenticated || state == .connected {
            let frame = FrameBuilder.build(cmd: CommandCode.unbind)
            connectionManager.getCommandQueue().enqueue(cmd: CommandCode.unbind, frame: frame) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success:
                    self.connectionManager.disconnect()
                    self.logger.info("[\(self.deviceName)] 解绑成功")
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            logger.info("[\(deviceName)] 设备未连接，无需解绑")
            completion(.success(()))
        }
    }

    // MARK: - 内部工具

    @discardableResult
    private func requireAuthenticated<T>(completion: (Result<T, BlueError>) -> Void) -> Bool {
        guard connectionManager.state == .authenticated else {
            completion(.failure(.notAuthenticated))
            return false
        }
        return true
    }

    private func getDeviceMac() -> [UInt8] {
        let uuidBytes = withUnsafeBytes(of: peripheral.identifier.uuid) { Array($0) }
        return Array(uuidBytes.prefix(6))
    }

    private func performAuth(phoneMac: [UInt8], deviceMac: [UInt8]) {
        authManager.authenticate(phoneMac: phoneMac, deviceMac: deviceMac) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.connectionManager.transitionTo(.authenticated)
                self.logger.info("[\(self.deviceName)] 认证成功")
                self.delegate?.deviceConnection(self, didAuthenticateWithSuccess: true, error: nil)
            case .failure(let error):
                self.logger.error("[\(self.deviceName)] 认证失败：\(error.localizedDescription)")
                if error == .authFailed {
                    self.connectionManager.disconnect()
                }
                self.delegate?.deviceConnection(self, didAuthenticateWithSuccess: false, error: error)
            }
        }
    }

    // MARK: - ConnectionManager 事件绑定

    private func setupConnectionManager() {
        connectionManager.onStateChanged = { [weak self] state in
            guard let self = self else { return }
            self.delegate?.deviceConnection(self, didChangeState: state)
        }

        connectionManager.onError = { [weak self] error in
            guard let self = self else { return }
            self.delegate?.deviceConnection(self, didEncounterError: error)
        }

        connectionManager.onReconnecting = { [weak self] attempt, maxAttempts in
            guard let self = self else { return }
            self.delegate?.deviceConnection(self, didStartReconnecting: attempt, maxAttempts: maxAttempts)
        }

        connectionManager.onReconnectFailed = { [weak self] in
            guard let self = self else { return }
            self.delegate?.deviceConnectionDidFailReconnection(self)
        }

        connectionManager.onDataReceived = { [weak self] frame in
            guard let self = self else { return }
            self.handleIncomingFrame(frame)
        }
    }

    // MARK: - 帧处理（从 BlueSDK 移入）

    private func handleIncomingFrame(_ frame: ParsedFrame) {
        // 时间同步请求 — 节流 30 秒
        if frame.cmd == CommandCode.timeSync {
            let now = Date()
            if let last = lastTimeSyncDate, now.timeIntervalSince(last) < 30 {
                logger.debug("[\(deviceName)] 时间同步请求已节流")
            } else {
                lastTimeSyncDate = now
                logger.info("[\(deviceName)] 设备请求时间同步，自动下发")
                deviceManager.syncTime { _ in }
            }
        }

        // 上报帧统一转发给上层处理
        delegate?.deviceConnection(self, didReceiveFrame: frame)
    }
}
