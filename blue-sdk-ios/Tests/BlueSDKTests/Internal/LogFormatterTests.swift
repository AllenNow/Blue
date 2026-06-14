// LogFormatterTests.swift
// BlueSDK 单元测试 - 日志脱敏

import XCTest
@testable import BlueSDK

final class LogFormatterTests: XCTestCase {

    /// 验证：密钥值不出现在日志输出中（FR36）
    func testAuthKeyIsSanitized() {
        let message = "auth key: 07 74"
        let result = LogFormatter.sanitize(message)
        XCTAssertFalse(result.contains("07 74"), "密钥值不应出现在日志中")
        XCTAssertTrue(result.contains("***"), "应替换为 ***")
    }

    /// 验证：MAC 地址被脱敏
    func testMACAddressIsSanitized() {
        let message = "mac: C7:50:B2:AA:C3:F3"
        let result = LogFormatter.sanitize(message)
        XCTAssertFalse(result.contains("C7:50:B2:AA:C3:F3"), "MAC 地址不应出现在日志中")
    }

    /// 验证：普通消息不被修改
    func testNormalMessageNotModified() {
        let message = "连接成功，设备 LX-PD02-A1B2"
        let result = LogFormatter.sanitize(message)
        XCTAssertEqual(result, message)
    }

    /// 验证：格式化输出包含级别标签
    func testFormatIncludesLevel() {
        let result = LogFormatter.format(level: .debug, tag: "Test", message: "hello")
        XCTAssertTrue(result.contains("[DEBUG]"))
        XCTAssertTrue(result.contains("[Test]"))
        XCTAssertTrue(result.contains("hello"))
    }

    /// 验证：格式化输出包含 BlueSDK 前缀
    func testFormatIncludesPrefix() {
        let result = LogFormatter.format(level: .info, tag: "BLE", message: "scanning")
        XCTAssertTrue(result.hasPrefix("[BlueSDK]"))
    }
}
