// ConnectionManager.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 连接状态机：管理 5 个连接状态的转换（ARCH-07）
// 状态：DISCONNECTED → CONNECTING → CONNECTED → AUTHENTICATED → RECONNECTING

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
            logger.info("连接状态变更：\(oldValue) → \(state)")
            notifyStateChange(state)
        }
    }

    private var reconnectAttempts = 0
    private var reconnectTimer: Timer?
    private var targetPeripheral: CBPeripheral?
    private var centralManager: CBCentralManager?

    private let scanner = BLEScanner()
    private let connector = BLEConnector()
    private let commandQueue = CommandQueue()
    private let streamParser = StreamFrameParser()
    private let logger = BlueLogger.shared

    // MARK: - 回调

    var onStateChanged: ((ConnectionState) -> Void)?
    var onError: ((BlueError) -> Void)?
    var onDataReceived: ((ParsedFrame) -> Void)?

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

    /// 连接指定设备
    func connect(peripheral: CBPeripheral, centralManager: CBCentralManager) {
        guard state == .disconnected else {
            logger.warn("当前状态 \(state) 不允许发起连接")
            return
        }
        self.targetPeripheral = peripheral
        self.centralManager = centralManager
        transitionTo(.connecting)
        connector.connect(peripheral: peripheral, centralManager: centralManager)
    }

    /// 主动断开连接（不触发自动重连）
    func disconnect() {
        cancelReconnect()
        reconnectAttempts = 0
        connector.disconnect()
        commandQueue.clear()
        streamParser.reset()
        transitionTo(.disconnected)
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
            logger.warn("重连次数已达上限（\(ConnectionManager.maxReconnectAttempts)次），停止重连")
            transitionTo(.disconnected)
            CallbackDispatcher.shared.dispatch { [weak self] in
                self?.onError?(.disconnected)
            }
            return
        }

        let delayIndex = min(reconnectAttempts, ConnectionManager.reconnectDelays.count - 1)
        let delay = ConnectionManager.reconnectDelays[delayIndex]
        reconnectAttempts += 1

        logger.info("第 \(reconnectAttempts) 次重连，\(delay) 秒后尝试")
        transitionTo(.reconnecting)

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self,
                  let peripheral = self.targetPeripheral,
                  let central = self.centralManager else { return }
            self.connector.connect(peripheral: peripheral, centralManager: central)
        }
    }

    private func cancelReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
}

// MARK: - BLEConnectorDelegate

extension ConnectionManager: BLEConnectorDelegate {

    func bleConnectorDidConnect() {
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
        // 上报帧（CMD=0x07 或 0xE1）直接路由到事件分发器（ARCH-05）
        if frame.cmd == CommandCode.deviceReport || frame.cmd == CommandCode.timeSync {
            onDataReceived?(frame)
            return
        }

        // 应答帧尝试匹配指令队列
        if !commandQueue.handleResponse(frame) {
            // 未匹配到指令，作为上报处理
            onDataReceived?(frame)
        }
    }
}
