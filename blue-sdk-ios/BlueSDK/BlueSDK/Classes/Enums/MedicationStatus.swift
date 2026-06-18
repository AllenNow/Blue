// MedicationStatus.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
// BlueSDK - LX-PD02 Smart Pill Box BLE SDK
//
// 用药状态枚举
// Medication status enum

import Foundation

/// 用药结果状态枚举
/// Medication result status enum
///
/// 对应协议中的状态值
/// Maps to protocol status values
@objc public enum MedicationStatus: Int {
    /// 按时取药（0x01）/ Taken on time (0x01)
    case taken = 1
    /// 超时取药（0x02）/ Taken late (0x02)
    case timeout = 2
    /// 漏服（0x03）/ Missed (0x03)
    case missed = 3
    /// 提前取药（0x04）/ Taken early (0x04)
    case early = 4

    /// 从协议字节值转换
    /// Convert from protocol byte value
    static func from(byte: UInt8) -> MedicationStatus? {
        return MedicationStatus(rawValue: Int(byte))
    }

    /// 用户可读的状态描述（中文）
    /// User-readable description (Chinese)
    public var displayNameZh: String {
        switch self {
        case .taken:   return "按时取药"
        case .timeout: return "超时取药"
        case .missed:  return "漏服"
        case .early:   return "提前取药"
        }
    }

    /// 用户可读的状态描述（英文）
    /// User-readable description (English)
    public var displayNameEn: String {
        switch self {
        case .taken:   return "Taken on time"
        case .timeout: return "Taken late"
        case .missed:  return "Missed"
        case .early:   return "Taken early"
        }
    }

    /// 用户可读的状态描述（德语）
    /// User-readable description (German)
    public var displayNameDe: String {
        switch self {
        case .taken:   return "Pünktlich eingenommen"
        case .timeout: return "Verspätet eingenommen"
        case .missed:  return "Vergessen"
        case .early:   return "Vorzeitig eingenommen"
        }
    }
}
