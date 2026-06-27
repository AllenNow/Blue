// WeekDay.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
// BlueSDK - LX-PD02 Smart Pill Box BLE SDK
//
// 星期 OptionSet（闹钟周期配置）
// Weekday OptionSet (alarm repeat schedule)

import Foundation

/// 星期选项集
/// Weekday option set
///
/// 用于闹钟的周期配置，替代原始 weekMask 整型位掩码
/// Used for alarm repeat configuration, replaces raw weekMask int bitmask
///
/// 使用示例 / Usage:
/// ```swift
/// BlueSDK.shared.setAlarm(index: 1, hour: 8, minute: 0, days: .weekdays) { ... }
/// BlueSDK.shared.setAlarm(index: 2, hour: 9, minute: 0, days: [.saturday, .sunday]) { ... }
/// ```
public struct WeekDays: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// 周日 / Sunday
    public static let sunday    = WeekDays(rawValue: 0x01)
    /// 周一 / Monday
    public static let monday    = WeekDays(rawValue: 0x02)
    /// 周二 / Tuesday
    public static let tuesday   = WeekDays(rawValue: 0x04)
    /// 周三 / Wednesday
    public static let wednesday = WeekDays(rawValue: 0x08)
    /// 周四 / Thursday
    public static let thursday  = WeekDays(rawValue: 0x10)
    /// 周五 / Friday
    public static let friday    = WeekDays(rawValue: 0x20)
    /// 周六 / Saturday
    public static let saturday  = WeekDays(rawValue: 0x40)

    /// 每天 / Every day
    public static let all: WeekDays = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

    /// 工作日（周一至周五）/ Weekdays (Mon-Fri)
    public static let weekdays: WeekDays = [.monday, .tuesday, .wednesday, .thursday, .friday]

    /// 周末 / Weekend
    public static let weekend: WeekDays = [.saturday, .sunday]
}
