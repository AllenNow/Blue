// AuthManagerTests.swift
// BlueSDK 单元测试 - 密钥认证管理器

import XCTest
@testable import BlueSDK

final class AuthManagerTests: XCTestCase {

    // MARK: - 密钥计算验证

    /// 验证协议文档示例：
    /// 手机 MAC: C7 50 B2 AA C3 F3
    /// 设备 MAC: A6 C0 82 00 A1 C2
    /// 密钥算法：12字节全部累加 = 0x0774，取高低两字节 [0x07, 0x74]
    func testCalculateKey_protocolExample() {
        let phoneMac: [UInt8] = [0xC7, 0x50, 0xB2, 0xAA, 0xC3, 0xF3]
        let deviceMac: [UInt8] = [0xA6, 0xC0, 0x82, 0x00, 0xA1, 0xC2]
        let key = AuthManager.calculateKey(phoneMac: phoneMac, deviceMac: deviceMac)
        XCTAssertEqual(key, [0x07, 0x74])
    }

    /// 验证密钥计算：溢出情况（总和超过 0xFFFF 时取低16位）
    func testCalculateKey_overflow() {
        // 全 0xFF：12 * 255 = 3060 = 0x0BF4
        let phoneMac: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
        let deviceMac: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
        let key = AuthManager.calculateKey(phoneMac: phoneMac, deviceMac: deviceMac)
        XCTAssertEqual(key, [0x0B, 0xF4])
    }

    /// 验证密钥计算：全零 MAC
    func testCalculateKey_allZero() {
        let phoneMac: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let deviceMac: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let key = AuthManager.calculateKey(phoneMac: phoneMac, deviceMac: deviceMac)
        XCTAssertEqual(key, [0x00, 0x00])
    }

    /// 验证密钥帧构建：密钥包帧格式正确
    /// 期望帧：55 AA 00 00 00 02 07 74 [crc8]
    func testAuthKeyFrameFormat() {
        let phoneMac: [UInt8] = [0xC7, 0x50, 0xB2, 0xAA, 0xC3, 0xF3]
        let deviceMac: [UInt8] = [0xA6, 0xC0, 0x82, 0x00, 0xA1, 0xC2]
        let key = AuthManager.calculateKey(phoneMac: phoneMac, deviceMac: deviceMac)
        let frame = FrameBuilder.build(cmd: CommandCode.authKey, data: key)
        // 验证帧头
        XCTAssertEqual(frame[0], 0x55)
        XCTAssertEqual(frame[1], 0xAA)
        XCTAssertEqual(frame[2], 0x00)
        XCTAssertEqual(frame[3], 0x00) // AUTH_KEY CMD
        // 验证数据长度（2字节密钥）
        XCTAssertEqual(frame[4], 0x00) // lenHigh
        XCTAssertEqual(frame[5], 0x02) // lenLow
        // 验证密钥数据
        XCTAssertEqual(Array(frame[6..<8]), [0x07, 0x74])
        // 验证 CRC8（协议文档示例 CRC = 0x7C）
        XCTAssertEqual(frame[8], 0x7C)
        XCTAssertTrue(CRC8Calculator.verify(frame))
    }

    /// 验证参数校验：MAC 地址长度不足时应返回 invalidParameter
    func testAuthenticateInvalidMacLength() {
        let queue = CommandQueue()
        let manager = AuthManager(commandQueue: queue)
        let shortMac: [UInt8] = [0x01, 0x02, 0x03] // 只有3字节，应为6字节

        let expectation = expectation(description: "应返回 invalidParameter 错误")
        manager.authenticate(phoneMac: shortMac, deviceMac: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06]) { result in
            if case .failure(let error) = result, error == .invalidParameter {
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1)
    }
}
