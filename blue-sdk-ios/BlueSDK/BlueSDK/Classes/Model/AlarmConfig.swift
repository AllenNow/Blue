// AlarmConfig.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 闹钟配置数据结构（批量设置用）

import Foundation

/// 闹钟配置（用于批量设置）
///
/// 使用示例：
/// ```swift
/// let alarms = [
///     AlarmConfig(index: 1, hour: 8, minute: 0),
///     AlarmConfig(index: 2, hour: 12, minute: 30, days: .weekdays),
///     AlarmConfig(index: 3, hour: 20, minute: 0, days: .weekend)
/// ]
/// BlueSDK.shared.setAlarms(alarms) { result in ... }
/// ```
public struct AlarmConfig {
    /// 闹钟槽位（1~7）
    public let index: Int
    /// 小时（0~23）
    public let hour: Int
    /// 分钟（0~59）
    public let minute: Int
    /// 星期周期（类型安全）
    public let days: WeekDays

    /// 创建闹钟配置
    /// - Parameters:
    ///   - index: 闹钟槽位（1~7）
    ///   - hour: 小时（0~23）
    ///   - minute: 分钟（0~59）
    ///   - days: 重复星期（默认每天）
    public init(index: Int, hour: Int, minute: Int, days: WeekDays = .all) {
        self.index = index
        self.hour = hour
        self.minute = minute
        self.days = days
    }

    /// 创建闹钟配置（兼容旧 weekMask）
    /// - Parameters:
    ///   - index: 闹钟槽位（1~7）
    ///   - hour: 小时（0~23）
    ///   - minute: 分钟（0~59）
    ///   - weekMask: 星期掩码整数
    public init(index: Int, hour: Int, minute: Int, weekMask: Int) {
        self.index = index
        self.hour = hour
        self.minute = minute
        self.days = WeekDays(rawValue: weekMask)
    }

    /// 获取 weekMask 整数值（内部使用）
    internal var weekMask: Int { days.rawValue }
}
