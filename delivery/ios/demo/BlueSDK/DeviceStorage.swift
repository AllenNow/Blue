// DeviceStorage.swift
// BlueSDK Example - 绑定设备列表本地持久化
// 使用 UserDefaults + Codable 存储已绑定设备列表

import Foundation

/// 绑定设备数据模型
struct BoundDevice: Codable {
    let deviceId: String           // UUID 字符串（唯一标识）
    let deviceName: String         // 设备广播名称
    let bindTime: TimeInterval     // 绑定时间戳
    var lastConnectedTime: TimeInterval // 最后连接时间戳
}

/// 绑定设备本地存储管理器
final class DeviceStorage {

    static let shared = DeviceStorage()

    private let key = "bound_devices_v1"
    private let defaults = UserDefaults.standard

    private init() {}

    /// 加载所有绑定设备（按最后连接时间倒序）
    func loadAll() -> [BoundDevice] {
        guard let data = defaults.data(forKey: key),
              let devices = try? JSONDecoder().decode([BoundDevice].self, from: data) else {
            return []
        }
        return devices.sorted { $0.lastConnectedTime > $1.lastConnectedTime }
    }

    /// 添加绑定设备（如已存在则更新名称）
    func add(_ device: BoundDevice) {
        var all = loadAll()
        if let idx = all.firstIndex(where: { $0.deviceId == device.deviceId }) {
            all[idx] = device
        } else {
            all.append(device)
        }
        persist(all)
    }

    /// 删除绑定设备
    func remove(deviceId: String) {
        var all = loadAll()
        all.removeAll { $0.deviceId == deviceId }
        persist(all)
    }

    /// 更新最后连接时间
    func updateLastConnected(deviceId: String) {
        var all = loadAll()
        if let idx = all.firstIndex(where: { $0.deviceId == deviceId }) {
            all[idx].lastConnectedTime = Date().timeIntervalSince1970
            persist(all)
        }
    }

    /// 检查设备是否已绑定
    func isBound(deviceId: String) -> Bool {
        return loadAll().contains { $0.deviceId == deviceId }
    }

    /// 清空所有绑定
    func clearAll() {
        persist([])
    }

    // MARK: - 私有

    private func persist(_ devices: [BoundDevice]) {
        if let data = try? JSONEncoder().encode(devices) {
            defaults.set(data, forKey: key)
        }
    }
}
