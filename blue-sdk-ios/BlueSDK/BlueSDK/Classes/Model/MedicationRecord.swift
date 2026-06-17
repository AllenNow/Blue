// MedicationRecord.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 用药记录数据模型

import Foundation

/// 用药记录
@objc public class MedicationRecord: NSObject {
    /// 实际事件时间戳（Unix 时间戳，毫秒）— 取药/漏服发生的时刻
    @objc public let timestamp: Int64
    /// 对应的闹钟槽位索引（1~7）
    @objc public let alarmIndex: Int
    /// 闹钟设定小时（0~23）— 应该吃药的时间
    @objc public let alarmHour: Int
    /// 闹钟设定分钟（0~59）
    @objc public let alarmMinute: Int
    /// 用药状态（取药/超时/漏服/提前）
    @objc public let status: MedicationStatus

    @objc public init(timestamp: Int64, alarmIndex: Int, alarmHour: Int, alarmMinute: Int, status: MedicationStatus) {
        self.timestamp = timestamp
        self.alarmIndex = alarmIndex
        self.alarmHour = alarmHour
        self.alarmMinute = alarmMinute
        self.status = status
    }

    /// 将时间戳转换为 Date（实际事件时间）
    public var date: Date {
        return Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
    }

    /// 闹钟设定时间格式化（如 "08:00"）
    @objc public var alarmTimeString: String {
        return String(format: "%02d:%02d", alarmHour, alarmMinute)
    }
}
