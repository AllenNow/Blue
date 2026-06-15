// ScanEvent.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 扫描事件模型

import Foundation

/// 扫描事件
/// 统一的扫描回调类型，替代原有双回调（onDeviceFound + onError）模式
public enum ScanEvent {
    /// 发现设备
    case deviceFound(ScannedDevice)
    /// 扫描错误
    case error(BlueError)
    /// 扫描已停止（超时或手动停止）
    case stopped
}
