// FrameBuilder.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 帧构建器：将业务数据封装为符合协议格式的二进制帧
// 帧格式：[0x55][0xAA][版本][CMD][LenHigh][LenLow][Data...][CRC8]

import Foundation

/// 帧构建器
/// 所有下行指令通过此类构建，保证帧格式正确
enum FrameBuilder {

    /// 构建完整协议帧
    /// - Parameters:
    ///   - cmd: 命令字（见 CommandCode）
    ///   - data: 数据内容，可为空
    /// - Returns: 完整帧字节数组，包含帧头、版本、CMD、长度、数据和 CRC8
    static func build(cmd: UInt8, data: [UInt8] = []) -> [UInt8] {
        let len = data.count
        let lenHigh = UInt8((len >> 8) & 0xFF)
        let lenLow  = UInt8(len & 0xFF)

        var frame: [UInt8] = [
            FrameConstants.headerByte1,
            FrameConstants.headerByte2,
            FrameConstants.protocolVersion,
            cmd,
            lenHigh,
            lenLow
        ]
        frame.append(contentsOf: data)

        let crc = CRC8Calculator.calculate(frame)
        frame.append(crc)
        return frame
    }

    /// 构建完整协议帧（Data 版本）
    /// - Parameters:
    ///   - cmd: 命令字
    ///   - data: 数据内容
    /// - Returns: 完整帧 Data
    static func build(cmd: UInt8, data: Data) -> Data {
        return Data(build(cmd: cmd, data: [UInt8](data)))
    }
}
