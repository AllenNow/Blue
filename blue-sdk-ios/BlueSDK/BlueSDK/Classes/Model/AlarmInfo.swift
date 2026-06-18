// AlarmInfo.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
// BlueSDK - LX-PD02 Smart Pill Box BLE SDK
//
// 闹钟信息数据模型
// Alarm info data model

import Foundation

/// 闹钟运行状态
/// Alarm running state
@objc public enum AlarmRunState: Int {
    /// 空闲/等待下次触发 / Idle, waiting for next trigger
    case idle = 0
    /// 正在响铃中 / Currently ringing
    case ringing = 1
    /// 响铃结束（超时或已取药）/ Ringing ended (timeout or taken)
    case ended = 2
}

/// 闹钟信息
/// Alarm info
@objc public class AlarmInfo: NSObject {
    /// 闹钟槽位索引（1~7）/ Alarm slot index (1~7)
    @objc public let index: Int
    /// 小时（0~23）/ Hour (0~23)
    @objc public let hour: Int
    /// 分钟（0~59）/ Minute (0~59)
    @objc public let minute: Int
    /// 星期周期掩码 / Week repeat bitmask
    @objc public let weekMask: Int
    /// 响铃状态：0=空闲, 1=响铃结束 / Ringing state: 0=idle, 1=ended
    @objc public let ringingState: Int
    /// 事件状态：0=无, 1=响铃中, 2=超时或已取药 / Event status: 0=none, 1=ringing, 2=timeout/taken
    @objc public let eventStatus: Int

    @objc public init(index: Int, hour: Int, minute: Int, weekMask: Int, ringingState: Int = 0, eventStatus: Int = 0) {
        self.index = index
        self.hour = hour
        self.minute = minute
        self.weekMask = weekMask
        self.ringingState = ringingState
        self.eventStatus = eventStatus
    }

    /// 向后兼容旧字段 / Backward compatible
    @objc public var advanceStatus: Int { eventStatus }

    /// 是否为删除状态 / Whether deleted
    @objc public var isDeleted: Bool {
        return hour == 0xFF && minute == 0xFF && weekMask == 0xFF
    }

    /// 当前运行状态 / Current running state
    @objc public var runState: AlarmRunState {
        if ringingState == 0 && eventStatus == 1 { return .ringing }
        if ringingState == 1 { return .ended }
        return .idle
    }
}
