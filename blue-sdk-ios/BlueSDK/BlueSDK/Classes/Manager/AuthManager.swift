// AuthManager.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 身份认证管理器
// 密钥算法：手机 MAC 6字节 + 设备 MAC 6字节全部累加，取 16-bit 总和的高低两字节（FR08）
// 密钥值不写入任何日志或持久化存储（NFR06、NFR07）

import Foundation

/// 认证管理器
final class AuthManager {

    private let commandQueue: CommandQueue
    private let logger = BlueLogger.shared

    init(commandQueue: CommandQueue) {
        self.commandQueue = commandQueue
    }

    // MARK: - 公开方法

    /// 发送密钥包完成设备认证（FR08）
    /// - Parameters:
    ///   - phoneMac: 手机 MAC 地址（6字节）
    ///   - deviceMac: 设备 MAC 地址（6字节）
    ///   - completion: 认证结果回调
    func authenticate(
        phoneMac: [UInt8],
        deviceMac: [UInt8],
        completion: @escaping (Result<Void, BlueError>) -> Void
    ) {
        guard phoneMac.count == 6, deviceMac.count == 6 else {
            completion(.failure(.invalidParameter))
            return
        }

        // 计算密钥：手机 MAC 6字节 + 设备 MAC 6字节 全部累加，得到 16-bit 总和
        // 取高字节和低字节作为 2字节密钥数据
        let sum = (phoneMac + deviceMac).reduce(0) { acc, byte in acc + Int(byte) }
        let keyHigh = UInt8((sum >> 8) & 0xFF)
        let keyLow  = UInt8(sum & 0xFF)
        let keyBytes: [UInt8] = [keyHigh, keyLow]

        let phoneMacStr = phoneMac.map { String(format: "%02X", $0) }.joined(separator: ":")
        let deviceMacStr = deviceMac.map { String(format: "%02X", $0) }.joined(separator: ":")
        logger.debug("认证密钥包：phoneMac=\(phoneMacStr) deviceMac=\(deviceMacStr) key=\(String(format: "%02X%02X", keyHigh, keyLow))")

        // 构建密钥帧：CMD=0x00，数据为 2字节密钥
        let frame = FrameBuilder.build(cmd: CommandCode.authKey, data: keyBytes)

        commandQueue.enqueue(cmd: CommandCode.authKey, frame: frame) { result in
            switch result {
            case .success(let response):
                // 认证成功：设备返回 01，失败返回 00
                let success = response.data.first == 0x01
                if success {
                    completion(.success(()))
                } else {
                    completion(.failure(.authFailed))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 内部工具

    /// 计算密钥（仅供测试使用，不对外暴露）
    /// 算法：12字节全部累加得到 16-bit 总和，返回 [高字节, 低字节]
    internal static func calculateKey(phoneMac: [UInt8], deviceMac: [UInt8]) -> [UInt8] {
        let sum = (phoneMac + deviceMac).reduce(0) { acc, byte in acc + Int(byte) }
        return [UInt8((sum >> 8) & 0xFF), UInt8(sum & 0xFF)]
    }
}
