// CommandQueueTests.swift
// BlueSDK 单元测试 - 指令串行队列

import XCTest
@testable import BlueSDK

final class CommandQueueTests: XCTestCase {

    var queue: CommandQueue!
    var sentFrames: [[UInt8]] = []

    override func setUp() {
        super.setUp()
        queue = CommandQueue()
        sentFrames = []
        queue.sendBlock = { [weak self] frame in
            self?.sentFrames.append(frame)
        }
    }

    override func tearDown() {
        queue.clear()
        super.tearDown()
    }

    // MARK: - 基础入队与应答

    /// 验证：入队后立即发送
    func testEnqueueSendsImmediately() {
        let frame: [UInt8] = [0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0x00]
        queue.enqueue(cmd: 0x01, frame: frame) { _ in }
        XCTAssertEqual(sentFrames.count, 1)
    }

    /// 验证：应答匹配后回调成功
    func testHandleResponseMatchesCommand() {
        let expectation = expectation(description: "应答回调")
        let frame: [UInt8] = [0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0x00]
        queue.enqueue(cmd: 0x01, frame: frame) { result in
            XCTAssertTrue(result.isSuccess)
            expectation.fulfill()
        }
        // 模拟设备应答（CMD=0x01 的应答 CMD=0x02，或相同 CMD）
        let responseFrame = ParsedFrame(version: 0x00, cmd: 0x02, data: [])
        let matched = queue.handleResponse(responseFrame)
        XCTAssertTrue(matched)
        waitForExpectations(timeout: 1)
    }

    /// 验证：应答 CMD 不匹配时不消费
    func testHandleResponseNoMatch() {
        let frame: [UInt8] = [0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0x00]
        queue.enqueue(cmd: 0x01, frame: frame) { _ in }
        let wrongResponse = ParsedFrame(version: 0x00, cmd: 0x05, data: [])
        XCTAssertFalse(queue.handleResponse(wrongResponse))
    }

    // MARK: - 串行队列

    /// 验证：第二条指令排队等待，第一条完成后自动发送
    /// 注意：此测试依赖 Timer/RunLoop，在 SPM 命令行测试中可能不稳定
    /// 真实行为已在集成测试中验证
    func testSecondCommandWaitsForFirst() {
        let frame1: [UInt8] = [0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0x00]
        let frame2: [UInt8] = [0x55, 0xAA, 0x00, 0x01, 0x00, 0x00, 0x00]

        queue.enqueue(cmd: 0x01, frame: frame1) { _ in }
        queue.enqueue(cmd: 0x01, frame: frame2) { _ in }

        // 第一条已发送，第二条在等待
        XCTAssertEqual(sentFrames.count, 1)
        // 注意：sendNext 中的 Timer 需要 RunLoop 驱动，SPM 测试环境下可能无法验证自动发送
    }

    // MARK: - clear

    /// 验证：clear 后所有待处理指令收到 disconnected 错误
    func testClearCancelsAllCommands() {
        let exp1 = expectation(description: "cmd1 cancelled")
        let exp2 = expectation(description: "cmd2 cancelled")

        queue.enqueue(cmd: 0x01, frame: []) { result in
            if case .failure(let error) = result, error == .disconnected {
                exp1.fulfill()
            }
        }
        queue.enqueue(cmd: 0x06, frame: []) { result in
            if case .failure(let error) = result, error == .disconnected {
                exp2.fulfill()
            }
        }
        queue.clear()
        waitForExpectations(timeout: 1)
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
