// Tests.swift
// BlueSDK Example Tests

import XCTest
import BlueSDK

class BlueSDKExampleTests: XCTestCase {

    func testSDKSharedInstanceNotNil() {
        XCTAssertNotNil(BlueSDKManager.shared)
    }
}
