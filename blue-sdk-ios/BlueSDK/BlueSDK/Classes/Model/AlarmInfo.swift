// AlarmInfo.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 闹钟信息数据模型

import Foundation

/// 闹钟信息
@objc public class AlarmInfo: NSObject {
    /// 闹钟槽位索引（1~7）
    @objc public let index: Int
    /// 小时（0~23）
    @objc public let hour: Int
    /// 分钟（0~59）
    @objc public let minute: Int
    /// 星期周期掩码（bit0=周日, bit1=周一, ..., bit6=周六，默认 0x7F 每天）
    @objc public let weekMask: Int
    /// 提前取药状态（bit0=当天已取药, bit4=次日已取药）
    @objc public let advanceStatus: Int

    @objc public init(index: Int, hour: Int, minute: Int, weekMask: Int, advanceStatus: Int) {
        self.index = index
        self.hour = hour
        self.minute = minute
        self.weekMask = weekMask
        self.advanceStatus = advanceStatus
    }

    /// 是否为删除状态（所有字段为 0xFF）
    @objc public var isDeleted: Bool {
        return hour == 0xFF && minute == 0xFF && weekMask == 0xFF
    }
}
