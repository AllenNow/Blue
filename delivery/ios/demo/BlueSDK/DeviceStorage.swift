// DeviceStorage.swift
// BlueSDK Example - Bound device list local persistence
// Uses UserDefaults + Codable to store the bound device list

import Foundation

/// Bound device data model
struct BoundDevice: Codable {
    let deviceId: String           // UUID string (unique identifier)
    let deviceName: String         // Device broadcast name
    let bindTime: TimeInterval     // Bind timestamp
    var lastConnectedTime: TimeInterval // Last connected timestamp
}

/// Bound device local storage manager
final class DeviceStorage {

    static let shared = DeviceStorage()

    private let key = "bound_devices_v1"
    private let defaults = UserDefaults.standard

    private init() {}

    /// Load all bound devices (sorted by last connected time descending)
    func loadAll() -> [BoundDevice] {
        guard let data = defaults.data(forKey: key),
              let devices = try? JSONDecoder().decode([BoundDevice].self, from: data) else {
            return []
        }
        return devices.sorted { $0.lastConnectedTime > $1.lastConnectedTime }
    }

    /// Add a bound device (updates name if already exists)
    func add(_ device: BoundDevice) {
        var all = loadAll()
        if let idx = all.firstIndex(where: { $0.deviceId == device.deviceId }) {
            all[idx] = device
        } else {
            all.append(device)
        }
        persist(all)
    }

    /// Remove a bound device
    func remove(deviceId: String) {
        var all = loadAll()
        all.removeAll { $0.deviceId == deviceId }
        persist(all)
    }

    /// Update last connected time
    func updateLastConnected(deviceId: String) {
        var all = loadAll()
        if let idx = all.firstIndex(where: { $0.deviceId == deviceId }) {
            all[idx].lastConnectedTime = Date().timeIntervalSince1970
            persist(all)
        }
    }

    /// Check if device is bound
    func isBound(deviceId: String) -> Bool {
        return loadAll().contains { $0.deviceId == deviceId }
    }

    /// Clear all bindings
    func clearAll() {
        persist([])
    }

    // MARK: - Private

    private func persist(_ devices: [BoundDevice]) {
        if let data = try? JSONEncoder().encode(devices) {
            defaults.set(data, forKey: key)
        }
    }
}
