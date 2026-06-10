// LogFormatter.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 日志脱敏处理器
// 密钥值和 MAC 地址在任何日志级别下均不输出明文（FR36、NFR07）

import Foundation

/// 日志脱敏处理器
/// 在日志输出前替换敏感信息
enum LogFormatter {

    /// 对日志消息进行脱敏处理
    /// 将密钥相关的十六进制字节序列替换为 ***
    /// - Parameter message: 原始日志消息
    /// - Returns: 脱敏后的消息
    static func sanitize(_ message: String) -> String {
        // 替换形如 "key: 0x07 0x74" 或 "authKey: 07 74" 的模式
        var result = message
        // 替换 "key" 相关字段后的十六进制值
        let patterns = [
            "(?i)(auth[_\\s]?key[:\\s]+)[0-9a-fA-F\\s]+",
            "(?i)(key[:\\s]+)[0-9a-fA-F\\s]{2,}",
            "(?i)(mac[:\\s]+)([0-9a-fA-F]{2}[:\\-\\s]){5}[0-9a-fA-F]{2}"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: range,
                    withTemplate: "$1***"
                )
            }
        }
        return result
    }

    /// 格式化日志输出字符串
    /// - Parameters:
    ///   - level: 日志级别
    ///   - tag: 标签
    ///   - message: 消息内容
    /// - Returns: 格式化后的日志字符串
    static func format(level: LogLevel, tag: String, message: String) -> String {
        let levelStr: String
        switch level {
        case .none:  levelStr = "NONE"
        case .error: levelStr = "ERROR"
        case .warn:  levelStr = "WARN"
        case .info:  levelStr = "INFO"
        case .debug: levelStr = "DEBUG"
        }
        let sanitized = sanitize(message)
        return "[BlueSDK][\(levelStr)][\(tag)] \(sanitized)"
    }
}
