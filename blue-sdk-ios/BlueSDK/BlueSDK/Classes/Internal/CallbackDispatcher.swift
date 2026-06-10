// CallbackDispatcher.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 回调派发器：确保所有公开回调在主线程执行（ARCH-06）

import Foundation

/// 回调派发器
/// 所有公开回调必须通过此类派发，禁止直接调用（ARCH-06）
final class CallbackDispatcher {

    static let shared = CallbackDispatcher()
    private init() {}

    /// 在主线程派发回调
    /// - Parameter block: 要执行的回调块
    func dispatch(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    /// 在指定队列派发回调（供自定义线程调度使用）
    /// - Parameters:
    ///   - queue: 目标队列，默认主队列
    ///   - block: 要执行的回调块
    func dispatch(on queue: DispatchQueue = .main, _ block: @escaping () -> Void) {
        queue.async(execute: block)
    }
}
