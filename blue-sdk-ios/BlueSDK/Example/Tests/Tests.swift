// Tests.swift
// BlueSDK Example Tests
//
// 集成测试占位文件
// 各 Story 的具体测试将在对应 Story 实现时添加

import XCTest
import BlueSDK

class BlueSDKExampleTests: XCTestCase {

    func testSDKSharedInstanceNotNil() {
        XCTAssertNotNil(BlueSDKManager.shared)
    }
}
