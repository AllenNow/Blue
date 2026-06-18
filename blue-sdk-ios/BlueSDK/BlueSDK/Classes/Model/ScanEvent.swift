// ScanEvent.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
// BlueSDK - LX-PD02 Smart Pill Box BLE SDK
//
// 扫描事件模型
// Scan event model

import Foundation

/// 扫描事件
/// Scan event
///
/// 统一的扫描回调类型，替代原有双回调（onDeviceFound + onError）模式
/// Unified scan callback type, replaces legacy dual-callback (onDeviceFound + onError) pattern
public enum ScanEvent {
    /// 发现设备 / Device found
    case deviceFound(ScannedDevice)
    /// 扫描错误 / Scan error
    case error(BlueError)
    /// 扫描已停止（超时或手动停止）/ Scan stopped (timeout or manual)
    case stopped
}
