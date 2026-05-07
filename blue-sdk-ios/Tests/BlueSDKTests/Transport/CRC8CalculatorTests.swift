// CRC8CalculatorTests.swift
// BlueSDK 单元测试
//
// 使用协议文档中的真实帧数据验证 CRC8 计算正确性

import XCTest
@testable import BlueSDK

final class CRC8CalculatorTests: XCTestCase {

    // MARK: - 基础计算验证

    /// 验证：查询设备信息帧 55 AA 00 01 00 00 → CRC8 = 0x00
    /// (0x55+0xAA+0x00+0x01+0x00+0x00) = 256 → 256 % 256 = 0
    func testQueryDeviceInfoFrame() {
        let payload: [UInt8] = [0x55, 0xAA, 0x00, 0x01, 0x00, 0x00]
        XCTAssertEqual(CRC8Calculator.calculate(payload), 0x00)
    }

    /// 验证：密钥包帧 55 AA 00 00 00 02 07 74 → CRC8 = 0x7C
    /// (0x55+0xAA+0x00+0x00+0x00+0x02+0x07+0x74) = 124 → 0x7C
    func testAuthKeyFrame() {
        let payload: [UInt8] = [0x55, 0xAA, 0x00, 0x00, 0x00, 0x02, 0x07, 0x74]
        XCTAssertEqual(CRC8Calculator.calculate(payload), 0x7C)
    }

    /// 验证：时间同步请求帧 55 AA 00 E1 00 01 00 → CRC8 = 0xE1
    func testTimeSyncRequestFrame() {
        let payload: [UInt8] = [0x55, 0xAA, 0x00, 0xE1, 0x00, 0x01, 0x00]
        XCTAssertEqual(CRC8Calculator.calculate(payload), 0xE1)
    }

    /// 验证：设置闹钟1为12:00 帧 55 AA 00 06 00 0B 66 00 00 07 01 0C 00 7F 00 00 00 → CRC8 = 0x09
    func testSetAlarm1Frame() {
        let payload: [UInt8] = [0x55, 0xAA, 0x00, 0x06, 0x00, 0x0B,
                                0x66, 0x00, 0x00, 0x07, 0x01, 0x0C, 0x00, 0x7F, 0x00, 0x00, 0x00]
        XCTAssertEqual(CRC8Calculator.calculate(payload), 0x09)
    }

    /// 验证：设置闹钟2为15:30 帧 55 AA 00 06 00 0B 67 00 00 07 01 0F 1E 7F 00 00 00 → CRC8 = 0x2B
    func testSetAlarm2Frame() {
        let payload: [UInt8] = [0x55, 0xAA, 0x00, 0x06, 0x00, 0x0B,
                                0x67, 0x00, 0x00, 0x07, 0x01, 0x0F, 0x1E, 0x7F, 0x00, 0x00, 0x00]
        XCTAssertEqual(CRC8Calculator.calculate(payload), 0x2B)
    }

    /// 验证：删除闹钟7 帧 55 AA 00 06 00 0B 6C 00 00 07 FF FF FF FF FF FF FF → CRC8 = 0x7C
    func testDeleteAlarm7Frame() {
        let payload: [UInt8] = [0x55, 0xAA, 0x00, 0x06, 0x00, 0x0B,
                                0x6C, 0x00, 0x00, 0x07, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
        XCTAssertEqual(CRC8Calculator.calculate(payload), 0x7C)
    }

    // MARK: - Data 类型重载验证

    func testCalculateWithData() {
        let payload: [UInt8] = [0x55, 0xAA, 0x00, 0x01, 0x00, 0x00]
        let data = Data(payload)
        XCTAssertEqual(CRC8Calculator.calculate(data), 0x00)
    }

    // MARK: - 帧验证方法

    /// 验证完整帧（含 CRC8 末字节）校验通过
    func testVerifyValidFrame() {
        // 查询设备信息完整帧：55 AA 00 01 00 00 00
        let frame: [UInt8] = [0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0x00]
        XCTAssertTrue(CRC8Calculator.verify(frame))
    }

    /// 验证 CRC8 错误的帧校验失败
    func testVerifyInvalidFrame() {
        // 故意将 CRC8 改为错误值
        let frame: [UInt8] = [0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0xFF]
        XCTAssertFalse(CRC8Calculator.verify(frame))
    }

    /// 验证帧长度不足时校验失败
    func testVerifyTooShortFrame() {
        let frame: [UInt8] = [0x55, 0xAA, 0x00]
        XCTAssertFalse(CRC8Calculator.verify(frame))
    }

    // MARK: - 边界条件

    /// 空数组 CRC8 = 0
    func testEmptyArray() {
        XCTAssertEqual(CRC8Calculator.calculate([]), 0x00)
    }

    /// 单字节 CRC8 = 该字节本身（若 < 256）
    func testSingleByte() {
        XCTAssertEqual(CRC8Calculator.calculate([0x55]), 0x55)
        XCTAssertEqual(CRC8Calculator.calculate([0xFF]), 0xFF)
    }

    /// 累加和超过 256 时正确取余
    func testOverflow() {
        // 0xFF + 0xFF = 510 → 510 % 256 = 254 = 0xFE
        XCTAssertEqual(CRC8Calculator.calculate([0xFF, 0xFF]), 0xFE)
    }
}
