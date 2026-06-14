// BlueSDKLifecycleTests.swift
// BlueSDK 单元测试 - SDK 生命周期

import XCTest
@testable import BlueSDK

final class BlueSDKLifecycleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 每个测试前重置 SDK 状态
        BlueSDK.shared.destroy()
    }

    /// 验证：单例不为 nil
    func testSharedInstanceNotNil() {
        XCTAssertNotNil(BlueSDK.shared)
    }

    /// 验证：initialize() 后 requireInitialized 返回 true
    func testInitializeSuccess() {
        BlueSDK.shared.initialize()
        var errorReceived: BlueError? = nil
        let initialized = BlueSDK.shared.requireInitialized { error in
            errorReceived = error
        }
        XCTAssertTrue(initialized)
        XCTAssertNil(errorReceived)
    }

    /// 验证：未初始化时调用业务 API 返回 notInitialized 错误（FR32）
    func testNotInitializedReturnsError() {
        var receivedError: BlueError? = nil
        let initialized = BlueSDK.shared.requireInitialized { error in
            receivedError = error
        }
        XCTAssertFalse(initialized)
        XCTAssertEqual(receivedError, .notInitialized)
    }

    /// 验证：destroy() 后再次调用 requireInitialized 返回错误（FR33）
    func testDestroyResetsState() {
        BlueSDK.shared.initialize()
        BlueSDK.shared.destroy()
        var receivedError: BlueError? = nil
        let initialized = BlueSDK.shared.requireInitialized { error in
            receivedError = error
        }
        XCTAssertFalse(initialized)
        XCTAssertEqual(receivedError, .notInitialized)
    }

    /// 验证：setLogLevel 可正常设置（FR34）
    func testSetLogLevel() {
        BlueSDK.shared.initialize()
        BlueSDK.shared.setLogLevel(.debug)
        XCTAssertEqual(BlueLogger.shared.logLevel, .debug)
        BlueSDK.shared.setLogLevel(.none)
    }

    /// 验证：setLogHandler 可注册自定义处理器（FR35）
    func testSetLogHandler() {
        BlueSDK.shared.initialize()
        var capturedMessage = ""
        BlueSDK.shared.setLogHandler { _, _, message in
            capturedMessage = message
        }
        BlueSDK.shared.setLogLevel(.info)
        BlueLogger.shared.info("测试消息")
        XCTAssertEqual(capturedMessage, "测试消息")
        // 清理
        BlueSDK.shared.setLogHandler(nil)
        BlueSDK.shared.setLogLevel(.none)
    }

    /// 验证：密钥值不出现在日志中（FR36）
    func testKeyNotInLog() {
        BlueSDK.shared.initialize()
        var capturedMessage = ""
        BlueSDK.shared.setLogHandler { _, _, message in
            capturedMessage = message
        }
        BlueSDK.shared.setLogLevel(.debug)
        BlueLogger.shared.debug("auth key: 07 74")
        XCTAssertFalse(capturedMessage.contains("07 74"), "密钥值不应出现在日志中")
        // 清理
        BlueSDK.shared.setLogHandler(nil)
        BlueSDK.shared.setLogLevel(.none)
    }
}
