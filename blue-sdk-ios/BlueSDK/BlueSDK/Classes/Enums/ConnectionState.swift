// ConnectionState.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 连接状态枚举

import Foundation

/// BLE 连接状态枚举
/// 状态转换通过 ConnectionManager 统一管理（ARCH-07）
@objc public enum ConnectionState: Int {
    /// 已断开（初始状态）
    case disconnected = 0
    /// 连接中
    case connecting = 1
    /// 已连接（未认证）
    case connected = 2
    /// 已认证（可执行业务指令）
    case authenticated = 3
    /// 重连中（断线后自动重连）
    case reconnecting = 4
}
