// AlarmStorage.swift
// BlueSDK Example - Alarm configuration local persistence
// Uses UserDefaults to store alarm slot configurations, persists after exiting the UI

import Foundation

/// Alarm local storage manager
final class AlarmStorage {

    static let shared = AlarmStorage()

    private let key = "alarm_slots_v1"
    private let defaults = UserDefaults.standard

    private init() {}

    /// Save a single alarm slot
    func save(slot: AlarmSlot) {
        var all = loadAll()
        all[slot.index - 1] = slot
        persist(all)
    }

    /// Save all alarm slots
    func saveAll(_ slots: [AlarmSlot]) {
        persist(slots)
    }

    /// Load all alarm slots (7 total)
    func loadAll() -> [AlarmSlot] {
        guard let data = defaults.data(forKey: key),
              let stored = try? JSONDecoder().decode([StoredAlarm].self, from: data),
              stored.count == 7 else {
            return defaultSlots()
        }
        return stored.map { $0.toSlot() }
    }

    /// Clear a specific slot
    func clear(index: Int) {
        var all = loadAll()
        guard index >= 1, index <= 7 else { return }
        all[index - 1] = AlarmSlot(index: index, isEnabled: false, hour: 0, minute: 0, weekMask: 0x7F, isSet: false)
        persist(all)
    }

    /// Clear all
    func clearAll() {
        persist(defaultSlots())
    }

    // MARK: - Private

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

// MARK: - Codable intermediate structure

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
