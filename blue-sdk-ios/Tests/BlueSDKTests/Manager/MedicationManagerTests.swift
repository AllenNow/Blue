// MedicationManagerTests.swift
// BlueSDK 单元测试 - 用药事件管理器

import XCTest
@testable import BlueSDK

final class MedicationManagerTests: XCTestCase {

    // MARK: - parseMedicationEvent

    /// 验证：解析用药事件（闹钟3响铃上报）
    /// 帧：55 AA 00 07 00 0B 68 00 00 07 01 00 12 7F 01 00 01 14
    /// 数据段：68 00 00 07 01 00 12 7F 01 00 01
    func testParseMedicationEvent_ringing() {
        let data: [UInt8] = [0x68, 0x00, 0x00, 0x07, 0x01, 0x00, 0x12, 0x7F, 0x01, 0x00, 0x01]
        let result = MedicationManager.parseMedicationEvent(from: data)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.alarmIndex, 3) // 0x68 = alarm3
        XCTAssertEqual(result?.status, .taken)
    }

    /// 验证：解析超时未取药事件（byte10=0x02）
    func testParseMedicationEvent_timeout() {
        let data: [UInt8] = [0x68, 0x00, 0x00, 0x07, 0x01, 0x00, 0x12, 0x7F, 0x01, 0x01, 0x02]
        let result = MedicationManager.parseMedicationEvent(from: data)
        XCTAssertEqual(result?.status, .timeout)
    }

    /// 验证：解析漏服事件（byte10=0x03）
    func testParseMedicationEvent_missed() {
        let data: [UInt8] = [0x68, 0x00, 0x00, 0x07, 0x01, 0x00, 0x12, 0x7F, 0x01, 0x01, 0x03]
        let result = MedicationManager.parseMedicationEvent(from: data)
        XCTAssertEqual(result?.status, .missed)
    }

    /// 验证：解析提前取药事件（byte10=0x04）
    func testParseMedicationEvent_early() {
        let data: [UInt8] = [0x68, 0x00, 0x00, 0x07, 0x01, 0x00, 0x12, 0x7F, 0x01, 0x01, 0x04]
        let result = MedicationManager.parseMedicationEvent(from: data)
        XCTAssertEqual(result?.status, .early)
    }

    /// 验证：数据不足时返回 nil
    func testParseMedicationEvent_insufficientData() {
        XCTAssertNil(MedicationManager.parseMedicationEvent(from: [0x68, 0x00]))
    }

    // MARK: - parseMedicationRecord

    /// 验证：解析用药记录上报
    /// 协议帧数据段：65 00 00 0B 68 07 E9 0B 01 00 12 01 00 0A
    /// data[4]=0x68(alarm3), data[5-6]=0x07E9(2025年), data[7]=0x0B(11月), data[8]=0x01(1日)
    /// data[9]=0x00(0时), data[10]=0x12(18分), data[11]=0x01(taken)
    func testParseMedicationRecord() {
        let data: [UInt8] = [0x65, 0x00, 0x00, 0x0B, 0x68, 0x07, 0xE9, 0x0B, 0x01, 0x00, 0x12, 0x01, 0x00]
        let record = MedicationManager.parseMedicationRecord(from: data)
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.alarmIndex, 3)
        XCTAssertEqual(record?.status, .taken)
        XCTAssertGreaterThan(record?.timestamp ?? 0, 0) // 时间戳为毫秒，应大于0
    }

    /// 验证：数据不足时返回 nil
    func testParseMedicationRecord_insufficientData() {
        XCTAssertNil(MedicationManager.parseMedicationRecord(from: [0x65, 0x00]))
    }

    // MARK: - MedicationStatus

    func testMedicationStatusFromByte() {
        XCTAssertEqual(MedicationStatus.from(byte: 0x01), .taken)
        XCTAssertEqual(MedicationStatus.from(byte: 0x02), .timeout)
        XCTAssertEqual(MedicationStatus.from(byte: 0x03), .missed)
        XCTAssertEqual(MedicationStatus.from(byte: 0x04), .early)
        XCTAssertNil(MedicationStatus.from(byte: 0x00))
        XCTAssertNil(MedicationStatus.from(byte: 0x05))
    }
}
