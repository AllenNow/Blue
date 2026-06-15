// WeekDay.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 星期 OptionSet（闹钟周期配置）

import Foundation

/// 星期选项集
/// 用于闹钟的周期配置，替代原始 weekMask 整型位掩码
///
/// 使用示例：
/// ```swift
/// BlueSDK.shared.setAlarm(index: 1, hour: 8, minute: 0, days: .weekdays) { ... }
/// BlueSDK.shared.setAlarm(index: 2, hour: 9, minute: 0, days: [.saturday, .sunday]) { ... }
/// ```
public struct WeekDays: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let monday    = WeekDays(rawValue: 0x01)
    public static let tuesday   = WeekDays(rawValue: 0x02)
    public static let wednesday = WeekDays(rawValue: 0x04)
    public static let thursday  = WeekDays(rawValue: 0x08)
    public static let friday    = WeekDays(rawValue: 0x10)
    public static let saturday  = WeekDays(rawValue: 0x20)
    public static let sunday    = WeekDays(rawValue: 0x40)

    /// 每天
    public static let all: WeekDays = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    /// 工作日（周一至周五）
    public static let weekdays: WeekDays = [.monday, .tuesday, .wednesday, .thursday, .friday]

    /// 周末
    public static let weekend: WeekDays = [.saturday, .sunday]
}
