package com.blue.demo

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class MedicationDatabase private constructor(context: Context) : SQLiteOpenHelper(context, DB_NAME, null, DB_VERSION) {

    companion object {
        private const val DB_NAME = "medication.db"
        private const val DB_VERSION = 2  // v2: added alarmHour, alarmMinute columns

        @Volatile
        private var instance: MedicationDatabase? = null

        fun getInstance(context: Context): MedicationDatabase {
            return instance ?: synchronized(this) {
                instance ?: MedicationDatabase(context.applicationContext).also { instance = it }
            }
        }
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("""
            CREATE TABLE records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp INTEGER NOT NULL,
                alarmIndex INTEGER NOT NULL,
                alarmHour INTEGER NOT NULL DEFAULT 0,
                alarmMinute INTEGER NOT NULL DEFAULT 0,
                status INTEGER NOT NULL
            )
        """.trimIndent())
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL("ALTER TABLE records ADD COLUMN alarmHour INTEGER NOT NULL DEFAULT 0")
            db.execSQL("ALTER TABLE records ADD COLUMN alarmMinute INTEGER NOT NULL DEFAULT 0")
        }
    }

    fun insert(timestamp: Long, alarmIndex: Int, alarmHour: Int, alarmMinute: Int, status: Int) {
        // Deduplication: same alarmIndex + timestamp + status not stored again
        // timestamp is millisecond-precise, only hits on duplicate parsing of same frame
        val cursor = readableDatabase.query("records", arrayOf("id"),
            "alarmIndex = ? AND timestamp = ? AND status = ?",
            arrayOf(alarmIndex.toString(), timestamp.toString(), status.toString()),
            null, null, null)
        val exists = cursor.count > 0
        cursor.close()
        if (exists) return

        writableDatabase.insert("records", null, ContentValues().apply {
            put("timestamp", timestamp)
            put("alarmIndex", alarmIndex)
            put("alarmHour", alarmHour)
            put("alarmMinute", alarmMinute)
            put("status", status)
        })
    }

    fun query(date: Long): List<MedicationEntry> {
        val startOfDay = date - (date % (24 * 60 * 60 * 1000))
        val endOfDay = startOfDay + (24 * 60 * 60 * 1000)
        return queryWhere("timestamp >= ? AND timestamp < ?", arrayOf(startOfDay.toString(), endOfDay.toString()))
    }

    fun queryAll(): List<MedicationEntry> = queryWhere(null, null)

    fun deleteAll() { writableDatabase.delete("records", null, null) }

    private fun queryWhere(where: String?, args: Array<String>?): List<MedicationEntry> {
        val list = mutableListOf<MedicationEntry>()
        readableDatabase.query("records", null, where, args, null, null, "timestamp DESC").use { c ->
            while (c.moveToNext()) {
                list.add(MedicationEntry(
                    timestamp = c.getLong(c.getColumnIndexOrThrow("timestamp")),
                    alarmIndex = c.getInt(c.getColumnIndexOrThrow("alarmIndex")),
                    alarmHour = c.getInt(c.getColumnIndexOrThrow("alarmHour")),
                    alarmMinute = c.getInt(c.getColumnIndexOrThrow("alarmMinute")),
                    status = c.getInt(c.getColumnIndexOrThrow("status"))
                ))
            }
        }
        return list
    }
}

data class MedicationEntry(
    val timestamp: Long,
    val alarmIndex: Int,
    val alarmHour: Int,
    val alarmMinute: Int,
    val status: Int
) {
    val statusEmoji: String get() = when (status) { 1 -> "✅"; 2 -> "⏰"; 3 -> "❌"; 4 -> "⏩"; else -> "❓" }
    val statusText: String get() = when (status) {
        1 -> S.statusTaken; 2 -> S.statusLate; 3 -> S.statusMissed; 4 -> S.statusEarly; else -> S.statusUnknown
    }
    val alarmTimeString: String get() = "%02d:%02d".format(alarmHour, alarmMinute)
}
