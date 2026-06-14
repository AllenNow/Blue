// BlueSDKConfig.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// SDK 初始化配置
// 通过 BlueSDK.shared.initialize(config:) 传入

import Foundation

/// SDK 初始化配置
/// 使用 struct 确保值语义和线程安全
///
/// 使用示例：
/// ```swift
/// let config = BlueSDKConfig(fixedAuthKey: "05FA")
/// BlueSDK.shared.initialize(config: config)
/// ```
public struct BlueSDKConfig {

    /// 固定认证密钥（4字符十六进制字符串，如 "05FA"）。
    /// 设置后连接时优先使用此密钥，为 nil 则自动计算密钥。
    public var fixedAuthKey: String?

    /// 日志级别，默认 DEBUG
    public var logLevel: LogLevel

    /// 是否在连接成功后自动执行认证，默认 true
    public var autoAuthEnabled: Bool

    /// 创建配置
    /// - Parameters:
    ///   - fixedAuthKey: 固定认证密钥（可选，4字符十六进制字符串）
    ///   - logLevel: 日志级别（默认 .debug）
    ///   - autoAuthEnabled: 是否自动认证（默认 true）
    public init(
        fixedAuthKey: String? = nil,
        logLevel: LogLevel = .debug,
        autoAuthEnabled: Bool = true
    ) {
        self.fixedAuthKey = fixedAuthKey
        self.logLevel = logLevel
        self.autoAuthEnabled = autoAuthEnabled
    }
}
