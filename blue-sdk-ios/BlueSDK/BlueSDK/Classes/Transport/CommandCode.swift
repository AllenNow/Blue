// CommandCode.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// CMD 命令字常量定义
// 对应帧结构中第4字节（index=3）的命令类型

import Foundation

/// CMD 命令字常量
/// 用于标识帧类型，区分下行指令和上行上报
enum CommandCode {
    /// 查询设备信息（下行）
    /// 帧示例：55 AA 00 01 00 00 00
    static let queryDeviceInfo: UInt8 = 0x01

    /// 时间同步（双向）
    /// 设备请求：55 AA 00 E1 00 01 00 E1
    /// APP 下发：55 AA 00 E1 00 0B ...
    static let timeSync: UInt8 = 0xE1

    /// APP 下发指令（下行）
    /// 用于设置闹钟、音量、铃声等所有配置类指令
    static let sendCommand: UInt8 = 0x06

    /// 设备上报（上行）
    /// 设备主动上报闹钟变更、用药事件等
    static let deviceReport: UInt8 = 0x07

    /// 密钥认证（下行）
    /// 帧示例：55 AA 00 00 00 02 [keyHigh] [keyLow] [crc8]
    static let authKey: UInt8 = 0x00
}
