// StreamFrameParserTests.swift
// BlueSDK 单元测试 - 流式帧解析器（粘包/分包处理）

import XCTest
@testable import BlueSDK

final class StreamFrameParserTests: XCTestCase {

    var parser: StreamFrameParser!
    var parsedFrames: [ParsedFrame] = []

    override func setUp() {
        super.setUp()
        parser = StreamFrameParser()
        parsedFrames = []
        parser.onFrameParsed = { [weak self] frame in
            self?.parsedFrames.append(frame)
        }
    }

    // MARK: - 正常情况：一次接收一个完整帧

    func testSingleCompleteFrame() {
        // 查询设备信息帧：55 AA 00 01 00 00 00
        let frame: [UInt8] = [0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0x00]
        parser.receive(frame)
        XCTAssertEqual(parsedFrames.count, 1)
        XCTAssertEqual(parsedFrames[0].cmd, 0x01)
    }

    // MARK: - 粘包：一次接收包含两个完整帧

    func testTwoFramesStuckTogether() {
        // 帧1：55 AA 00 01 00 00 00（查询设备信息）
        // 帧2：55 AA 00 E1 00 01 00 E1（时间同步请求）
        let data: [UInt8] = [
            0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0x00,
            0x55, 0xAA, 0x00, 0xE1, 0x00, 0x01, 0x00, 0xE1
        ]
        parser.receive(data)
        XCTAssertEqual(parsedFrames.count, 2)
        XCTAssertEqual(parsedFrames[0].cmd, 0x01)
        XCTAssertEqual(parsedFrames[1].cmd, 0xE1)
    }

    // MARK: - 分包：一个帧分两次到达

    func testFrameSplitInTwo() {
        // 帧：55 AA 00 01 00 00 00 分两次到达
        let part1: [UInt8] = [0x55, 0xAA, 0x00]
        let part2: [UInt8] = [0x01, 0x00, 0x00, 0x00]

        parser.receive(part1)
        XCTAssertEqual(parsedFrames.count, 0, "第一部分不够完整，不应解析")

        parser.receive(part2)
        XCTAssertEqual(parsedFrames.count, 1, "两部分合并后应解析出完整帧")
        XCTAssertEqual(parsedFrames[0].cmd, 0x01)
    }

    // MARK: - 分包：帧头在第一包，数据在第二包

    func testFrameSplitAtData() {
        // 密钥包帧：55 AA 00 00 00 02 07 74 7C，在长度字段之后分割
        let part1: [UInt8] = [0x55, 0xAA, 0x00, 0x00, 0x00, 0x02]
        let part2: [UInt8] = [0x07, 0x74, 0x7C]

        parser.receive(part1)
        XCTAssertEqual(parsedFrames.count, 0)

        parser.receive(part2)
        XCTAssertEqual(parsedFrames.count, 1)
        XCTAssertEqual(parsedFrames[0].cmd, 0x00)
        XCTAssertEqual(parsedFrames[0].data, [0x07, 0x74])
    }

    // MARK: - 垃圾数据 + 完整帧

    func testGarbageBeforeFrame() {
        // 垃圾数据 + 完整帧
        let data: [UInt8] = [0x11, 0x22, 0x33, 0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0x00]
        parser.receive(data)
        XCTAssertEqual(parsedFrames.count, 1, "应跳过垃圾数据并解析出完整帧")
        XCTAssertEqual(parsedFrames[0].cmd, 0x01)
    }

    // MARK: - CRC 错误帧被丢弃，后续帧正常解析

    func testCRCErrorFrameDiscarded() {
        // 错误帧（CRC 不对）+ 正确帧
        let data: [UInt8] = [
            0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0xFF, // CRC 错误
            0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0x00  // CRC 正确
        ]
        parser.receive(data)
        XCTAssertEqual(parsedFrames.count, 1, "CRC 错误帧被丢弃，正确帧正常解析")
        XCTAssertEqual(parsedFrames[0].cmd, 0x01)
    }

    // MARK: - reset 清空缓冲区

    func testResetClearsBuffer() {
        // 发送不完整数据
        parser.receive([0x55, 0xAA, 0x00])
        XCTAssertEqual(parsedFrames.count, 0)

        // reset
        parser.reset()

        // 发送新的完整帧
        parser.receive([0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0x00])
        XCTAssertEqual(parsedFrames.count, 1, "reset 后应能正常解析新帧")
    }

    // MARK: - 三次分包

    func testFrameSplitInThree() {
        // 设置闹钟帧分三次到达
        let part1: [UInt8] = [0x55, 0xAA]
        let part2: [UInt8] = [0x00, 0x06, 0x00, 0x0B, 0x66, 0x00, 0x00]
        let part3: [UInt8] = [0x07, 0x01, 0x0C, 0x00, 0x7F, 0x00, 0x00, 0x00, 0x09]

        parser.receive(part1)
        XCTAssertEqual(parsedFrames.count, 0)
        parser.receive(part2)
        XCTAssertEqual(parsedFrames.count, 0)
        parser.receive(part3)
        XCTAssertEqual(parsedFrames.count, 1)
        XCTAssertEqual(parsedFrames[0].cmd, 0x06)
        XCTAssertEqual(parsedFrames[0].data.count, 11)
    }
}
