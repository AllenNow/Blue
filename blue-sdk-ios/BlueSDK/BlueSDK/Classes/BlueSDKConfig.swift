// BlueSDKConfig.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// SDK 初始化配置
// 通过 BlueSDK.shared.initialize(config:) 传入

import Foundation

/// SDK 语言设置
/// - system: 跟随系统语言（默认）
/// - zh: 强制中文
/// - en: 强制英文
public enum BlueSDKLanguage {
    case system, zh, en
}

/// SDK 初始化配置
public struct BlueSDKConfig {

    public var fixedAuthKey: String?
    public var logLevel: LogLevel
    public var autoAuthEnabled: Bool
    public var autoReconnect: Bool
    public var maxReconnectAttempts: Int
    public var language: BlueSDKLanguage

    public init(
        fixedAuthKey: String? = nil,
        logLevel: LogLevel = .debug,
        autoAuthEnabled: Bool = true,
        autoReconnect: Bool = true,
        maxReconnectAttempts: Int = 5,
        language: BlueSDKLanguage = .system
    ) {
        self.fixedAuthKey = fixedAuthKey
        self.logLevel = logLevel
        self.autoAuthEnabled = autoAuthEnabled
        self.autoReconnect = autoReconnect
        self.maxReconnectAttempts = maxReconnectAttempts
        self.language = language
    }
}

/// SDK 内部语言判断工具
/// 默认跟随系统，可通过 config.language 覆盖
public enum SDKLocale {
    private static var forced: BlueSDKLanguage = .system

    internal static func setLanguage(_ language: BlueSDKLanguage) {
        forced = language
    }

    /// 当前是否使用中文
    public static var isZh: Bool {
        switch forced {
        case .zh: return true
        case .en: return false
        case .system:
            let lang = Locale.preferredLanguages.first ?? "en"
            return lang.hasPrefix("zh")
        }
    }

    /// 便利方法
    public static func s(_ zh: String, _ en: String) -> String {
        return isZh ? zh : en
    }
}
