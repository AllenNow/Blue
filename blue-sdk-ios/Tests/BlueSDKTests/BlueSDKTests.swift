// BlueSDKTests.swift
// BlueSDK 测试套件
//
// 测试文件将随各 Story 实现逐步填充

import XCTest
@testable import BlueSDK

final class BlueSDKTests: XCTestCase {

    // 占位测试，确保测试目标可编译
    // 各 Story 的具体测试将在对应 Story 实现时添加

    func testSDKSharedInstanceNotNil() {
        // Story 1.8 实现后此测试将有实际意义
        XCTAssertNotNil(BlueSDK.shared)
    }
}
