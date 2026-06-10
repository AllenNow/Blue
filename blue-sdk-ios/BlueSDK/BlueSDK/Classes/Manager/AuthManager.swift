// AuthManager.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 身份认证管理器
// 密钥算法：手机 MAC + 设备 MAC 逐字节累加取低字节（FR08）
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

        // 计算密钥：手机 MAC + 设备 MAC 逐字节累加，取低字节
        // 密钥值不输出到日志（NFR06、NFR07）
        let keyBytes = zip(phoneMac, deviceMac).map { UInt8(($0.0 &+ $0.1) & 0xFF) }

        logger.debug("发送认证密钥包（密钥值已脱敏）")

        // 构建密钥帧：CMD=0x00，数据为密钥字节
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
    internal static func calculateKey(phoneMac: [UInt8], deviceMac: [UInt8]) -> [UInt8] {
        return zip(phoneMac, deviceMac).map { UInt8(($0.0 &+ $0.1) & 0xFF) }
    }
}
