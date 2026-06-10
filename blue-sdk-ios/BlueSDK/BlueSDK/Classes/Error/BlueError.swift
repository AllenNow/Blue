// BlueError.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 统一错误类型定义
// 所有 SDK 错误通过回调返回，不向上层抛出异常（ARCH-08）

import Foundation

/// SDK 统一错误类型
/// 所有异步操作通过回调返回此类型，不抛出异常
@objc public enum BlueError: Int, Error {
    /// SDK 未初始化，需先调用 initialize()
    case notInitialized = 1
    /// 设备未完成认证，需先完成 authenticate()
    case notAuthenticated = 2
    /// 认证失败，密钥不匹配
    case authFailed = 3
    /// 指令超时（5秒内未收到设备应答）
    case timeout = 4
    /// 蓝牙权限未授权
    case permissionDenied = 5
    /// 参数无效（如闹钟索引超出 1~7 范围）
    case invalidParameter = 6
    /// 协议错误（帧格式异常或 CRC 校验失败）
    case protocolError = 7
    /// 系统 BLE 错误
    case bleError = 8
    /// 设备已断开连接
    case disconnected = 9
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
        case .bleError:          return "蓝牙系统错误"
        case .disconnected:      return "设备已断开连接"
        }
    }
}
