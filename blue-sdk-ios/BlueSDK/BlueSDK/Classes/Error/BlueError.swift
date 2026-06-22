// BlueError.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 统一错误类型定义（支持中英双语）
// 根据系统语言自动切换错误描述和恢复建议

import Foundation

/// SDK 统一错误类型
public enum BlueError: Error, Equatable {
    case notInitialized
    case notAuthenticated
    case authFailed
    case timeout
    case permissionDenied
    case invalidParameter
    case protocolError
    case bleError(underlying: Error?)
    case disconnected
    case deviceNotFound

    // MARK: - Equatable

    public static func == (lhs: BlueError, rhs: BlueError) -> Bool {
        switch (lhs, rhs) {
        case (.notInitialized, .notInitialized),
             (.notAuthenticated, .notAuthenticated),
             (.authFailed, .authFailed),
             (.timeout, .timeout),
             (.permissionDenied, .permissionDenied),
             (.invalidParameter, .invalidParameter),
             (.protocolError, .protocolError),
             (.bleError, .bleError),
             (.disconnected, .disconnected),
             (.deviceNotFound, .deviceNotFound):
            return true
        default:
            return false
        }
    }

    // MARK: - 跨平台错误码

    public var code: Int {
        switch self {
        case .notInitialized:  return 1
        case .notAuthenticated: return 2
        case .authFailed:      return 3
        case .timeout:         return 4
        case .permissionDenied: return 5
        case .invalidParameter: return 6
        case .protocolError:   return 7
        case .bleError:        return 8
        case .disconnected:    return 9
        case .deviceNotFound:  return 10
        }
    }

    public var underlyingError: Error? {
        if case .bleError(let err) = self { return err }
        return nil
    }

    // MARK: - 多语言

    /// 错误恢复建议（跟随 SDKLocale 设置，支持中/英/德）
    public var recoverySuggestion: String {
        switch self {
        case .notInitialized:
            return SDKLocale.s("请在调用任何 SDK 方法前先执行 BlueSDK.shared.initialize()",
                               "Call BlueSDK.shared.initialize() before using any SDK method",
                               "Rufen Sie BlueSDK.shared.initialize() auf, bevor Sie SDK-Methoden verwenden")
        case .notAuthenticated:
            return SDKLocale.s("请等待连接成功后 SDK 自动认证完成，或检查 fixedAuthKey 配置是否正确",
                               "Wait for SDK auto-authentication after connection, or check fixedAuthKey configuration",
                               "Warten Sie auf die automatische Authentifizierung oder prüfen Sie die fixedAuthKey-Konfiguration")
        case .authFailed:
            return SDKLocale.s("请检查 fixedAuthKey 是否与设备端匹配。如设备已被其他手机绑定，需先对设备执行恢复出厂设置",
                               "Check if fixedAuthKey matches the device. If bound to another phone, factory reset the device first",
                               "Prüfen Sie den fixedAuthKey. Falls das Gerät an ein anderes Handy gebunden ist, führen Sie einen Werksreset durch")
        case .timeout:
            return SDKLocale.s("请确认设备在蓝牙有效范围内（≤3米）且电量充足。可尝试重新连接",
                               "Ensure device is within 3m range and has sufficient battery. Try reconnecting",
                               "Stellen Sie sicher, dass das Gerät in ≤3m Reichweite ist und genug Akku hat. Versuchen Sie erneut zu verbinden")
        case .permissionDenied:
            return SDKLocale.s("请在系统设置中授予应用蓝牙权限。iOS 13+ 需要在 Info.plist 中声明 NSBluetoothAlwaysUsageDescription",
                               "Grant Bluetooth permission in Settings. iOS 13+ requires NSBluetoothAlwaysUsageDescription in Info.plist",
                               "Erteilen Sie die Bluetooth-Berechtigung in den Einstellungen. iOS 13+ benötigt NSBluetoothAlwaysUsageDescription")
        case .invalidParameter:
            return SDKLocale.s("请检查参数范围：闹钟索引 1~7，小时 0~23，分钟 0~59",
                               "Check parameter ranges: alarm index 1~7, hour 0~23, minute 0~59",
                               "Parameterbereich prüfen: Alarm-Index 1~7, Stunde 0~23, Minute 0~59")
        case .protocolError:
            return SDKLocale.s("通信帧校验失败，可能是蓝牙干扰导致。建议断开重连后重试",
                               "Frame CRC check failed, possibly due to interference. Disconnect and retry",
                               "Frame-Prüfsumme fehlgeschlagen, möglicherweise durch Interferenz. Trennen und erneut versuchen")
        case .bleError:
            return SDKLocale.s("系统蓝牙异常，请确认蓝牙已开启。如问题持续，尝试重启手机蓝牙",
                               "BLE system error. Ensure Bluetooth is enabled. If persistent, try toggling Bluetooth",
                               "BLE-Systemfehler. Stellen Sie sicher, dass Bluetooth aktiviert ist. Bei anhaltendem Problem Bluetooth neu starten")
        case .disconnected:
            return SDKLocale.s("设备连接已断开。SDK 会自动尝试重连，也可手动调用 connect() 重新连接",
                               "Device disconnected. SDK will auto-reconnect, or call connect() manually",
                               "Gerät getrennt. SDK versucht automatisch neu zu verbinden, oder rufen Sie connect() manuell auf")
        case .deviceNotFound:
            return SDKLocale.s("未找到设备，请确认设备已开启且在蓝牙范围内",
                               "Device not found. Ensure device is powered on and within range",
                               "Gerät nicht gefunden. Stellen Sie sicher, dass es eingeschaltet und in Reichweite ist")
        }
    }
}

