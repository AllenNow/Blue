// DeviceManager.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 设备信息查询与时间同步管理器（FR12~FR14）

import Foundation

/// 设备管理器
final class DeviceManager {

    private let commandQueue: CommandQueue
    private let logger = BlueLogger.shared

    init(commandQueue: CommandQueue) {
        self.commandQueue = commandQueue
    }

    // MARK: - 设备信息查询（FR12）

    /// 查询设备基础信息
    /// 应答格式：[MAC 6字节][...][固件版本 ASCII]
    /// 示例：6F 74 36 74 74 64 35 6A 31 2E 30 2E 30
    ///       MAC=6F:74:36:74:74:64, 固件版本="1.0.0"
    /// - Parameter completion: 结果回调，成功返回 DeviceInfo
    func queryDeviceInfo(completion: @escaping (Result<DeviceInfo, BlueError>) -> Void) {
        let frame = FrameBuilder.build(cmd: CommandCode.queryDeviceInfo)
        commandQueue.enqueue(cmd: CommandCode.queryDeviceInfo, frame: frame) { result in
            switch result {
            case .success(let response):
                let data = response.data
                guard data.count >= 6 else {
                    completion(.failure(.invalidParameter))
                    return
                }
                // 前 6 字节为设备 MAC 地址
                let macAddress = Array(data.prefix(6))
                // 从第7字节开始查找固件版本（匹配 "x.x.x" 格式）
                let remaining = Array(data.suffix(from: 6))
                let asciiStr = String(bytes: remaining, encoding: .ascii) ?? ""
                let version: String
                if let range = asciiStr.range(of: "[0-9]+\\.[0-9]+\\.[0-9]+", options: .regularExpression) {
                    version = String(asciiStr[range])
                } else {
                    version = "Unknown"
                }
                let info = DeviceInfo(firmwareVersion: version, macAddress: macAddress)
                completion(.success(info))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 时间同步（FR13、FR14）

    /// 向设备下发当前系统时间
    /// 注意：时间同步为单向下发，设备不返回应答。直接发送，不入 CommandQueue 等待。
    /// - Parameters:
    ///   - date: 要同步的时间，默认当前系统时间
    ///   - completion: 结果回调（发送成功即视为成功）
    func syncTime(date: Date = Date(), completion: @escaping (Result<Void, BlueError>) -> Void) {
        let data = buildTimeSyncData(from: date)
        let frame = FrameBuilder.build(cmd: CommandCode.timeSync, data: data)
        // 直接发送，不等待应答（协议约定设备不对时间同步作应答）
        commandQueue.sendDirect(frame: frame)
        completion(.success(()))
    }

    // MARK: - 私有方法

    /// 构建时间同步数据字节
    /// 格式（11字节）：[0x00][0x00][年偏移(从2018)][月][日][时][分][秒][星期(1=周一~7=周日)][时区高][时区低]
    /// 参考协议文档示例：55 AA 00 E1 00 0B 00 00 01 0C 1E 0F 34 1F 01 03 20 9C
    /// 解析：年=2018+1=2019, 月=12, 日=30, 时=15, 分=52, 秒=31, 星期一
    private func buildTimeSyncData(from date: Date) -> [UInt8] {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .weekday],
            from: date
        )

        let year = components.year ?? 2024
        let yearOffset = UInt8(min(max(year - 2018, 0), 255))
        let month    = UInt8(components.month ?? 1)
        let day      = UInt8(components.day ?? 1)
        let hour     = UInt8(components.hour ?? 0)
        let minute   = UInt8(components.minute ?? 0)
        let second   = UInt8(components.second ?? 0)
        // 星期：Calendar 中 1=周日...7=周六 → 协议中 1=周一...7=周日
        let calWeekday = components.weekday ?? 1
        let weekday = UInt8(calWeekday == 1 ? 7 : calWeekday - 1)

        // 时区偏移（秒），转换为分钟
        let timeZoneOffset = TimeZone.current.secondsFromGMT() / 60
        let tzHigh = UInt8((timeZoneOffset >> 8) & 0xFF)
        let tzLow  = UInt8(timeZoneOffset & 0xFF)

        return [0x00, 0x00, yearOffset, month, day, hour, minute, second, weekday, tzHigh, tzLow]
    }
}
