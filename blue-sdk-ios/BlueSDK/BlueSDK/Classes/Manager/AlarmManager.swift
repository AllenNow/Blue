// AlarmManager.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 闹钟管理器：管理 7 个闹钟槽位的设置、删除、清空（FR15~FR19）

import Foundation

/// 闹钟管理器
final class AlarmManager {

    private let commandQueue: CommandQueue
    private let logger = BlueLogger.shared

    init(commandQueue: CommandQueue) {
        self.commandQueue = commandQueue
    }

    // MARK: - 设置闹钟（FR15）

    /// 设置指定槽位的闹钟
    /// - Parameters:
    ///   - index: 闹钟槽位（1~7）
    ///   - hour: 小时（0~23）
    ///   - minute: 分钟（0~59）
    ///   - weekMask: 星期周期掩码（bit0=周日...bit6=周六，默认 0x7F 每天）
    ///   - completion: 结果回调
    func setAlarm(
        index: Int,
        hour: Int,
        minute: Int,
        weekMask: Int = 0x7F,
        completion: @escaping (Result<AlarmInfo, BlueError>) -> Void
    ) {
        guard let dpid = DPIDConstants.alarmDPID(for: index) else {
            completion(.failure(.invalidParameter))
            return
        }

        // 数据格式：[DPID][0x00][0x00][0x07][0x01][hour][minute][weekMask][0x00][0x00][0x00]
        let data: [UInt8] = [
            dpid,
            0x00, 0x00, 0x07, 0x01,
            UInt8(hour),
            UInt8(minute),
            UInt8(weekMask),
            0x00, 0x00, 0x00
        ]
        let frame = FrameBuilder.build(cmd: CommandCode.sendCommand, data: data)

        commandQueue.enqueue(cmd: CommandCode.sendCommand, frame: frame) { result in
            switch result {
            case .success:
                let alarm = AlarmInfo(
                    index: index,
                    hour: hour,
                    minute: minute,
                    weekMask: weekMask
                )
                completion(.success(alarm))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 删除闹钟（FR16）

    /// 删除指定槽位的闹钟（数据全填 0xFF）
    /// - Parameters:
    ///   - index: 闹钟槽位（1~7）
    ///   - completion: 结果回调
    func deleteAlarm(index: Int, completion: @escaping (Result<Void, BlueError>) -> Void) {
        guard let dpid = DPIDConstants.alarmDPID(for: index) else {
            completion(.failure(.invalidParameter))
            return
        }

        // 删除：数据全填 0xFF
        let data: [UInt8] = [dpid, 0x00, 0x00, 0x07, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
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

    // MARK: - 清空所有闹钟（FR17）

    /// 清空设备上所有闹钟
    /// - Parameter completion: 结果回调
    func clearAllAlarms(completion: @escaping (Result<Void, BlueError>) -> Void) {
        let data: [UInt8] = [DPIDConstants.emptyAllAlarms, 0x01, 0x00, 0x01, 0x01]
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

    // MARK: - 查询闹钟（FR15）

    /// 查询指定槽位的闹钟当前配置
    /// - Parameters:
    ///   - index: 闹钟槽位（1~7）
    ///   - completion: 结果回调
    func queryAlarm(index: Int, completion: @escaping (Result<AlarmInfo, BlueError>) -> Void) {
        guard let dpid = DPIDConstants.alarmDPID(for: index) else {
            completion(.failure(.invalidParameter))
            return
        }

        let data: [UInt8] = [dpid]
        let frame = FrameBuilder.build(cmd: CommandCode.sendCommand, data: data)

        commandQueue.enqueue(cmd: CommandCode.sendCommand, frame: frame) { result in
            switch result {
            case .success(let response):
                if let alarm = AlarmManager.parseAlarmInfo(from: response.data, index: index) {
                    completion(.success(alarm))
                } else {
                    completion(.failure(.protocolError))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 解析设备上报的闹钟数据（FR18、FR19）

    /// 从上报帧数据解析 AlarmInfo
    /// - Parameters:
    ///   - data: 上报帧数据段
    ///   - index: 闹钟槽位索引
    /// - Returns: 解析后的 AlarmInfo，格式错误返回 nil
    static func parseAlarmInfo(from data: [UInt8], index: Int) -> AlarmInfo? {
        // 数据格式：[DPID][0x00][0x00][0x07][enabled][hour][minute][weekMask][ringingState][???][eventStatus]
        guard data.count >= 11 else { return nil }
        let hour         = Int(data[5])
        let minute       = Int(data[6])
        let weekMask     = Int(data[7])
        let ringingState = Int(data[9])
        let eventStatus  = Int(data[10])
        return AlarmInfo(
            index: index,
            hour: hour,
            minute: minute,
            weekMask: weekMask,
            ringingState: ringingState,
            eventStatus: eventStatus
        )
    }
}
