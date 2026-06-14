// FrameConstants.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 协议帧格式常量定义
// 所有帧结构相关的固定值，禁止在其他文件中使用魔法数字

import Foundation

/// 协议帧格式常量
/// 帧结构：[0x55][0xAA][版本][CMD][LenHigh][LenLow][Data...][CRC8]
enum FrameConstants {
    /// 帧头第一字节
    static let headerByte1: UInt8 = 0x55
    /// 帧头第二字节
    static let headerByte2: UInt8 = 0xAA
    /// 协议版本号
    static let protocolVersion: UInt8 = 0x00
    /// 最小帧长度：帧头2 + 版本1 + CMD1 + Len2 + CRC1 = 7字节
    static let minFrameLength: Int = 7
    /// 帧头偏移量
    static let headerOffset: Int = 0
    /// 版本字段偏移量
    static let versionOffset: Int = 2
    /// CMD 字段偏移量
    static let cmdOffset: Int = 3
    /// 数据长度高字节偏移量
    static let lenHighOffset: Int = 4
    /// 数据长度低字节偏移量
    static let lenLowOffset: Int = 5
    /// 数据起始偏移量
    static let dataOffset: Int = 6
}
