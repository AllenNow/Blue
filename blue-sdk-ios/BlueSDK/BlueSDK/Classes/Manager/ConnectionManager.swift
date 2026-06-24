// ConnectionManager.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 连接状态机：管理 5 个连接状态的转换（ARCH-07）
// 状态：DISCONNECTED → CONNECTING → CONNECTED → AUTHENTICATED → RECONNECTING
// 使用 BLECentralManager 单例，无需外部传入 CBCentralManager

import Foundation
import CoreBluetooth

/// 连接管理器
/// 维护连接状态机，处理连接、断开、自动重连逻辑
final class ConnectionManager {

    // MARK: - 重连配置

    private static let reconnectDelays: [TimeInterval] = [2, 4, 8]
    private static let maxReconnectAttempts = 5

    // MARK: - 状态

    private(set) var state: ConnectionState = .disconnected {
        didSet {
            guard state != oldValue else { return }
            logger.info(SDKLocale.s("连接状态变更：\(oldValue) → \(state)", "State changed: \(oldValue) → \(state)", "Status geändert: \(oldValue) → \(state)"))
            notifyStateChange(state)
        }
    }

    private var reconnectAttempts = 0
    private var reconnectTimer: Timer?
    private var targetPeripheral: CBPeripheral?

    private let connector = BLEConnector()
    private let commandQueue = CommandQueue()
    private let streamParser = StreamFrameParser()
    private let logger = BlueLogger.shared

    // MARK: - 回调

    var onStateChanged: ((ConnectionState) -> Void)?
    var onError: ((BlueError) -> Void)?
    var onDataReceived: ((ParsedFrame) -> Void)?
    var onReconnecting: ((_ attempt: Int, _ maxAttempts: Int) -> Void)?
    var onReconnectFailed: (() -> Void)?

    // MARK: - 初始化

    init() {
        connector.delegate = self
        commandQueue.sendBlock = { [weak self] bytes in
            self?.connector.write(bytes)
        }
        streamParser.onFrameParsed = { [weak self] frame in
            self?.handleParsedFrame(frame)
        }
    }

    // MARK: - 公开方法

    /// 连接超时定时器
    private var connectTimeoutTimer: Timer?
    private static let connectTimeout: TimeInterval = 15

    /// 连接指定设备（使用 BLECentralManager 单例）
    func connect(peripheral: CBPeripheral) {
        guard state == .disconnected else {
            logger.warn(SDKLocale.s("当前状态 \(state) 不允许发起连接", "Cannot connect in state \(state)", "Verbindung im Status \(state) nicht möglich"))
            return
        }
        self.targetPeripheral = peripheral
        transitionTo(.connecting)
        connector.connect(peripheral: peripheral)
        scheduleConnectTimeout()
    }

    /// 主动断开连接（不触发自动重连）
    func disconnect() {
        cancelConnectTimeout()
        cancelReconnect()
        reconnectAttempts = 0
        connector.disconnect()
        commandQueue.clear()
        streamParser.reset()
        transitionTo(.disconnected)
    }

    private func scheduleConnectTimeout() {
        cancelConnectTimeout()
        connectTimeoutTimer = Timer.scheduledTimer(withTimeInterval: ConnectionManager.connectTimeout, repeats: false) { [weak self] _ in
            guard let self = self, self.state == .connecting else { return }
            self.logger.error(SDKLocale.s("连接超时（\(Int(ConnectionManager.connectTimeout))秒），中止连接", "Connection timeout (\(Int(ConnectionManager.connectTimeout))s), aborting", "Verbindungs-Timeout (\(Int(ConnectionManager.connectTimeout))s), Abbruch"))
            self.connector.disconnect()
            self.transitionTo(.disconnected)
            CallbackDispatcher.shared.dispatch {
                self.onError?(.timeout)
            }
        }
    }

    private func cancelConnectTimeout() {
        connectTimeoutTimer?.invalidate()
        connectTimeoutTimer = nil
    }

    /// 获取指令队列（供 Manager 层使用）
    func getCommandQueue() -> CommandQueue {
        return commandQueue
    }

    // MARK: - 状态机（ARCH-07：所有状态变更通过此方法）

    func transitionTo(_ newState: ConnectionState) {
        state = newState
    }

    // MARK: - 私有方法

    private func notifyStateChange(_ state: ConnectionState) {
        CallbackDispatcher.shared.dispatch { [weak self] in
            self?.onStateChanged?(state)
        }
    }

    private func startReconnect() {
        guard reconnectAttempts < ConnectionManager.maxReconnectAttempts else {
            logger.warn(SDKLocale.s("重连次数已达上限（\(ConnectionManager.maxReconnectAttempts)次），停止重连", "Max reconnect attempts (\(ConnectionManager.maxReconnectAttempts)) reached", "Max. Wiederverbindungsversuche (\(ConnectionManager.maxReconnectAttempts)) erreicht"))
            transitionTo(.disconnected)
            CallbackDispatcher.shared.dispatch { [weak self] in
                self?.onReconnectFailed?()
                self?.onError?(.disconnected)
            }
            return
        }

        let delayIndex = min(reconnectAttempts, ConnectionManager.reconnectDelays.count - 1)
        let delay = ConnectionManager.reconnectDelays[delayIndex]
        reconnectAttempts += 1

        logger.info(SDKLocale.s("第 \(reconnectAttempts) 次重连，\(delay) 秒后尝试", "Reconnect attempt \(reconnectAttempts), retrying in \(delay)s", "Wiederverbindung \(reconnectAttempts), erneut in \(delay)s"))
        transitionTo(.reconnecting)
        CallbackDispatcher.shared.dispatch { [weak self] in
            self?.onReconnecting?(self?.reconnectAttempts ?? 0, ConnectionManager.maxReconnectAttempts)
        }

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self,
                  let peripheral = self.targetPeripheral else { return }
            self.connector.connect(peripheral: peripheral)
        }
    }

    /// 取消正在进行的自动重连
    func cancelReconnection() {
        guard state == .reconnecting else { return }
        logger.info("手动取消重连")
        cancelReconnect()
        reconnectAttempts = 0
        transitionTo(.disconnected)
    }

    private func cancelReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
}

// MARK: - BLEConnectorDelegate

extension ConnectionManager: BLEConnectorDelegate {

    func bleConnectorDidConnect() {
        cancelConnectTimeout()
        reconnectAttempts = 0
        cancelReconnect()
        transitionTo(.connected)
    }

    func bleConnectorDidDisconnect(error: Error?) {
        commandQueue.clear()

        // 主动断开时状态已为 disconnected，不触发重连
        guard state != .disconnected else { return }

        if error != nil {
            // 意外断开，触发自动重连
            startReconnect()
        } else {
            transitionTo(.disconnected)
        }
    }

    func bleConnectorDidReceiveData(_ data: Data) {
        // 通过流式解析器处理（自动处理粘包/分包）
        streamParser.receive(data)
    }

    // MARK: - 帧处理

    private func handleParsedFrame(_ frame: ParsedFrame) {
        // 时间同步帧（CMD=0xE1）始终作为上报处理
        if frame.cmd == CommandCode.timeSync {
            onDataReceived?(frame)
            return
        }

        // CMD=0x07 的帧可能是指令应答，也可能是设备主动上报
        // 先尝试 CommandQueue 匹配，匹配成功说明是应答；匹配失败则作为上报处理
        if !commandQueue.handleResponse(frame) {
            onDataReceived?(frame)
        }
    }
}
