// MedicationManager.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 用药事件管理器：处理响铃、超时、用药结果、用药记录（FR20~FR24）

import Foundation

/// 用药事件管理器
final class MedicationManager {

    private let commandQueue: CommandQueue
    private let logger = BlueLogger.shared

    init(commandQueue: CommandQueue) {
        self.commandQueue = commandQueue
    }

    // MARK: - 下发用药结果通知（FR24）

    /// 向设备下发用药结果通知
    /// - Parameters:
    ///   - status: 通知状态（0=等待 1=响铃开始 2=错过 3=成功）
    ///   - completion: 结果回调
    func sendMedicationNotification(
        status: UInt8,
        completion: @escaping (Result<Void, BlueError>) -> Void
    ) {
        // 用药结果通知使用 0x6F（协议文档注释有歧义，以示例帧为准）
        let data: [UInt8] = [0x6F, 0x00, 0x00, 0x01, status]
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

    // MARK: - 解析上报帧（FR20~FR23）

    /// 解析用药事件上报帧
    /// - Parameter data: 上报帧数据段（DPID=0x68）
    /// - Returns: 用药状态，解析失败返回 nil
    static func parseMedicationEvent(from data: [UInt8]) -> (alarmIndex: Int, status: MedicationStatus)? {
        // 数据格式：[DPID(0x68)][0x00][0x00][0x07][0x01][hour][minute][weekMask][advHigh][advLow][statusByte]
        // alarmIndex 直接从 DPID 推导（0x68 = alarm3 = index 3）
        guard data.count >= 11 else { return nil }
        let dpid = data[0]
        guard let alarmIndex = DPIDConstants.alarmIndex(for: dpid) else { return nil }
        let statusByte = data[10]
        guard let status = MedicationStatus.from(byte: statusByte) else { return nil }
        return (alarmIndex: alarmIndex, status: status)
    }

    /// 解析用药记录上报帧（DPID=0x65）
    /// 数据格式（15字节）：
    ///   [0]=DPID(0x65) [1-3]=type/len(00 00 0B)
    ///   [4]=闹钟DP点 [5-6]=年(高低) [7]=月 [8]=日
    ///   [9]=闹钟小时 [10]=闹钟分钟 [11]=响铃小时 [12]=响铃分钟
    ///   [13]=状态(01取药/02超时/03漏服/04提前) [14]=提前标志
    static func parseMedicationRecord(from data: [UInt8]) -> MedicationRecord? {
        guard data.count >= 14 else { return nil }

        let alarmDPID = data[4]
        guard let alarmIndex = DPIDConstants.alarmIndex(for: alarmDPID) else { return nil }

        let yearHigh = Int(data[5])
        let yearLow  = Int(data[6])
        let year     = (yearHigh << 8) | yearLow
        let month    = Int(data[7])
        let day      = Int(data[8])
        let alarmHour   = Int(data[9])
        let alarmMinute = Int(data[10])
        let eventHour   = Int(data[11])
        let eventMinute = Int(data[12])
        let statusByte  = data[13]

        guard let status = MedicationStatus.from(byte: statusByte) else { return nil }

        var components = DateComponents()
        components.year   = year
        components.month  = month
        components.day    = day
        components.hour   = eventHour
        components.minute = eventMinute
        let date = Calendar.current.date(from: components) ?? Date()

        return MedicationRecord(
            timestamp: Int64(date.timeIntervalSince1970 * 1000),
            alarmIndex: alarmIndex,
            alarmHour: alarmHour,
            alarmMinute: alarmMinute,
            status: status
        )
    }
}
