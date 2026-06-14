// MedicationDatabase.swift
// BlueSDK Example - 用药记录 SQLite 持久化

import Foundation
import SQLite3

/// 用药记录数据库条目
struct MedicationEntry {
    let id: Int64
    let timestamp: Int64        // 毫秒时间戳
    let alarmIndex: Int
    let status: Int             // 1=取药 2=超时 3=漏服 4=提前
    let createdAt: Date

    var date: Date {
        return Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
    }

    var statusText: String {
        switch status {
        case 1: return "按时取药"
        case 2: return "超时取药"
        case 3: return "漏服"
        case 4: return "提前取药"
        default: return "未知"
        }
    }

    var statusEmoji: String {
        switch status {
        case 1: return "✅"
        case 2: return "⏰"
        case 3: return "❌"
        case 4: return "⏩"
        default: return "❓"
        }
    }
}

/// 用药记录数据库管理器（SQLite）
final class MedicationDatabase {

    static let shared = MedicationDatabase()

    private var db: OpaquePointer?

    private init() {
        openDatabase()
        createTable()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - 数据库操作

    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("medication_records.sqlite")

        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("[MedicationDB] 打开数据库失败")
        }
    }

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS medication_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            alarm_index INTEGER NOT NULL,
            status INTEGER NOT NULL,
            created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_timestamp ON medication_records(timestamp);
        """
        var errMsg: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let err = errMsg.map { String(cString: $0) } ?? "未知错误"
            print("[MedicationDB] 建表失败：\(err)")
            sqlite3_free(errMsg)
        }
    }

    /// 插入一条用药记录
    @discardableResult
    func insert(timestamp: Int64, alarmIndex: Int, status: Int) -> Bool {
        let sql = "INSERT INTO medication_records (timestamp, alarm_index, status, created_at) VALUES (?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, timestamp)
        sqlite3_bind_int(stmt, 2, Int32(alarmIndex))
        sqlite3_bind_int(stmt, 3, Int32(status))
        sqlite3_bind_double(stmt, 4, Date().timeIntervalSince1970)

        return sqlite3_step(stmt) == SQLITE_DONE
    }

    /// 查询指定日期的所有记录
    func query(date: Date) -> [MedicationEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let startMs = Int64(startOfDay.timeIntervalSince1970 * 1000)
        let endMs = Int64(endOfDay.timeIntervalSince1970 * 1000)

        return query(fromTimestamp: startMs, toTimestamp: endMs)
    }

    /// 查询时间范围内的记录
    func query(fromTimestamp: Int64, toTimestamp: Int64) -> [MedicationEntry] {
        let sql = "SELECT id, timestamp, alarm_index, status, created_at FROM medication_records WHERE timestamp >= ? AND timestamp < ? ORDER BY timestamp DESC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, fromTimestamp)
        sqlite3_bind_int64(stmt, 2, toTimestamp)

        var results: [MedicationEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let entry = MedicationEntry(
                id: sqlite3_column_int64(stmt, 0),
                timestamp: sqlite3_column_int64(stmt, 1),
                alarmIndex: Int(sqlite3_column_int(stmt, 2)),
                status: Int(sqlite3_column_int(stmt, 3)),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
            )
            results.append(entry)
        }
        return results
    }

    /// 查询所有记录
    func queryAll() -> [MedicationEntry] {
        let sql = "SELECT id, timestamp, alarm_index, status, created_at FROM medication_records ORDER BY timestamp DESC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var results: [MedicationEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let entry = MedicationEntry(
                id: sqlite3_column_int64(stmt, 0),
                timestamp: sqlite3_column_int64(stmt, 1),
                alarmIndex: Int(sqlite3_column_int(stmt, 2)),
                status: Int(sqlite3_column_int(stmt, 3)),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
            )
            results.append(entry)
        }
        return results
    }

    /// 查询记录总数
    func count() -> Int {
        let sql = "SELECT COUNT(*) FROM medication_records"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
    }

    /// 清空所有记录
    func deleteAll() {
        sqlite3_exec(db, "DELETE FROM medication_records", nil, nil, nil)
    }
}
