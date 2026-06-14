// MedicationStatus.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 用药状态枚举

import Foundation

/// 用药结果状态枚举
/// 对应协议中 byte9 的状态值
@objc public enum MedicationStatus: Int {
    /// 按时取药（0x01）
    case taken = 1
    /// 超时取药（0x02）
    case timeout = 2
    /// 漏服（0x03）
    case missed = 3
    /// 提前取药（0x04）
    case early = 4

    /// 从协议字节值转换
    static func from(byte: UInt8) -> MedicationStatus? {
        return MedicationStatus(rawValue: Int(byte))
    }
}
