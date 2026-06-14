// FrameBuilderTests.swift
// BlueSDK 单元测试 - 帧构建器

import XCTest
@testable import BlueSDK

final class FrameBuilderTests: XCTestCase {

    /// 验证：build(0x01, []) → 55 AA 00 01 00 00 00（查询设备信息）
    func testQueryDeviceInfoFrame() {
        let frame = FrameBuilder.build(cmd: 0x01)
        XCTAssertEqual(frame, [0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0x00])
    }

    /// 验证：时间同步请求帧 55 AA 00 E1 00 01 00 E1
    func testTimeSyncRequestFrame() {
        let frame = FrameBuilder.build(cmd: 0xE1, data: [0x00])
        XCTAssertEqual(frame, [0x55, 0xAA, 0x00, 0xE1, 0x00, 0x01, 0x00, 0xE1])
    }

    /// 验证：密钥包帧 55 AA 00 00 00 02 07 74 7C
    func testAuthKeyFrame() {
        let frame = FrameBuilder.build(cmd: 0x00, data: [0x07, 0x74])
        XCTAssertEqual(frame, [0x55, 0xAA, 0x00, 0x00, 0x00, 0x02, 0x07, 0x74, 0x7C])
    }

    /// 验证：设置闹钟1为12:00 → 55 AA 00 06 00 0B 66 00 00 07 01 0C 00 7F 00 00 00 09
    func testSetAlarm1Frame() {
        let data: [UInt8] = [0x66, 0x00, 0x00, 0x07, 0x01, 0x0C, 0x00, 0x7F, 0x00, 0x00, 0x00]
        let frame = FrameBuilder.build(cmd: 0x06, data: data)
        XCTAssertEqual(frame, [0x55, 0xAA, 0x00, 0x06, 0x00, 0x0B,
                                0x66, 0x00, 0x00, 0x07, 0x01, 0x0C, 0x00, 0x7F, 0x00, 0x00, 0x00, 0x09])
    }

    /// 验证：设置闹钟2为15:30 → 55 AA 00 06 00 0B 67 00 00 07 01 0F 1E 7F 00 00 00 2B
    func testSetAlarm2Frame() {
        let data: [UInt8] = [0x67, 0x00, 0x00, 0x07, 0x01, 0x0F, 0x1E, 0x7F, 0x00, 0x00, 0x00]
        let frame = FrameBuilder.build(cmd: 0x06, data: data)
        XCTAssertEqual(frame, [0x55, 0xAA, 0x00, 0x06, 0x00, 0x0B,
                                0x67, 0x00, 0x00, 0x07, 0x01, 0x0F, 0x1E, 0x7F, 0x00, 0x00, 0x00, 0x2B])
    }

    /// 验证：删除闹钟7 → 55 AA 00 06 00 0B 6C 00 00 07 FF FF FF FF FF FF FF 7C
    func testDeleteAlarm7Frame() {
        let data: [UInt8] = [0x6C, 0x00, 0x00, 0x07, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
        let frame = FrameBuilder.build(cmd: 0x06, data: data)
        XCTAssertEqual(frame, [0x55, 0xAA, 0x00, 0x06, 0x00, 0x0B,
                                0x6C, 0x00, 0x00, 0x07, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7C])
    }

    /// 验证：数据长度超过 255 时 Len 高字节正确填充
    func testLargeDataLenHighByte() {
        let data = [UInt8](repeating: 0x00, count: 256)
        let frame = FrameBuilder.build(cmd: 0x06, data: data)
        // Len = 256 → lenHigh = 0x01, lenLow = 0x00
        XCTAssertEqual(frame[4], 0x01)
        XCTAssertEqual(frame[5], 0x00)
        XCTAssertEqual(frame.count, 256 + 7) // 数据256 + 帧头6 + CRC1
    }

    /// 验证：Data 类型重载
    func testBuildWithData() {
        let frame = FrameBuilder.build(cmd: 0x01, data: Data())
        XCTAssertEqual([UInt8](frame), [0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0x00])
    }

    /// 验证：帧末尾 CRC8 正确
    func testFrameCRC8IsCorrect() {
        let frame = FrameBuilder.build(cmd: 0x01)
        XCTAssertTrue(CRC8Calculator.verify(frame))
    }
}

    // MARK: - 待确认

    /// ⚠️ TODO: 时间同步帧格式待硬件方确认后补充测试
    /// 协议文档示例帧：55 AA 00 E1 00 0B 00 00 01 0C 1E 0F 34 1F 01 03 20 9C
    /// 疑点：年份字段、字节总数、时区编码均与预期不符
    /// 参考 DeviceManager.buildTimeSyncData() 中的详细说明
    func testTimeSyncDataFrame_TODO() {
        // 此测试暂时跳过，待协议确认后实现
        // XCTSkip("时间同步帧格式待硬件方确认")
    }
