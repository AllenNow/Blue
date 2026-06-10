// LogLevel.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 日志级别枚举

import Foundation

/// SDK 日志级别
@objc public enum LogLevel: Int, Comparable {
    /// 关闭所有日志（默认）
    case none = 0
    /// 仅错误日志
    case error = 1
    /// 警告及以上
    case warn = 2
    /// 信息及以上
    case info = 3
    /// 调试及以上（输出原始帧数据）
    case debug = 4

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
