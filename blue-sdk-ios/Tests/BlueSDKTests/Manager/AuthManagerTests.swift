// AuthManagerTests.swift
// BlueSDK 单元测试 - 密钥认证管理器

import XCTest
@testable import BlueSDK

final class AuthManagerTests: XCTestCase {

    // MARK: - 密钥计算验证

    /// 验证协议文档示例：
    /// 手机 MAC: C7 50 B2 AA C3 F3
    /// 设备 MAC: A6 C0 82 00 A1 C2
    /// 期望密钥: 6D 10 34 AA 64 B5
    func testCalculateKey_protocolExample() {
        let phoneMac: [UInt8] = [0xC7, 0x50, 0xB2, 0xAA, 0xC3, 0xF3]
        let deviceMac: [UInt8] = [0xA6, 0xC0, 0x82, 0x00, 0xA1, 0xC2]
        let key = AuthManager.calculateKey(phoneMac: phoneMac, deviceMac: deviceMac)
        XCTAssertEqual(key, [0x6D, 0x10, 0x34, 0xAA, 0x64, 0xB5])
    }

    /// 验证密钥计算：逐字节累加取低字节（溢出截断）
    func testCalculateKey_overflow() {
        // 0xFF + 0xFF = 0x1FE → 取低字节 0xFE
        let phoneMac: [UInt8] = [0xFF, 0x00, 0x00, 0x00, 0x00, 0x00]
        let deviceMac: [UInt8] = [0xFF, 0x00, 0x00, 0x00, 0x00, 0x00]
        let key = AuthManager.calculateKey(phoneMac: phoneMac, deviceMac: deviceMac)
        XCTAssertEqual(key[0], 0xFE) // 溢出截断
        XCTAssertEqual(key[1], 0x00)
    }

    /// 验证密钥计算：全零 MAC
    func testCalculateKey_allZero() {
        let phoneMac: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let deviceMac: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let key = AuthManager.calculateKey(phoneMac: phoneMac, deviceMac: deviceMac)
        XCTAssertEqual(key, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    }

    /// 验证密钥帧构建：密钥包帧格式正确
    /// 期望帧：55 AA 00 00 00 06 6D 10 34 AA 64 B5 [crc8]
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
        // 验证数据长度（6字节密钥）
        XCTAssertEqual(frame[4], 0x00) // lenHigh
        XCTAssertEqual(frame[5], 0x06) // lenLow
        // 验证密钥数据
        XCTAssertEqual(Array(frame[6..<12]), [0x6D, 0x10, 0x34, 0xAA, 0x64, 0xB5])
        // 验证 CRC8
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
