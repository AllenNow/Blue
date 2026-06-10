// FrameParser.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 帧解析器：从 BLE notify 数据流中识别并解析完整的协议帧
// CRC8 校验失败时静默丢弃，不抛出异常（NFR12）

import Foundation

/// 解析后的协议帧
struct ParsedFrame {
    /// 协议版本号
    let version: UInt8
    /// 命令字
    let cmd: UInt8
    /// 数据内容（不含帧头、版本、CMD、长度、CRC8）
    let data: [UInt8]
}

/// 帧解析器
/// 从 BLE notify 原始字节流中解析完整协议帧
enum FrameParser {

    /// 解析单个完整帧
    /// - Parameter bytes: 原始字节数组（应为一个完整帧）
    /// - Returns: 解析成功返回 ParsedFrame，帧头错误或 CRC8 校验失败返回 nil（静默丢弃）
    static func parse(_ bytes: [UInt8]) -> ParsedFrame? {
        // 最小帧长度检查
        guard bytes.count >= FrameConstants.minFrameLength else {
            return nil
        }

        // 帧头校验
        guard bytes[0] == FrameConstants.headerByte1,
              bytes[1] == FrameConstants.headerByte2 else {
            return nil
        }

        // 解析长度字段
        let lenHigh = Int(bytes[FrameConstants.lenHighOffset])
        let lenLow  = Int(bytes[FrameConstants.lenLowOffset])
        let dataLen = (lenHigh << 8) | lenLow

        // 帧完整性检查：帧头6字节 + 数据 + CRC1
        let expectedLength = FrameConstants.minFrameLength + dataLen
        guard bytes.count == expectedLength else {
            return nil
        }

        // CRC8 校验（失败时静默丢弃，NFR12）
        guard CRC8Calculator.verify(bytes) else {
            return nil
        }

        // 提取字段
        let version = bytes[FrameConstants.versionOffset]
        let cmd     = bytes[FrameConstants.cmdOffset]
        let data    = dataLen > 0
            ? Array(bytes[FrameConstants.dataOffset ..< FrameConstants.dataOffset + dataLen])
            : []

        return ParsedFrame(version: version, cmd: cmd, data: data)
    }

    /// 解析 Data 类型的帧
    /// - Parameter data: 原始帧数据
    /// - Returns: 解析成功返回 ParsedFrame，否则返回 nil
    static func parse(_ data: Data) -> ParsedFrame? {
        return parse([UInt8](data))
    }
}
