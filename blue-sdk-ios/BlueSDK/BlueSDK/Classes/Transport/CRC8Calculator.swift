// CRC8Calculator.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// CRC8 校验计算器
// 算法：从帧头第一字节开始，所有字节累加和对 256 求余
// 公式：crc = (sum of bytes[0..6+Len-1]) % 256

import Foundation

/// CRC8 校验计算器
/// 唯一实现，不允许变体
enum CRC8Calculator {

    /// 计算字节数组的 CRC8 校验值
    /// - Parameter bytes: 参与校验的字节数组（从帧头第一字节到数据最后一字节）
    /// - Returns: CRC8 校验值（累加和对 256 求余）
    static func calculate(_ bytes: [UInt8]) -> UInt8 {
        let sum = bytes.reduce(0) { (acc: Int, byte: UInt8) in
            acc + Int(byte)
        }
        return UInt8(sum % 256)
    }

    /// 计算 Data 的 CRC8 校验值
    /// - Parameter data: 参与校验的数据（从帧头第一字节到数据最后一字节）
    /// - Returns: CRC8 校验值
    static func calculate(_ data: Data) -> UInt8 {
        return calculate([UInt8](data))
    }

    /// 验证帧数据的 CRC8 校验值是否正确
    /// - Parameter frame: 完整帧数据（包含末尾的 CRC8 字节）
    /// - Returns: 校验是否通过
    static func verify(_ frame: [UInt8]) -> Bool {
        guard frame.count >= FrameConstants.minFrameLength else { return false }
        let payload = Array(frame.dropLast())
        let expected = frame.last!
        return calculate(payload) == expected
    }
}
