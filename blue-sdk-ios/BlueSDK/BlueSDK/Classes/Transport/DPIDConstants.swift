// DPIDConstants.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// DPID 功能字节常量定义
// 对应数据内容中的功能字节，用于标识具体的数据类型

import Foundation

/// DPID 功能字节常量（Data Point ID）
/// 位于数据段第一字节，标识该帧携带的数据类型
enum DPIDConstants {

    // MARK: - 用药记录

    /// 闹钟记录（可下发可上报）DPID_ALARMRECORD
    /// byte0-闹钟DP点 byte1-年高 byte2-年低 byte3-月 byte4-日
    /// byte5-闹钟小时 byte6-闹钟分钟 byte7-响铃小时 byte8-响铃分钟
    /// byte9-闹钟状态(0x01取药/0x02超时取药/0x03漏服/0x04提前取药)
    /// byte10-0x00未提前取药 0x01提前取药
    static let alarmRecord: UInt8 = 0x65

    // MARK: - 闹钟槽位（1~7）

    /// 闹钟1（可下发可上报）DPID_ALARM1
    /// byte0-小时 byte1-分钟 byte2-周期使能(bit0=周日,bit1=周一,bit2=周二,bit3=周三,bit4=周四,bit5=周五,bit6=周六，默认0x7F)
    /// byte3-提前状态(bit0-当天 bit4-次日)
    static let alarm1: UInt8 = 0x66
    static let alarm2: UInt8 = 0x67
    static let alarm3: UInt8 = 0x68
    static let alarm4: UInt8 = 0x69
    static let alarm5: UInt8 = 0x6A
    static let alarm6: UInt8 = 0x6B
    static let alarm7: UInt8 = 0x6C

    // MARK: - 音频设置

    /// 声音类型（可下发可上报）DPID_TYPEOFSOUND
    /// 1-静音 2-声音A 3-声音B
    static let typeOfSound: UInt8 = 0x6D

    /// 提醒持续时间 / 音量设置（可下发可上报）
    /// 帧示例（持续时间）：70 02 00 04 00 00 00 XX
    /// 帧示例（音量）：6E 04 00 01 XX
    /// ⚠️ 协议文档将 0x70 注释为"清空所有闹钟"，但帧示例证实 0x70 为提醒持续时间
    static let alertDuration: UInt8 = 0x6E

    /// 用药结果通知 / 铃声类型设置（可下发可上报）
    /// APP 下发铃声：6F 04 00 01 XX（01=A, 02=B, 03=C）
    /// ⚠️ 协议文档将 0x6F 注释为"用药结果通知"，但帧示例证实 APP 用此 DPID 设置铃声类型
    static let notificationOfResults: UInt8 = 0x6F

    // MARK: - 系统控制

    /// 清空所有闹钟 / 提醒持续时间设置（只下发）
    /// 帧示例（持续时间）：70 02 00 04 00 00 00 05
    /// ⚠️ 协议文档将 0x70 注释为"清空所有闹钟"，但帧示例证实为提醒持续时间设置
    /// 清空闹钟功能待硬件方确认真实 DPID
    static let emptyAllAlarms: UInt8 = 0x70

    /// 设备恢复出厂配置（只下发）
    /// DPID = 0x71
    static let restoreFactory: UInt8 = 0x71

    /// 时制（可下发可上报）DPID_TIMEFORMAT
    /// 0-12小时制 1-24小时制
    static let timeFormat: UInt8 = 0x73

    /// 当前闹钟静音（可下发可上报）DPID_SILENCE
    /// 0-静音关 1-静音开
    static let silence: UInt8 = 0x74

    /// 设备低电（只上报）DPID_LOWBAT
    /// 1-设备低电
    static let lowBat: UInt8 = 0x75

    // MARK: - 辅助方法

    /// 根据闹钟槽位索引（1~7）获取对应的 DPID
    static func alarmDPID(for index: Int) -> UInt8? {
        guard index >= 1, index <= 7 else { return nil }
        return alarm1 + UInt8(index - 1)
    }

    /// 根据 DPID 获取闹钟槽位索引（1~7）
    static func alarmIndex(for dpid: UInt8) -> Int? {
        guard dpid >= alarm1, dpid <= alarm7 else { return nil }
        return Int(dpid - alarm1) + 1
    }
}
