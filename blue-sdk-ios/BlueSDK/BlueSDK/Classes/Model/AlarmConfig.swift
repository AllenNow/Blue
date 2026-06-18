// AlarmConfig.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
// BlueSDK - LX-PD02 Smart Pill Box BLE SDK
//
// 闹钟配置数据结构（批量设置用）
// Alarm configuration struct (for batch operations)

import Foundation

/// 闹钟配置（用于批量设置）
/// Alarm configuration (for batch operations)
///
/// 使用示例 / Usage:
/// ```swift
/// let alarms = [
///     AlarmConfig(index: 1, hour: 8, minute: 0),
///     AlarmConfig(index: 2, hour: 12, minute: 30, days: .weekdays),
///     AlarmConfig(index: 3, hour: 20, minute: 0, days: .weekend)
/// ]
/// BlueSDK.shared.setAlarms(alarms) { result in ... }
/// ```
public struct AlarmConfig {
    /// 闹钟槽位（1~7）/ Alarm slot (1~7)
    public let index: Int
    /// 小时（0~23）/ Hour (0~23)
    public let hour: Int
    /// 分钟（0~59）/ Minute (0~59)
    public let minute: Int
    /// 星期周期 / Repeat days
    public let days: WeekDays

    /// 创建闹钟配置
    /// Create alarm configuration
    /// - Parameters:
    ///   - index: 闹钟槽位（1~7）/ Alarm slot (1~7)
    ///   - hour: 小时（0~23）/ Hour (0~23)
    ///   - minute: 分钟（0~59）/ Minute (0~59)
    ///   - days: 重复星期（默认每天）/ Repeat days (default: every day)
    public init(index: Int, hour: Int, minute: Int, days: WeekDays = .all) {
        self.index = index
        self.hour = hour
        self.minute = minute
        self.days = days
    }

    /// 创建闹钟配置（兼容旧 weekMask）
    /// Create alarm configuration (compatible with legacy weekMask)
    /// - Parameters:
    ///   - index: 闹钟槽位（1~7）/ Alarm slot (1~7)
    ///   - hour: 小时（0~23）/ Hour (0~23)
    ///   - minute: 分钟（0~59）/ Minute (0~59)
    ///   - weekMask: 星期掩码整数 / Week bitmask integer
    public init(index: Int, hour: Int, minute: Int, weekMask: Int) {
        self.index = index
        self.hour = hour
        self.minute = minute
        self.days = WeekDays(rawValue: weekMask)
    }

    /// 获取 weekMask 整数值（内部使用）
    /// Get weekMask integer value (internal use)
    internal var weekMask: Int { days.rawValue }
}
