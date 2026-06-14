// AlarmManagerTests.swift
// BlueSDK 单元测试 - 闹钟管理器

import XCTest
@testable import BlueSDK

final class AlarmManagerTests: XCTestCase {

    // MARK: - parseAlarmInfo

    /// 验证：解析设备上报闹钟1为07:00的帧数据
    /// 帧：55 AA 00 07 00 0B 66 00 00 07 01 07 00 7F 00 00 00 05
    /// 数据段：66 00 00 07 01 07 00 7F 00 00 00
    func testParseAlarmInfo_alarm1_07_00() {
        let data: [UInt8] = [0x66, 0x00, 0x00, 0x07, 0x01, 0x07, 0x00, 0x7F, 0x00, 0x00, 0x00]
        let alarm = AlarmManager.parseAlarmInfo(from: data, index: 1)
        XCTAssertNotNil(alarm)
        XCTAssertEqual(alarm?.index, 1)
        XCTAssertEqual(alarm?.hour, 7)
        XCTAssertEqual(alarm?.minute, 0)
        XCTAssertEqual(alarm?.weekMask, 0x7F)
    }

    /// 验证：解析设备上报闹钟2为09:00的帧数据
    func testParseAlarmInfo_alarm2_09_00() {
        let data: [UInt8] = [0x67, 0x00, 0x00, 0x07, 0x01, 0x09, 0x00, 0x7F, 0x00, 0x00, 0x00]
        let alarm = AlarmManager.parseAlarmInfo(from: data, index: 2)
        XCTAssertNotNil(alarm)
        XCTAssertEqual(alarm?.hour, 9)
        XCTAssertEqual(alarm?.minute, 0)
    }

    /// 验证：数据不足时返回 nil
    func testParseAlarmInfo_insufficientData() {
        let data: [UInt8] = [0x66, 0x00, 0x00]
        XCTAssertNil(AlarmManager.parseAlarmInfo(from: data, index: 1))
    }

    // MARK: - DPIDConstants.alarmDPID

    /// 验证：闹钟槽位 1~7 对应正确的 DPID
    func testAlarmDPID_validRange() {
        XCTAssertEqual(DPIDConstants.alarmDPID(for: 1), 0x66)
        XCTAssertEqual(DPIDConstants.alarmDPID(for: 2), 0x67)
        XCTAssertEqual(DPIDConstants.alarmDPID(for: 7), 0x6C)
    }

    /// 验证：超出范围返回 nil
    func testAlarmDPID_outOfRange() {
        XCTAssertNil(DPIDConstants.alarmDPID(for: 0))
        XCTAssertNil(DPIDConstants.alarmDPID(for: 8))
    }

    // MARK: - DPIDConstants.alarmIndex

    /// 验证：DPID 反查闹钟槽位
    func testAlarmIndex_validDPID() {
        XCTAssertEqual(DPIDConstants.alarmIndex(for: 0x66), 1)
        XCTAssertEqual(DPIDConstants.alarmIndex(for: 0x6C), 7)
    }

    /// 验证：非闹钟 DPID 返回 nil
    func testAlarmIndex_invalidDPID() {
        XCTAssertNil(DPIDConstants.alarmIndex(for: 0x65)) // alarmRecord
        XCTAssertNil(DPIDConstants.alarmIndex(for: 0x6D)) // typeOfSound
    }
}
