// FrameParserTests.swift
// BlueSDK 单元测试 - 帧解析器

import XCTest
@testable import BlueSDK

final class FrameParserTests: XCTestCase {

    // MARK: - 正常帧解析

    /// 验证：解析查询设备信息帧（无数据）
    func testParseQueryDeviceInfoFrame() {
        let frame: [UInt8] = [0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0x00]
        let result = FrameParser.parse(frame)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cmd, 0x01)
        XCTAssertEqual(result?.data, [])
        XCTAssertEqual(result?.version, 0x00)
    }

    /// 验证：解析时间同步请求帧
    func testParseTimeSyncFrame() {
        let frame: [UInt8] = [0x55, 0xAA, 0x00, 0xE1, 0x00, 0x01, 0x00, 0xE1]
        let result = FrameParser.parse(frame)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cmd, 0xE1)
        XCTAssertEqual(result?.data, [0x00])
    }

    /// 验证：解析设备上报闹钟帧（含多字节数据）
    func testParseDeviceReportFrame() {
        // 设备上报闹钟1为07:00：55 AA 00 07 00 0B 66 00 00 07 01 07 00 7F 00 00 00 05
        let frame: [UInt8] = [0x55, 0xAA, 0x00, 0x07, 0x00, 0x0B,
                               0x66, 0x00, 0x00, 0x07, 0x01, 0x07, 0x00, 0x7F, 0x00, 0x00, 0x00, 0x05]
        let result = FrameParser.parse(frame)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cmd, 0x07)
        XCTAssertEqual(result?.data.count, 11)
        XCTAssertEqual(result?.data.first, 0x66) // DPID = alarm1
    }

    /// 验证：FrameBuilder 构建的帧可被 FrameParser 正确解析（往返测试）
    func testRoundTrip() {
        let originalData: [UInt8] = [0x66, 0x08, 0x00, 0x7F, 0x00]
        let frame = FrameBuilder.build(cmd: 0x06, data: originalData)
        let result = FrameParser.parse(frame)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cmd, 0x06)
        XCTAssertEqual(result?.data, originalData)
    }

    // MARK: - 异常帧处理（静默丢弃，NFR12）

    /// 验证：帧头错误时返回 nil
    func testInvalidHeader() {
        let frame: [UInt8] = [0x11, 0x22, 0x00, 0x01, 0x00, 0x00, 0x00]
        XCTAssertNil(FrameParser.parse(frame))
    }

    /// 验证：CRC8 错误时返回 nil
    func testInvalidCRC() {
        let frame: [UInt8] = [0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0xFF] // CRC 应为 0x00
        XCTAssertNil(FrameParser.parse(frame))
    }

    /// 验证：帧长度不足时返回 nil
    func testTooShortFrame() {
        let frame: [UInt8] = [0x55, 0xAA, 0x00]
        XCTAssertNil(FrameParser.parse(frame))
    }

    /// 验证：空数组返回 nil
    func testEmptyFrame() {
        XCTAssertNil(FrameParser.parse([]))
    }

    /// 验证：长度字段与实际数据不符时返回 nil
    func testLengthMismatch() {
        // 声明数据长度为 2，但实际只有 1 字节数据
        let frame: [UInt8] = [0x55, 0xAA, 0x00, 0x01, 0x00, 0x02, 0x00, 0x00]
        XCTAssertNil(FrameParser.parse(frame))
    }

    // MARK: - Data 类型重载

    func testParseWithData() {
        let frame = Data([0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0x00])
        let result = FrameParser.parse(frame)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cmd, 0x01)
    }
}
