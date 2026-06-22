// AudioManager.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 音频与系统设置管理器（FR25~FR31）
// 协议 DPID 对应关系：
//   0x6D - 声音类型（0-静音 1-声音A 2-声音B 3-声音C）— APP 下发 & 设备上报
//   0x6E - 提醒持续时间 / 音量设置（通过 type 字段区分）
//   0x6F - 用药结果通知（APP→设备）
//   0x73 - 时制（0-12H 1-24H）
//   0x74 - 当前闹钟静音（0-关 1-开）

import Foundation

/// 音频与系统设置管理器
final class AudioManager {

    private let commandQueue: CommandQueue
    private let logger = BlueLogger.shared

    init(commandQueue: CommandQueue) {
        self.commandQueue = commandQueue
    }

    // MARK: - 声音类型设置（DPID=0x6D）

    /// 设置设备铃声类型
    /// APP 下发用 DPID=0x6D（TYPEOFSOUND），值：00=静音 01=类型A 02=类型B 03=类型C
    func setSoundType(_ type: SoundType, completion: @escaping (Result<Void, BlueError>) -> Void) {
        let data: [UInt8] = [DPIDConstants.typeOfSound, 0x04, 0x00, 0x01, type.protocolValue]
        sendCommand(data: data, completion: completion)
    }

    // MARK: - 提醒持续时间设置（DPID=0x70）

    /// 设置提醒持续时长（分钟）
    /// 设置提醒持续时长
    /// 帧格式：6E 02 00 04 00 00 00 [值]
    /// 设置提醒持续时长（1~5分钟）
    /// 协议示例：55 AA 00 06 00 08 6E 02 00 04 00 00 00 05 86
    func setAlertDuration(_ minutes: Int, completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard minutes >= 1 && minutes <= 5 else {
            completion(.failure(.invalidParameter))
            return
        }
        let data: [UInt8] = [
            DPIDConstants.alertDuration,
            0x02, 0x00, 0x04,
            0x00, 0x00, 0x00,
            UInt8(minutes)
        ]
        sendCommand(data: data, completion: completion)
    }

    // MARK: - 音量设置

    /// 设置设备提醒音量
    /// 协议示例：55 AA 00 06 00 05 78 04 00 01 01 88（低音量）
    /// DPID=0x78, type=0x04, len=0x01, value: 01=低 02=中 03=高
    func setVolume(_ level: VolumeLevel, completion: @escaping (Result<Void, BlueError>) -> Void) {
        let data: [UInt8] = [0x78, 0x04, 0x00, 0x01, level.protocolValue]
        sendCommand(data: data, completion: completion)
    }

    // MARK: - 静音设置

    /// 设置静音（实际通过铃声类型=0x00实现）
    /// enabled=true 时设置铃声类型为静音，enabled=false 时恢复为类型A
    func setSilence(_ enabled: Bool, completion: @escaping (Result<Void, BlueError>) -> Void) {
        if enabled {
            setSoundType(.mute, completion: completion)
        } else {
            setSoundType(.typeA, completion: completion)
        }
    }

    // MARK: - 时间格式设置（DPID=0x73）

    func setTimeFormat(_ format: TimeFormat, completion: @escaping (Result<Void, BlueError>) -> Void) {
        let data: [UInt8] = [DPIDConstants.timeFormat, 0x04, 0x00, 0x01, format.protocolValue]
        sendCommand(data: data, completion: completion)
    }

    // MARK: - 解析上报帧

    /// 解析铃声类型上报（DPID=0x6D）
    /// 设备上报值：0=静音, 1=类型A, 2=类型B
    static func parseSoundType(from data: [UInt8]) -> SoundType? {
        guard data.count >= 5 else { return nil }
        let value = data[4]
        return SoundType.from(byte: value)
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
