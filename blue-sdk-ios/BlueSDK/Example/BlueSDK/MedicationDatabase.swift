// MedicationDatabase.swift
// BlueSDK Example - Medication records SQLite persistence

import Foundation
import SQLite3
import BlueSDK

/// Medication record database entry
struct MedicationEntry {
    let id: Int64
    let timestamp: Int64        // Millisecond timestamp (actual event time)
    let alarmIndex: Int
    let alarmHour: Int          // Alarm scheduled hour
    let alarmMinute: Int        // Alarm scheduled minute
    let status: Int             // 1=taken 2=late 3=missed 4=early
    let createdAt: Date

    var date: Date {
        return Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
    }

    var alarmTimeString: String {
        return String(format: "%02d:%02d", alarmHour, alarmMinute)
    }

    var statusText: String {
        let zh = SDKLocale.isZh
        switch status {
        case 1: return zh ? "按时取药" : "Taken on time"
        case 2: return zh ? "超时取药" : "Taken late"
        case 3: return zh ? "漏服" : "Missed"
        case 4: return zh ? "提前取药" : "Taken early"
        default: return zh ? "未知" : "Unknown"
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

/// Medication record database manager (SQLite)
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

    // MARK: - Database Operations

    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("medication_records.sqlite")

        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("[MedicationDB] Failed to open database")
        }
    }

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS medication_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            alarm_index INTEGER NOT NULL,
            alarm_hour INTEGER NOT NULL DEFAULT 0,
            alarm_minute INTEGER NOT NULL DEFAULT 0,
            status INTEGER NOT NULL,
            created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_timestamp ON medication_records(timestamp);
        """
        var errMsg: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let err = errMsg.map { String(cString: $0) } ?? "Unknown error"
            print("[MedicationDB] Failed to create table: \(err)")
            sqlite3_free(errMsg)
        }
        // Upgrade old table (add new columns, ignore already-exists errors)
        sqlite3_exec(db, "ALTER TABLE medication_records ADD COLUMN alarm_hour INTEGER NOT NULL DEFAULT 0", nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE medication_records ADD COLUMN alarm_minute INTEGER NOT NULL DEFAULT 0", nil, nil, nil)
    }

    /// Insert a medication record (dedup: same alarmIndex + timestamp + status won't be inserted twice)
    @discardableResult
    func insert(timestamp: Int64, alarmIndex: Int, alarmHour: Int = 0, alarmMinute: Int = 0, status: Int) -> Bool {
        // Dedup: only skip if alarmIndex + timestamp + status are exactly the same
        let checkSql = "SELECT COUNT(*) FROM medication_records WHERE alarm_index = ? AND timestamp = ? AND status = ?"
        var checkStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, checkSql, -1, &checkStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(checkStmt, 1, Int32(alarmIndex))
            sqlite3_bind_int64(checkStmt, 2, timestamp)
            sqlite3_bind_int(checkStmt, 3, Int32(status))
            if sqlite3_step(checkStmt) == SQLITE_ROW {
                let count = sqlite3_column_int(checkStmt, 0)
                sqlite3_finalize(checkStmt)
                if count > 0 { return false }
            } else {
                sqlite3_finalize(checkStmt)
            }
        }

        let sql = "INSERT INTO medication_records (timestamp, alarm_index, alarm_hour, alarm_minute, status, created_at) VALUES (?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, timestamp)
        sqlite3_bind_int(stmt, 2, Int32(alarmIndex))
        sqlite3_bind_int(stmt, 3, Int32(alarmHour))
        sqlite3_bind_int(stmt, 4, Int32(alarmMinute))
        sqlite3_bind_int(stmt, 5, Int32(status))
        sqlite3_bind_double(stmt, 6, Date().timeIntervalSince1970)

        return sqlite3_step(stmt) == SQLITE_DONE
    }

    /// Query all records for a specific date
    func query(date: Date) -> [MedicationEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let startMs = Int64(startOfDay.timeIntervalSince1970 * 1000)
        let endMs = Int64(endOfDay.timeIntervalSince1970 * 1000)

        return query(fromTimestamp: startMs, toTimestamp: endMs)
    }

    /// Query records within a time range
    func query(fromTimestamp: Int64, toTimestamp: Int64) -> [MedicationEntry] {
        let sql = "SELECT id, timestamp, alarm_index, alarm_hour, alarm_minute, status, created_at FROM medication_records WHERE timestamp >= ? AND timestamp < ? ORDER BY timestamp DESC"
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
                alarmHour: Int(sqlite3_column_int(stmt, 3)),
                alarmMinute: Int(sqlite3_column_int(stmt, 4)),
                status: Int(sqlite3_column_int(stmt, 5)),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))
            )
            results.append(entry)
        }
        return results
    }

    /// Query all records
    func queryAll() -> [MedicationEntry] {
        let sql = "SELECT id, timestamp, alarm_index, alarm_hour, alarm_minute, status, created_at FROM medication_records ORDER BY timestamp DESC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var results: [MedicationEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let entry = MedicationEntry(
                id: sqlite3_column_int64(stmt, 0),
                timestamp: sqlite3_column_int64(stmt, 1),
                alarmIndex: Int(sqlite3_column_int(stmt, 2)),
                alarmHour: Int(sqlite3_column_int(stmt, 3)),
                alarmMinute: Int(sqlite3_column_int(stmt, 4)),
                status: Int(sqlite3_column_int(stmt, 5)),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))
            )
            results.append(entry)
        }
        return results
    }

    /// Query total record count
    func count() -> Int {
        let sql = "SELECT COUNT(*) FROM medication_records"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
    }

    /// Delete all records
    func deleteAll() {
        sqlite3_exec(db, "DELETE FROM medication_records", nil, nil, nil)
    }
}
