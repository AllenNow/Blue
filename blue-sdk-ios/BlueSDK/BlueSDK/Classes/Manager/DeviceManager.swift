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
    /// - Parameter completion: 结果回调，成功返回 DeviceInfo
    func queryDeviceInfo(completion: @escaping (Result<DeviceInfo, BlueError>) -> Void) {
        let frame = FrameBuilder.build(cmd: CommandCode.queryDeviceInfo)
        commandQueue.enqueue(cmd: CommandCode.queryDeviceInfo, frame: frame) { result in
            switch result {
            case .success(let response):
                // 解析固件版本（ASCII 字符串，如 "1.0.0"）
                let versionBytes = response.data
                let version = String(bytes: versionBytes, encoding: .ascii) ?? "Unknown"
                let info = DeviceInfo(firmwareVersion: version, deviceId: "")
                completion(.success(info))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 时间同步（FR13、FR14）

    /// 向设备下发当前系统时间
    /// - Parameters:
    ///   - date: 要同步的时间，默认当前系统时间
    ///   - completion: 结果回调
    func syncTime(date: Date = Date(), completion: @escaping (Result<Void, BlueError>) -> Void) {
        let data = buildTimeSyncData(from: date)
        let frame = FrameBuilder.build(cmd: CommandCode.timeSync, data: data)
        commandQueue.enqueue(cmd: CommandCode.timeSync, frame: frame) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 私有方法

    /// 构建时间同步数据字节
    /// 格式：[年高][年低][月][日][时][分][秒][星期][时区高][时区低]
    ///
    /// ⚠️ TODO: 协议文档示例帧存疑，待硬件方确认
    /// 文档示例：55 AA 00 E1 00 0B 00 00 01 0C 1E 0F 34 1F 01 03 20 9C
    /// 数据段 11 字节：00 00 01 0C 1E 0F 34 1F 01 03 20
    /// 问题1：前两字节 00 00 不符合 2024年(0x07E8) 的年份编码
    /// 问题2：当前实现只有 10 字节，比示例少 1 字节
    /// 问题3：时区字段 0x0320=800分钟 不符合 UTC+8(480分钟)
    /// 待确认：各字段的完整定义和字节顺序
    private func buildTimeSyncData(from date: Date) -> [UInt8] {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .weekday],
            from: date
        )

        let year = components.year ?? 2024
        let yearHigh = UInt8((year >> 8) & 0xFF)
        let yearLow  = UInt8(year & 0xFF)
        let month    = UInt8(components.month ?? 1)
        let day      = UInt8(components.day ?? 1)
        let hour     = UInt8(components.hour ?? 0)
        let minute   = UInt8(components.minute ?? 0)
        let second   = UInt8(components.second ?? 0)
        // 星期：Calendar 中 1=周日，协议中 bit0=周日
        let weekday  = UInt8((components.weekday ?? 1) - 1)

        // 时区偏移（秒），转换为分钟
        let timeZoneOffset = TimeZone.current.secondsFromGMT() / 60
        let tzHigh = UInt8((timeZoneOffset >> 8) & 0xFF)
        let tzLow  = UInt8(timeZoneOffset & 0xFF)

        return [yearHigh, yearLow, month, day, hour, minute, second, weekday, tzHigh, tzLow]
    }
}
