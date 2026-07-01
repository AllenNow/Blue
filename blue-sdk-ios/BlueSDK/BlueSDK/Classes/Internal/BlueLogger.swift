// BlueLogger.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// SDK 日志系统
// 支持日志级别控制、自定义日志处理器（FR34、FR35）、日志导出（Story 10.4）
// 密钥值在任何级别下均不输出明文（FR36）

import Foundation
import os.log

/// 日志处理器类型
public typealias BlueLogHandler = (_ level: LogLevel, _ tag: String, _ message: String) -> Void

/// SDK 日志系统
final class BlueLogger {

    // MARK: - 单例

    static let shared = BlueLogger()
    private init() {}

    // MARK: - 配置

    /// 当前日志级别，默认 none（关闭）
    var logLevel: LogLevel = .none

    /// 是否输出原始帧日志（TX/RX），默认 false
    var rawFrameLogEnabled: Bool = false

    /// 自定义日志处理器，nil 时使用默认输出
    var logHandler: BlueLogHandler?

    // MARK: - 环形日志缓冲区（Story 10.4）

    private let bufferCapacity = 1000
    private var logBuffer: [String] = []
    private let bufferLock = NSLock()

    // MARK: - 日志方法

    func error(_ message: String, tag: String = "BlueSDK") {
        log(level: .error, tag: tag, message: message)
    }

    func warn(_ message: String, tag: String = "BlueSDK") {
        log(level: .warn, tag: tag, message: message)
    }

    func info(_ message: String, tag: String = "BlueSDK") {
        log(level: .info, tag: tag, message: message)
    }

    func debug(_ message: String, tag: String = "BlueSDK") {
        log(level: .debug, tag: tag, message: message)
    }

    // MARK: - 日志导出（Story 10.4）

    /// 导出最近的日志记录
    /// - Parameter maxLines: 最大导出行数，默认全部（最多 1000 条）
    /// - Returns: 日志文本，每行一条，含时间戳、级别、标签、消息
    func exportLog(maxLines: Int? = nil) -> String {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        let lines = maxLines.map { Array(logBuffer.suffix($0)) } ?? logBuffer
        let header = """
        === BlueSDK Log Export ===
        SDK Version: 0.2.0
        Export Time: \(ISO8601DateFormatter().string(from: Date()))
        Log Level: \(logLevel)
        Entries: \(lines.count)
        ===========================
        
        """
        return header + lines.joined(separator: "\n")
    }

    /// 清空日志缓冲区
    func clearLogBuffer() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        logBuffer.removeAll()
    }

    /// 当前缓冲区中的日志条数
    var logBufferCount: Int {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return logBuffer.count
    }

    // MARK: - 内部实现

    private func log(level: LogLevel, tag: String, message: String) {
        guard level <= logLevel else { return }

        let sanitized = LogFormatter.sanitize(message)
        let formatted = LogFormatter.format(level: level, tag: tag, message: message)

        // 写入环形缓冲区
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(formatted)"
        bufferLock.lock()
        logBuffer.append(entry)
        if logBuffer.count > bufferCapacity {
            logBuffer.removeFirst()
        }
        bufferLock.unlock()

        // 输出到处理器或 os_log
        if let handler = logHandler {
            handler(level, tag, sanitized)
        } else {
            os_log("%{public}@", log: .default, type: osLogType(for: level), formatted)
        }
    }

    private func osLogType(for level: LogLevel) -> OSLogType {
        switch level {
        case .none:  return .default
        case .error: return .error
        case .warn:  return .default
        case .info:  return .info
        case .debug: return .debug
        }
    }
}
