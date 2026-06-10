// AudioManager.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 音频与系统设置管理器（FR25~FR31）

import Foundation

/// 音频与系统设置管理器
final class AudioManager {

    private let commandQueue: CommandQueue
    private let logger = BlueLogger.shared

    init(commandQueue: CommandQueue) {
        self.commandQueue = commandQueue
    }

    // MARK: - 音量设置（FR25）

    /// 设置设备提醒音量
    /// - Parameters:
    ///   - level: 音量级别（低/中/高）
    ///   - completion: 结果回调
    func setVolume(_ level: VolumeLevel, completion: @escaping (Result<Void, BlueError>) -> Void) {
        let data: [UInt8] = [DPIDConstants.volumeLevel, 0x04, 0x00, 0x01, level.protocolValue]
        sendCommand(data: data, completion: completion)
    }

    // MARK: - 铃声类型设置（FR26）

    func setSoundType(_ type: SoundType, completion: @escaping (Result<Void, BlueError>) -> Void) {
        let data: [UInt8] = [DPIDConstants.soundTypeSetting, 0x04, 0x00, 0x01, type.protocolValue]
        sendCommand(data: data, completion: completion)
    }

    // MARK: - 静音设置（FR28）

    func setSilence(_ enabled: Bool, completion: @escaping (Result<Void, BlueError>) -> Void) {
        let value: UInt8 = enabled ? 0x01 : 0x00
        let data: [UInt8] = [DPIDConstants.silence, 0x04, 0x00, 0x01, value]
        sendCommand(data: data, completion: completion)
    }

    // MARK: - 提醒持续时长设置（FR29）

    func setAlertDuration(_ minutes: Int, completion: @escaping (Result<Void, BlueError>) -> Void) {
        let data: [UInt8] = [
            DPIDConstants.alertDurationSetting,
            0x02, 0x00, 0x04,
            0x00, 0x00, 0x00,
            UInt8(minutes)
        ]
        sendCommand(data: data, completion: completion)
    }

    // MARK: - 时间格式设置（FR30）

    /// 设置设备时间显示格式
    /// - Parameters:
    ///   - format: 时间格式（12/24小时制）
    ///   - completion: 结果回调
    func setTimeFormat(_ format: TimeFormat, completion: @escaping (Result<Void, BlueError>) -> Void) {
        let data: [UInt8] = [DPIDConstants.timeFormat, 0x04, 0x00, 0x01, format.protocolValue]
        sendCommand(data: data, completion: completion)
    }

    // MARK: - 解析上报帧（FR27、FR31）

    /// 解析铃声类型上报（DPID=0x6D）
    static func parseSoundType(from data: [UInt8]) -> SoundType? {
        guard data.count >= 5 else { return nil }
        return SoundType.from(byte: data[4])
    }

    /// 解析时间格式上报（DPID=0x73）
    static func parseTimeFormat(from data: [UInt8]) -> TimeFormat? {
        guard data.count >= 5 else { return nil }
        return TimeFormat(rawValue: Int(data[4]))
    }

    // MARK: - 私有方法

    private func sendCommand(data: [UInt8], completion: @escaping (Result<Void, BlueError>) -> Void) {
        let frame = FrameBuilder.build(cmd: CommandCode.sendCommand, data: data)
        commandQueue.enqueue(cmd: CommandCode.sendCommand, frame: frame) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
