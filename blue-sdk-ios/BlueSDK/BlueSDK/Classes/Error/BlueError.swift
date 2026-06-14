// BlueError.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 统一错误类型定义
// 所有 SDK 错误通过回调返回此类型，不向上层抛出异常（ARCH-08）

import Foundation

/// SDK 统一错误类型
/// 所有异步操作通过回调返回此类型，不抛出异常
/// 支持携带底层错误信息（underlyingError）以便集成方调试
public enum BlueError: Error, Equatable {
    /// SDK 未初始化，需先调用 initialize()
    case notInitialized
    /// 设备未完成认证，需先完成 authenticate()
    case notAuthenticated
    /// 认证失败，密钥不匹配
    case authFailed
    /// 指令超时（5秒内未收到设备应答）
    case timeout
    /// 蓝牙权限未授权
    case permissionDenied
    /// 参数无效（如闹钟索引超出 1~7 范围）
    case invalidParameter
    /// 协议错误（帧格式异常或 CRC 校验失败）
    case protocolError
    /// 系统 BLE 错误，携带底层错误
    case bleError(underlying: Error?)
    /// 设备已断开连接
    case disconnected

    // MARK: - Equatable

    public static func == (lhs: BlueError, rhs: BlueError) -> Bool {
        switch (lhs, rhs) {
        case (.notInitialized, .notInitialized): return true
        case (.notAuthenticated, .notAuthenticated): return true
        case (.authFailed, .authFailed): return true
        case (.timeout, .timeout): return true
        case (.permissionDenied, .permissionDenied): return true
        case (.invalidParameter, .invalidParameter): return true
        case (.protocolError, .protocolError): return true
        case (.bleError, .bleError): return true
        case (.disconnected, .disconnected): return true
        default: return false
        }
    }

    // MARK: - ObjC 兼容错误码

    /// 数字错误码，用于 ObjC 桥接和跨平台错误码对齐
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
        }
    }

    /// 底层错误（仅 .bleError 类型有值）
    public var underlyingError: Error? {
        if case .bleError(let err) = self { return err }
        return nil
    }
}

extension BlueError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notInitialized:    return "SDK 未初始化，请先调用 initialize()"
        case .notAuthenticated:  return "设备未认证，请先完成身份验证"
        case .authFailed:        return "认证失败，密钥不匹配"
        case .timeout:           return "指令超时，设备未在规定时间内响应"
        case .permissionDenied:  return "蓝牙权限未授权"
        case .invalidParameter:  return "参数无效"
        case .protocolError:     return "协议错误"
        case .bleError(let err): return "蓝牙系统错误：\(err?.localizedDescription ?? "未知")"
        case .disconnected:      return "设备已断开连接"
        }
    }
}

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
