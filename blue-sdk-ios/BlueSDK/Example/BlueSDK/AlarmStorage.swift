// AlarmStorage.swift
// BlueSDK Example - 闹钟配置本地持久化
// 使用 UserDefaults 存储闹钟槽位配置，退出界面后保留

import Foundation

/// 闹钟本地存储管理器
final class AlarmStorage {

    static let shared = AlarmStorage()

    private let key = "alarm_slots_v1"
    private let defaults = UserDefaults.standard

    private init() {}

    /// 保存单个闹钟槽位
    func save(slot: AlarmSlot) {
        var all = loadAll()
        all[slot.index - 1] = slot
        persist(all)
    }

    /// 保存所有闹钟槽位
    func saveAll(_ slots: [AlarmSlot]) {
        persist(slots)
    }

    /// 加载所有闹钟槽位（7个）
    func loadAll() -> [AlarmSlot] {
        guard let data = defaults.data(forKey: key),
              let stored = try? JSONDecoder().decode([StoredAlarm].self, from: data),
              stored.count == 7 else {
            return defaultSlots()
        }
        return stored.map { $0.toSlot() }
    }

    /// 清除指定槽位
    func clear(index: Int) {
        var all = loadAll()
        guard index >= 1, index <= 7 else { return }
        all[index - 1] = AlarmSlot(index: index, isEnabled: false, hour: 0, minute: 0, weekMask: 0x7F, isSet: false)
        persist(all)
    }

    /// 清除所有
    func clearAll() {
        persist(defaultSlots())
    }

    // MARK: - 私有

    private func defaultSlots() -> [AlarmSlot] {
        return (1...7).map {
            AlarmSlot(index: $0, isEnabled: false, hour: 0, minute: 0, weekMask: 0x7F, isSet: false)
        }
    }

    private func persist(_ slots: [AlarmSlot]) {
        let stored = slots.map { StoredAlarm(from: $0) }
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: key)
        }
    }
}

// MARK: - Codable 中间结构

private struct StoredAlarm: Codable {
    let index: Int
    let isEnabled: Bool
    let hour: Int
    let minute: Int
    let weekMask: Int
    let isSet: Bool

    init(from slot: AlarmSlot) {
        self.index = slot.index
        self.isEnabled = slot.isEnabled
        self.hour = slot.hour
        self.minute = slot.minute
        self.weekMask = slot.weekMask
        self.isSet = slot.isSet
    }

    func toSlot() -> AlarmSlot {
        return AlarmSlot(index: index, isEnabled: isEnabled, hour: hour, minute: minute, weekMask: weekMask, isSet: isSet)
    }
}
