// PermissionManager.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 蓝牙权限状态检查（FR07）

import Foundation
import CoreBluetooth

/// 权限管理器
enum PermissionManager {

    /// 查询当前蓝牙权限状态（同步，不触发系统弹窗）
    static func checkPermission() -> PermissionStatus {
        if #available(iOS 13.1, macOS 10.15, *) {
            switch CBManager.authorization {
            case .allowedAlways:
                return .granted
            case .denied, .restricted:
                return .denied
            case .notDetermined:
                return .notDetermined
            @unknown default:
                return .notDetermined
            }
        } else {
            return .notDetermined
        }
    }
}
