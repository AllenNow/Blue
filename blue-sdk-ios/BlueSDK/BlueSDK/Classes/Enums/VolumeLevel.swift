// VolumeLevel.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK

import Foundation

/// 设备提醒音量级别
@objc public enum VolumeLevel: Int {
    /// 低音量（协议值 0x01）
    case low = 1
    /// 中音量（协议值 0x02）
    case medium = 2
    /// 高音量（协议值 0x03）
    case high = 3

    /// 转换为协议字节值
    var protocolValue: UInt8 { UInt8(rawValue) }
}
