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

    /// 闹钟记录（可下发可上报）
    /// byte0-闹钟DP点 byte1-年份高字节 byte2-年份低字节 byte3-月份
    /// byte4-日 byte5-闹钟小时 byte6-闹钟分钟 byte7-响铃小时 byte8-响铃分钟
    /// byte9-闹钟状态(0x01取药/0x02超时取药/0x03漏服/0x04提前取药)
    /// byte10-0x00未提前取药 0x01提前取药
    static let alarmRecord: UInt8 = 0x65

    // MARK: - 闹钟槽位（1~7）

    /// 闹钟1（可下发可上报）
    /// byte0-小时 byte1-分钟 byte2-周期使能(bit0-周日...bit6-周六，默认0x7F)
    /// byte3-提前状态(bit0-当天 bit4-次日)
    static let alarm1: UInt8 = 0x66

    /// 闹钟2（可下发可上报）
    static let alarm2: UInt8 = 0x67

    /// 闹钟3（可下发可上报）
    static let alarm3: UInt8 = 0x68

    /// 闹钟4（可下发可上报）
    static let alarm4: UInt8 = 0x69

    /// 闹钟5（可下发可上报）
    static let alarm5: UInt8 = 0x6A

    /// 闹钟6（可下发可上报）
    static let alarm6: UInt8 = 0x6B

    /// 闹钟7（可下发可上报）
    static let alarm7: UInt8 = 0x6C

    // MARK: - 音频设置

    /// 声音类型（可下发可上报）
    /// 1-静音 2-声音A 3-声音B
    static let typeOfSound: UInt8 = 0x6D

    /// 音量设置（可下发可上报）1-低 2-中 3-高
    /// ⚠️ 协议文档将此字段注释为"提醒持续时间"，但示例帧 6E 04 00 01 01 实为音量设置
    /// 以示例帧为准，待硬件方最终确认
    static let volumeLevel: UInt8 = 0x6E

    /// 铃声类型设置（可下发可上报）1-类型A 2-类型B 3-类型C
    /// ⚠️ 协议文档将此字段注释为"用药结果通知"，但示例帧 6F 04 00 01 01 实为铃声类型
    /// 以示例帧为准，待硬件方最终确认
    static let soundTypeSetting: UInt8 = 0x6F

    // MARK: - 系统控制

    /// 提醒持续时间（可下发可上报）
    /// ⚠️ 协议文档将此字段注释为"清空所有闹钟"，但示例帧 70 02 00 04 ... 实为持续时间
    /// 以示例帧为准，待硬件方最终确认
    static let alertDurationSetting: UInt8 = 0x70

    /// 设备恢复出厂配置（只下发）
    /// 1-通知设备恢复出厂设置
    static let restoreFactory: UInt8 = 0x71

    /// 时制（可下发可上报）
    /// 0-12小时制 1-24小时制
    static let timeFormat: UInt8 = 0x73

    /// 当前闹钟静音（可下发可上报）
    /// 0-静音关 1-静音开
    static let silence: UInt8 = 0x74

    /// 设备低电（只上报）
    /// 1-设备低电
    static let lowBat: UInt8 = 0x75

    // MARK: - 辅助方法

    /// 根据闹钟槽位索引（1~7）获取对应的 DPID
    /// - Parameter index: 闹钟槽位，范围 1~7
    /// - Returns: 对应的 DPID 值，索引无效时返回 nil
    static func alarmDPID(for index: Int) -> UInt8? {
        guard index >= 1, index <= 7 else { return nil }
        return alarm1 + UInt8(index - 1)
    }

    /// 根据 DPID 获取闹钟槽位索引（1~7）
    /// - Parameter dpid: DPID 值
    /// - Returns: 闹钟槽位索引，非闹钟 DPID 时返回 nil
    static func alarmIndex(for dpid: UInt8) -> Int? {
        guard dpid >= alarm1, dpid <= alarm7 else { return nil }
        return Int(dpid - alarm1) + 1
    }
}
