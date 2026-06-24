// CommandQueue.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 指令串行队列：同一时刻只允许一条指令在等待应答（ARCH-04）
// 超时 5 秒自动重试，最多重试 3 次（NFR02）
// 支持多指令排队，按 FIFO 顺序依次发送

import Foundation

/// 待执行指令
private struct PendingCommand {
    let cmd: UInt8
    let frame: [UInt8]
    let retryCount: Int
    let maxRetries: Int
    let timeout: TimeInterval
    let completion: (Result<ParsedFrame, BlueError>) -> Void
}

/// 指令串行队列
/// 管理下行指令的发送、超时重试和应答匹配
final class CommandQueue {

    // MARK: - 配置

    static let defaultTimeout: TimeInterval = 5.0
    static let defaultMaxRetries: Int = 3

    // MARK: - 状态

    private var pendingCommand: PendingCommand?   // 当前正在等待应答的指令
    private var waitingQueue: [PendingCommand] = [] // 等待发送的指令队列
    private var timeoutTimer: Timer?
    private let lock = NSLock()

    /// 发送指令的实际执行块（由 BLEConnector 注入）
    var sendBlock: (([UInt8]) -> Void)?

    /// 直接发送帧数据，不入队等待应答（用于单向下发指令如时间同步）
    func sendDirect(frame: [UInt8]) {
        sendBlock?(frame)
    }

    // MARK: - 入队

    /// 将指令加入队列
    /// - Parameters:
    ///   - cmd: 命令字
    ///   - frame: 完整帧数据
    ///   - timeout: 超时时间，默认 5 秒
    ///   - maxRetries: 最大重试次数，默认 3 次
    ///   - completion: 完成回调
    func enqueue(
        cmd: UInt8,
        frame: [UInt8],
        timeout: TimeInterval = defaultTimeout,
        maxRetries: Int = defaultMaxRetries,
        completion: @escaping (Result<ParsedFrame, BlueError>) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }

        let command = PendingCommand(
            cmd: cmd,
            frame: frame,
            retryCount: 0,
            maxRetries: maxRetries,
            timeout: timeout,
            completion: completion
        )

        if pendingCommand == nil {
            // 队列空闲，直接发送
            pendingCommand = command
            send(command)
        } else {
            // 有指令在等待，加入等待队列
            waitingQueue.append(command)
        }
    }

    // MARK: - 应答处理

    /// 处理设备应答帧
    @discardableResult
    func handleResponse(_ frame: ParsedFrame) -> Bool {
        lock.lock()

        guard let pending = pendingCommand else {
            lock.unlock()
            return false
        }

        // CMD 匹配：应答帧 CMD == 发送帧 CMD + 1 或相同
        let cmdMatch = frame.cmd == pending.cmd + 1 || frame.cmd == pending.cmd
        guard cmdMatch else {
            lock.unlock()
            return false
        }

        // 对于 sendCommand(0x06) 的应答(0x07)，还需匹配 DPID（数据第一字节）
        // 避免设备主动上报帧（如低电 0x75）被错误匹配
        if pending.cmd == CommandCode.sendCommand, frame.cmd == CommandCode.deviceReport {
            let pendingDPID = pending.frame.count > Int(FrameConstants.dataOffset)
                ? pending.frame[Int(FrameConstants.dataOffset)]
                : nil
            let responseDPID = frame.data.first
            if let pDPID = pendingDPID, let rDPID = responseDPID, pDPID != rDPID {
                lock.unlock()
                return false
            }
        }

        cancelTimeout()
        pendingCommand = nil
        // 先释放锁，再调用 completion（防止 completion 内再次 enqueue 导致死锁）
        lock.unlock()

        pending.completion(.success(frame))

        // 发送队列中的下一条指令
        lock.lock()
        sendNext()
        lock.unlock()
        return true
    }

    /// 清空队列，取消所有待处理指令
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cancelTimeout()
        pendingCommand?.completion(.failure(.disconnected))
        pendingCommand = nil
        waitingQueue.forEach { $0.completion(.failure(.disconnected)) }
        waitingQueue.removeAll()
    }

    // MARK: - 私有方法

    private func send(_ command: PendingCommand) {
        guard let block = sendBlock else {
            // 没有连接，立即回调 Disconnected 错误
            pendingCommand = nil
            command.completion(.failure(.disconnected))
            sendNext()
            return
        }
        block(command.frame)
        scheduleTimeout(for: command)
    }

    private func sendNext() {
        guard !waitingQueue.isEmpty else { return }
        let next = waitingQueue.removeFirst()
        pendingCommand = next
        // 指令间隔至少 200ms，避免设备来不及处理
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.send(next)
        }
    }

    private func scheduleTimeout(for command: PendingCommand) {
        cancelTimeout()
        timeoutTimer = Timer.scheduledTimer(
            withTimeInterval: command.timeout,
            repeats: false
        ) { [weak self] _ in
            self?.handleTimeout()
        }
    }

    private func handleTimeout() {
        lock.lock()
        guard let command = pendingCommand else {
            lock.unlock()
            return
        }

        if command.retryCount < command.maxRetries {
            let retried = PendingCommand(
                cmd: command.cmd,
                frame: command.frame,
                retryCount: command.retryCount + 1,
                maxRetries: command.maxRetries,
                timeout: command.timeout,
                completion: command.completion
            )
            pendingCommand = retried
            lock.unlock()
            send(retried)
        } else {
            pendingCommand = nil
            lock.unlock()
            command.completion(.failure(.timeout))
            // 继续发送队列中的下一条
            lock.lock()
            sendNext()
            lock.unlock()
        }
    }

    private func cancelTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
}
