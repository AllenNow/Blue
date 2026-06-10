// BlueSDK.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// SDK 公开 API 入口（单例）
// 所有公开 API 通过此类访问，支持 Swift 和 Objective-C 调用

import Foundation
import CoreBluetooth

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
    private var centralManager: CBCentralManager?

    // MARK: - 公开回调

    @objc public weak var delegate: BlueSDKDelegate?

    private override init() {
        super.init()
        setupConnectionManager()
    }

    // MARK: - 生命周期（FR32、FR33）

    /// 初始化 SDK（耗时 ≤ 100ms，NFR04）
    @objc public func initialize() {
        guard !isInitialized else { return }
        isInitialized = true
        centralManager = CBCentralManager(delegate: nil, queue: nil)
        let queue = connectionManager.getCommandQueue()
        authManager       = AuthManager(commandQueue: queue)
        deviceManager     = DeviceManager(commandQueue: queue)
        alarmManager      = AlarmManager(commandQueue: queue)
        medicationManager = MedicationManager(commandQueue: queue)
        audioManager      = AudioManager(commandQueue: queue)
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

    /// 开始扫描 LX-PD02 设备（FR01）
    /// - Parameters:
    ///   - onDeviceFound: 发现设备回调（主线程），返回 ScannedDevice
    ///   - onError: 错误回调（主线程）
    public func startScan(
        onDeviceFound: @escaping (ScannedDevice) -> Void,
        onError: @escaping (BlueError) -> Void
    ) {
        guard requireInitialized(callback: onError) else { return }
        scanner.startScan(onDeviceFound: onDeviceFound, onError: onError)
    }

    /// 停止扫描（FR01）
    @objc public func stopScan() {
        scanner.stopScan()
    }

    /// 连接指定设备（FR02）
    /// - Parameters:
    ///   - device: 由 startScan 回调返回的 ScannedDevice
    public func connect(_ device: ScannedDevice) {
        guard requireInitialized(callback: { _ in }) else { return }
        guard let central = centralManager else {
            logger.error("CBCentralManager 未初始化，请先调用 initialize()")
            return
        }
        connectionManager.connect(peripheral: device.peripheral, centralManager: central)
    }

    /// 断开连接（FR03）
    @objc public func disconnect() {
        requireInitialized { _ in }
        connectionManager.disconnect()
    }

    // MARK: - 认证（Epic 3）

    /// 发送密钥包完成设备认证（FR08）
    /// - Parameters:
    ///   - phoneMac: 手机 MAC 地址（6字节）
    ///   - deviceMac: 设备 MAC 地址（6字节）
    ///   - completion: 认证结果回调（主线程）
    public func authenticate(
        phoneMac: [UInt8],
        deviceMac: [UInt8],
        completion: @escaping (Result<Void, BlueError>) -> Void
    ) {
        guard requireInitialized(callback: { completion(.failure($0)) }) else { return }
        authManager?.authenticate(phoneMac: phoneMac, deviceMac: deviceMac) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.connectionManager.transitionTo(.authenticated)
                CallbackDispatcher.shared.dispatch {
                    self.delegate?.blueSDK?(self, didAuthenticateWithSuccess: true, error: .authFailed)
                }
                completion(.success(()))
            case .failure(let error):
                if error == .authFailed {
                    self.connectionManager.disconnect()
                    CallbackDispatcher.shared.dispatch {
                        self.delegate?.blueSDK?(self, didAuthenticateWithSuccess: false, error: error)
                    }
                }
                completion(.failure(error))
            }
        }
    }

    // MARK: - 设备信息与时间同步（Epic 4）

    /// 查询设备信息（FR12）
    public func queryDeviceInfo(completion: @escaping (Result<DeviceInfo, BlueError>) -> Void) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
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

    // MARK: - 用药事件（Epic 6）

    /// 下发用药结果通知（FR24）
    public func sendMedicationNotification(
        status: UInt8,
        completion: @escaping (Result<Void, BlueError>) -> Void
    ) {
        guard requireInitialized(callback: { completion(.failure($0)) }),
              requireAuthenticated(callback: { completion(.failure($0)) }) else { return }
        medicationManager?.sendMedicationNotification(status: status, completion: completion)
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

    // MARK: - 连接管理器事件处理

    private func setupConnectionManager() {
        connectionManager.onStateChanged = { [weak self] state in
            guard let self = self else { return }
            self.delegate?.blueSDK?(self, didChangeConnectionState: state)
        }

        connectionManager.onDataReceived = { [weak self] frame in
            self?.handleIncomingFrame(frame)
        }
    }

    private func handleIncomingFrame(_ frame: ParsedFrame) {
        guard let dpid = frame.data.first else { return }

        switch frame.cmd {
        case CommandCode.timeSync:
            CallbackDispatcher.shared.dispatch { [weak self] in
                guard let self = self else { return }
                self.delegate?.blueSDKDidRequestTimeSync?(self)
            }

        case CommandCode.deviceReport:
            handleDeviceReport(dpid: dpid, data: frame.data)

        default:
            break
        }
    }

    private func handleDeviceReport(dpid: UInt8, data: [UInt8]) {
        switch dpid {
        case DPIDConstants.alarm1...DPIDConstants.alarm7:
            let index = Int(dpid - DPIDConstants.alarm1) + 1
            // 0x68（alarm3）同时用于用药事件上报，通过 byte10 状态值区分
            if dpid == DPIDConstants.alarm3, data.count >= 11 {
                let statusByte = data[10]
                if let alarm = AlarmManager.parseAlarmInfo(from: data, index: index) {
                    switch statusByte {
                    case 0x00: // 响铃开始（FR20）
                        CallbackDispatcher.shared.dispatch { [weak self] in
                            guard let self = self else { return }
                            self.delegate?.blueSDK?(self, didAlarmRinging: index, alarmInfo: alarm)
                        }
                    case 0x01: // 超时未取药（FR21）
                        CallbackDispatcher.shared.dispatch { [weak self] in
                            guard let self = self else { return }
                            self.delegate?.blueSDK?(self, didAlarmTimeout: index, alarmInfo: alarm)
                        }
                    default: // 用药结果（FR22）
                        if let status = MedicationStatus.from(byte: statusByte) {
                            CallbackDispatcher.shared.dispatch { [weak self] in
                                guard let self = self else { return }
                                self.delegate?.blueSDK?(self, didReceiveMedicationResult: index, status: status)
                            }
                        }
                    }
                }
            } else if let alarm = AlarmManager.parseAlarmInfo(from: data, index: index) {
                // 普通闹钟配置上报（FR18）
                CallbackDispatcher.shared.dispatch { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.blueSDK?(self, didUpdateAlarm: alarm)
                }
            }

        case DPIDConstants.alarmRecord:
            if let record = MedicationManager.parseMedicationRecord(from: data) {
                CallbackDispatcher.shared.dispatch { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.blueSDK?(self, didReceiveMedicationRecord: record)
                }
            }

        case DPIDConstants.typeOfSound:
            if let soundType = AudioManager.parseSoundType(from: data) {
                CallbackDispatcher.shared.dispatch { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.blueSDK?(self, didChangeSoundType: soundType)
                }
            }

        case DPIDConstants.timeFormat:
            if let format = AudioManager.parseTimeFormat(from: data) {
                CallbackDispatcher.shared.dispatch { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.blueSDK?(self, didChangeTimeFormat: format)
                }
            }

        default:
            logger.debug("未处理的上报 DPID：\(String(format: "0x%02X", dpid))")
        }
    }
}
