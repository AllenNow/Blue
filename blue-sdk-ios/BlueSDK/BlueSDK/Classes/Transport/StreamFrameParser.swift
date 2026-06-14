// StreamFrameParser.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 流式帧解析器：处理 BLE notify 粘包/分包
// BLE notify 回调可能：
//   1. 一次包含一个完整帧（正常情况）
//   2. 一次包含多个完整帧（粘包）
//   3. 一个帧分多次到达（分包）
// 本解析器通过缓冲区累积数据，识别完整帧后回调

import Foundation

/// 流式帧解析器
/// 线程安全，通过内部缓冲区处理 BLE 数据流的粘包/分包
final class StreamFrameParser {

    // MARK: - 配置

    /// 缓冲区最大容量（防止异常数据无限累积）
    private static let maxBufferSize = 1024

    // MARK: - 状态

    private var buffer: [UInt8] = []
    private let lock = NSLock()
    private let logger = BlueLogger.shared

    /// 帧解析完成回调
    var onFrameParsed: ((ParsedFrame) -> Void)?

    // MARK: - 公开方法

    /// 接收新的 BLE notify 数据（可能是完整帧、部分帧、或多帧粘包）
    /// - Parameter data: BLE notify 回调的原始数据
    func receive(_ data: Data) {
        receive([UInt8](data))
    }

    /// 接收新的字节数据
    /// - Parameter bytes: 原始字节数组
    func receive(_ bytes: [UInt8]) {
        lock.lock()
        defer { lock.unlock() }

        buffer.append(contentsOf: bytes)

        // 防止缓冲区无限增长（异常保护）
        if buffer.count > StreamFrameParser.maxBufferSize {
            logger.warn("StreamFrameParser 缓冲区超限（\(buffer.count)字节），已清空")
            buffer.removeAll()
            return
        }

        // 尝试从缓冲区中提取所有完整帧
        extractFrames()
    }

    /// 清空缓冲区（断开连接时调用）
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        buffer.removeAll()
    }

    // MARK: - 私有方法

    private func extractFrames() {
        while true {
            // 查找帧头 0x55 0xAA
            guard let headerIndex = findHeader() else {
                // 没找到帧头，丢弃所有数据
                if !buffer.isEmpty {
                    logger.debug("StreamFrameParser：未找到帧头，丢弃 \(buffer.count) 字节")
                    buffer.removeAll()
                }
                return
            }

            // 丢弃帧头之前的垃圾数据
            if headerIndex > 0 {
                logger.debug("StreamFrameParser：丢弃帧头前 \(headerIndex) 字节垃圾数据")
                buffer.removeFirst(headerIndex)
            }

            // 检查是否有足够数据读取长度字段
            guard buffer.count >= FrameConstants.dataOffset else {
                // 数据不够，等待更多数据（分包）
                return
            }

            // 读取数据长度
            let lenHigh = Int(buffer[FrameConstants.lenHighOffset])
            let lenLow  = Int(buffer[FrameConstants.lenLowOffset])
            let dataLen = (lenHigh << 8) | lenLow

            // 计算完整帧长度
            let frameLength = FrameConstants.minFrameLength + dataLen

            // 检查缓冲区是否有完整帧
            guard buffer.count >= frameLength else {
                // 数据不够，等待更多数据（分包）
                return
            }

            // 提取完整帧数据
            let frameBytes = Array(buffer.prefix(frameLength))
            buffer.removeFirst(frameLength)

            // 解析帧（CRC 校验失败会静默丢弃）
            if let frame = FrameParser.parse(frameBytes) {
                onFrameParsed?(frame)
            } else {
                logger.warn("StreamFrameParser：帧 CRC 校验失败或格式错误，已丢弃 \(frameLength) 字节")
            }
        }
    }

    /// 在缓冲区中查找帧头 0x55 0xAA 的位置
    /// - Returns: 帧头起始位置，未找到返回 nil
    private func findHeader() -> Int? {
        guard buffer.count >= 2 else { return nil }
        for i in 0..<(buffer.count - 1) {
            if buffer[i] == FrameConstants.headerByte1 &&
               buffer[i + 1] == FrameConstants.headerByte2 {
                return i
            }
        }
        return nil
    }
}
