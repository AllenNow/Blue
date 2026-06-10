// MedicationRecord.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 用药记录数据模型

import Foundation

/// 用药记录
@objc public class MedicationRecord: NSObject {
    /// 用药时间戳（Unix 时间戳，**毫秒**，与 Android 保持一致）
    @objc public let timestamp: Int64
    /// 对应的闹钟槽位索引（1~7）
    @objc public let alarmIndex: Int
    /// 用药状态
    @objc public let status: MedicationStatus

    @objc public init(timestamp: Int64, alarmIndex: Int, status: MedicationStatus) {
        self.timestamp = timestamp
        self.alarmIndex = alarmIndex
        self.status = status
    }

    /// 将时间戳转换为 Date
    public var date: Date {
        return Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
    }
}