// MARK: - LocalizedError

extension BlueError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return SDKLocale.s("SDK 未初始化，请先调用 initialize()", "SDK not initialized, call initialize() first", "SDK nicht initialisiert, bitte initialize() aufrufen")
        case .notAuthenticated:
            return SDKLocale.s("设备未认证，请先完成身份验证", "Device not authenticated", "Gerät nicht authentifiziert")
        case .authFailed:
            return SDKLocale.s("认证失败，密钥不匹配", "Authentication failed, key mismatch", "Authentifizierung fehlgeschlagen, Schlüssel stimmt nicht")
        case .timeout:
            return SDKLocale.s("指令超时，设备未在规定时间内响应", "Command timeout, device did not respond", "Befehl-Timeout, Gerät hat nicht geantwortet")
        case .permissionDenied:
            return SDKLocale.s("蓝牙权限未授权", "Bluetooth permission denied", "Bluetooth-Berechtigung verweigert")
        case .invalidParameter:
            return SDKLocale.s("参数无效", "Invalid parameter", "Ungültiger Parameter")
        case .protocolError:
            return SDKLocale.s("协议错误", "Protocol error", "Protokollfehler")
        case .bleError(let err):
            let detail = err?.localizedDescription ?? SDKLocale.s("未知", "unknown", "unbekannt")
            return SDKLocale.s("蓝牙系统错误：\(detail)", "BLE system error: \(detail)", "BLE-Systemfehler: \(detail)")
        case .disconnected:
            return SDKLocale.s("设备已断开连接", "Device disconnected", "Gerät getrennt")
        case .deviceNotFound:
            return SDKLocale.s("未找到设备", "Device not found", "Gerät nicht gefunden")
        }
    }
}

// MARK: - CustomNSError

extension BlueError: CustomNSError {
    public static var errorDomain: String { "com.blue.sdk.error" }
    public var errorCode: Int { code }
    public var errorUserInfo: [String: Any] {
        var info: [String: Any] = [NSLocalizedDescriptionKey: errorDescription ?? ""]
        if let underlying = underlyingError {
            info[NSUnderlyingErrorKey] = underlying
        }
        return info
    }
}
