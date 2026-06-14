// PermissionStatus.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK

import Foundation

/// 蓝牙权限状态（与 Android PermissionStatus 对称）
@objc public enum PermissionStatus: Int {
    /// 已授权
    case granted = 0
    /// 已拒绝
    case denied = 1
    /// 尚未请求（未确定）
    case notDetermined = 2
}
