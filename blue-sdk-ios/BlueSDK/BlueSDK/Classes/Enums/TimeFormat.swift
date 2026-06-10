// TimeFormat.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK

import Foundation

/// 设备时间显示格式
@objc public enum TimeFormat: Int {
    /// 12 小时制（协议值 0x00）
    case hour12 = 0
    /// 24 小时制（协议值 0x01）
    case hour24 = 1

    /// 转换为协议字节值
    var protocolValue: UInt8 { UInt8(rawValue) }
}
