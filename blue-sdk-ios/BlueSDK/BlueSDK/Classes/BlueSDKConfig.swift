// BlueSDKConfig.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
// BlueSDK - LX-PD02 Smart Pill Box BLE SDK
//
// SDK 初始化配置
// SDK initialization configuration
//
// 通过 BlueSDKManager.shared.initialize(config:) 传入
// Pass via BlueSDKManager.shared.initialize(config:)

import Foundation

/// SDK 语言设置
/// SDK language setting
/// - system: 跟随系统语言（默认）/ Follow system language (default)
/// - zh: 强制中文 / Force Chinese
/// - en: 强制英文 / Force English
/// - de: 强制德语 / Force German
public enum BlueSDKLanguage {
    case system, zh, en, de
}

/// SDK 初始化配置
/// SDK initialization configuration
///
/// 使用示例 / Usage:
/// ```swift
/// let config = BlueSDKConfig(fixedAuthKey: "05FA")
/// BlueSDKManager.shared.initialize(config: config)
/// ```
public struct BlueSDKConfig {

    /// 固定认证密钥
    /// Fixed authentication key
    ///
    /// - 格式/Format: 4 位十六进制字符串（2 字节）/ 4-char hex string (2 bytes), e.g. "05FA"
    /// - 有效字符/Valid chars: 0-9, A-F, a-f
    /// - 长度/Length: 必须恰好 4 个字符，否则忽略 / Must be exactly 4 chars, ignored otherwise
    /// - 示例/Example: "05FA" → keyHigh=0x05, keyLow=0xFA
    /// - 设置后优先使用此密钥，为 nil 则自动计算
    /// - When set, this key takes priority; nil = auto-calculate
    public var fixedAuthKey: String?

    /// 日志级别，默认 DEBUG
    /// Log level, defaults to .debug
    public var logLevel: LogLevel

    /// 是否在连接成功后自动执行认证，默认 true
    /// Whether to auto-authenticate after connection, defaults to true
    public var autoAuthEnabled: Bool

    /// 断线后是否自动重连，默认 true
    /// Whether to auto-reconnect after disconnection, defaults to true
    public var autoReconnect: Bool

    /// 最大自动重连次数，默认 5
    /// Maximum auto-reconnect attempts, defaults to 5
    public var maxReconnectAttempts: Int

    /// SDK 语言设置
    /// SDK language setting
    public var language: BlueSDKLanguage

    /// 自定义 phoneMac（用于自动计算密钥时的手机标识）
    /// Custom phoneMac (phone identifier for auto key calculation)
    ///
    /// - 格式/Format: 12 位十六进制字符串（6 字节）/ 12-char hex string (6 bytes), e.g. "A1B2C3D4E5F6"
    /// - 有效字符/Valid chars: 0-9, A-F, a-f
    /// - 长度/Length: 必须恰好 12 个字符，否则忽略 / Must be exactly 12 chars, ignored otherwise
    /// - 设置后 SDK 使用此值，不再从 Keychain/UUID 自动生成
    /// - When set, SDK uses this value instead of auto-generating from Keychain/UUID
    public var customPhoneMac: String?

    /// 是否输出原始帧日志（TX/RX 十六进制数据），默认 false
    /// Whether to output raw frame logs (TX/RX hex data), defaults to false
    ///
    /// 开启后日志中会包含完整的 BLE 收发帧数据，用于协议调试
    /// When enabled, logs will contain full BLE TX/RX frame data for protocol debugging
    public var rawFrameLogEnabled: Bool

    /// 创建配置
    /// Create configuration
    /// - Parameters:
    ///   - fixedAuthKey: 固定认证密钥 / Fixed auth key (4-char hex, optional)
    ///   - logLevel: 日志级别 / Log level (default .debug)
    ///   - autoAuthEnabled: 是否自动认证 / Auto-authenticate (default true)
    ///   - autoReconnect: 断线是否自动重连 / Auto-reconnect (default true)
    ///   - maxReconnectAttempts: 最大重连次数 / Max reconnect attempts (default 5)
    ///   - language: SDK 语言 / SDK language (default .system)
    ///   - customPhoneMac: 自定义手机标识 / Custom phone identifier (12-char hex, optional)
    public init(
        fixedAuthKey: String? = nil,
        logLevel: LogLevel = .debug,
        autoAuthEnabled: Bool = true,
        autoReconnect: Bool = true,
        maxReconnectAttempts: Int = 5,
        language: BlueSDKLanguage = .system,
        customPhoneMac: String? = nil,
        rawFrameLogEnabled: Bool = false
    ) {
        self.fixedAuthKey = fixedAuthKey
        self.logLevel = logLevel
        self.autoAuthEnabled = autoAuthEnabled
        self.autoReconnect = autoReconnect
        self.maxReconnectAttempts = maxReconnectAttempts
        self.language = language
        self.customPhoneMac = customPhoneMac
        self.rawFrameLogEnabled = rawFrameLogEnabled
    }
}

/// SDK 内部语言判断工具
/// SDK internal locale utility
/// 默认跟随系统，可通过 config.language 覆盖
/// Defaults to system language, can be overridden via config.language
public enum SDKLocale {
    private static var forced: BlueSDKLanguage = .system

    /// 当前语言代码 / Current language code
    public enum Lang { case zh, en, de }

    /// 设置语言 / Set language
    internal static func setLanguage(_ language: BlueSDKLanguage) {
        forced = language
    }

    /// 当前语言 / Current language
    public static var current: Lang {
        switch forced {
        case .zh: return .zh
        case .en: return .en
        case .de: return .de
        case .system:
            let lang = Locale.preferredLanguages.first ?? "en"
            if lang.hasPrefix("zh") { return .zh }
            if lang.hasPrefix("de") { return .de }
            return .en
        }
    }

    /// 当前是否使用中文 / Whether currently using Chinese
    public static var isZh: Bool { current == .zh }

    /// 当前是否使用德语 / Whether currently using German
    public static var isDe: Bool { current == .de }

    /// 便利方法：根据当前语言返回对应文本（中/英）
    /// Convenience: return text based on current language (zh/en)
    public static func s(_ zh: String, _ en: String) -> String {
        return isZh ? zh : en
    }

    /// 三语便利方法：中/英/德
    /// Trilingual convenience: zh/en/de
    public static func s(_ zh: String, _ en: String, _ de: String) -> String {
        switch current {
        case .zh: return zh
        case .en: return en
        case .de: return de
        }
    }
}
