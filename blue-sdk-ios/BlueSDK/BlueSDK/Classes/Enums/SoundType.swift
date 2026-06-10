// SoundType.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK

import Foundation

/// 设备铃声类型
@objc public enum SoundType: Int {
    /// 静音（协议值 0x00）
    case mute = 0
    /// 声音类型 A（协议值 0x01）
    case typeA = 1
    /// 声音类型 B（协议值 0x02）
    case typeB = 2
    /// 声音类型 C（协议值 0x03）
    case typeC = 3

    /// 转换为协议字节值
    var protocolValue: UInt8 { UInt8(rawValue) }

    /// 从协议字节值转换
    static func from(byte: UInt8) -> SoundType? {
        return SoundType(rawValue: Int(byte))
    }
}
