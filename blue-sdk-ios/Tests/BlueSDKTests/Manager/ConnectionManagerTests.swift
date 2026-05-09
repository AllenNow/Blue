// ConnectionManagerTests.swift
// BlueSDK 单元测试 - 连接状态机

import XCTest
@testable import BlueSDK

final class ConnectionManagerTests: XCTestCase {

    var manager: ConnectionManager!
    var stateChanges: [ConnectionState] = []

    override func setUp() {
        super.setUp()
        manager = ConnectionManager()
        stateChanges = []
        manager.onStateChanged = { [weak self] state in
            self?.stateChanges.append(state)
        }
    }

    // MARK: - 初始状态

    func testInitialStateIsDisconnected() {
        XCTAssertEqual(manager.state, .disconnected)
    }

    // MARK: - 状态转换

    func testTransitionToConnecting() {
        manager.transitionTo(.connecting)
        XCTAssertEqual(manager.state, .connecting)
        XCTAssertEqual(stateChanges, [.connecting])
    }

    func testTransitionToConnected() {
        manager.transitionTo(.connecting)
        manager.transitionTo(.connected)
        XCTAssertEqual(manager.state, .connected)
        XCTAssertEqual(stateChanges, [.connecting, .connected])
    }

    func testTransitionToAuthenticated() {
        manager.transitionTo(.connecting)
        manager.transitionTo(.connected)
        manager.transitionTo(.authenticated)
        XCTAssertEqual(manager.state, .authenticated)
        XCTAssertEqual(stateChanges.last, .authenticated)
    }

    func testTransitionToReconnecting() {
        manager.transitionTo(.authenticated)
        manager.transitionTo(.reconnecting)
        XCTAssertEqual(manager.state, .reconnecting)
    }

    func testTransitionToDisconnected() {
        manager.transitionTo(.authenticated)
        manager.transitionTo(.disconnected)
        XCTAssertEqual(manager.state, .disconnected)
    }

    // MARK: - 重复状态不触发回调

    func testSameStateDoesNotTriggerCallback() {
        manager.transitionTo(.disconnected) // 已经是 disconnected
        XCTAssertEqual(stateChanges.count, 0, "相同状态不应触发回调")
    }

    func testTransitionToSameStateIgnored() {
        manager.transitionTo(.connecting)
        let countBefore = stateChanges.count
        manager.transitionTo(.connecting) // 重复
        XCTAssertEqual(stateChanges.count, countBefore, "重复状态转换不应触发回调")
    }

    // MARK: - 状态回调在主线程

    func testStateChangeCallbackOnMainThread() {
        let expectation = expectation(description: "回调在主线程")
        manager.onStateChanged = { _ in
            XCTAssertTrue(Thread.isMainThread, "状态回调必须在主线程")
            expectation.fulfill()
        }
        // 在后台线程触发状态变更
        DispatchQueue.global().async {
            self.manager.transitionTo(.connecting)
        }
        waitForExpectations(timeout: 1)
    }
}
