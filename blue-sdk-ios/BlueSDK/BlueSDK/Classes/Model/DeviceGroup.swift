// DeviceGroup.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 设备分组模型：支持将多个设备归入命名分组
// 用于命令广播时按分组发送

import Foundation

/// 设备分组
/// 一个命名的设备 ID 集合，用于批量命令下发
public struct DeviceGroup {
    /// 分组名称（唯一标识）
    public let name: String

    /// 分组内设备 ID 列表
    public private(set) var deviceIds: Set<String>

    public init(name: String, deviceIds: [String] = []) {
        self.name = name
        self.deviceIds = Set(deviceIds)
    }

    /// 添加设备到分组
    public mutating func addDevice(_ deviceId: String) {
        deviceIds.insert(deviceId)
    }

    /// 从分组移除设备
    public mutating func removeDevice(_ deviceId: String) {
        deviceIds.remove(deviceId)
    }

    /// 分组是否包含指定设备
    public func contains(_ deviceId: String) -> Bool {
        return deviceIds.contains(deviceId)
    }

    /// 分组内设备数量
    public var count: Int {
        return deviceIds.count
    }
}

/// 命令目标 — 指定命令发送给哪些设备
public enum DeviceTarget {
    /// 发送给所有已连接且已认证的设备
    case all
    /// 发送给指定分组内已连接且已认证的设备
    case group(String)
    /// 发送给指定的一个或多个设备
    case devices([String])
    /// 发送给单个设备（便利写法）
    case device(String)

    /// 获取目标设备 ID 集合（需要外部提供分组解析和已连接设备列表）
    internal func resolve(groups: [String: DeviceGroup], connectedDeviceIds: [String]) -> [String] {
        switch self {
        case .all:
            return connectedDeviceIds
        case .group(let name):
            guard let group = groups[name] else { return [] }
            return connectedDeviceIds.filter { group.contains($0) }
        case .devices(let ids):
            return connectedDeviceIds.filter { ids.contains($0) }
        case .device(let id):
            return connectedDeviceIds.contains(id) ? [id] : []
        }
    }
}

/// 多设备命令执行结果
/// 记录每台设备的执行成功/失败状态
public struct MultiDeviceResult<T> {
    /// 成功的设备结果
    public let successes: [(deviceId: String, value: T)]
    /// 失败的设备结果
    public let failures: [(deviceId: String, error: BlueError)]

    /// 是否全部成功
    public var allSucceeded: Bool { failures.isEmpty }

    /// 是否全部失败
    public var allFailed: Bool { successes.isEmpty }
}
