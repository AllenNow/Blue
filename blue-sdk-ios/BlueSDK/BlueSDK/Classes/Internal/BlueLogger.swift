// BlueLogger.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// SDK 日志系统
// 支持日志级别控制和自定义日志处理器（FR34、FR35）
// 密钥值在任何级别下均不输出明文（FR36）

import Foundation
import os.log

/// 日志处理器类型
/// - Parameters:
///   - level: 日志级别
///   - tag: 标签
///   - message: 脱敏后的消息内容
public typealias BlueLogHandler = (_ level: LogLevel, _ tag: String, _ message: String) -> Void

/// SDK 日志系统
final class BlueLogger {

    // MARK: - 单例

    static let shared = BlueLogger()
    private init() {}

    // MARK: - 配置

    /// 当前日志级别，默认 none（关闭）
    var logLevel: LogLevel = .none

    /// 自定义日志处理器，nil 时使用默认输出
    var logHandler: BlueLogHandler?

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

    // MARK: - 内部实现

    private func log(level: LogLevel, tag: String, message: String) {
        guard level <= logLevel else { return }

        let formatted = LogFormatter.format(level: level, tag: tag, message: message)

        if let handler = logHandler {
            handler(level, tag, LogFormatter.sanitize(message))
        } else {
            // 默认使用 os_log 输出
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
