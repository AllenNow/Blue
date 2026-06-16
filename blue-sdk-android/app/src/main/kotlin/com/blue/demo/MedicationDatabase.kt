package com.blue.demo

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class MedicationDatabase private constructor(context: Context) : SQLiteOpenHelper(context, DB_NAME, null, DB_VERSION) {

    companion object {
        private const val DB_NAME = "medication.db"
        private const val DB_VERSION = 1

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
                status INTEGER NOT NULL
            )
        """.trimIndent())
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {}

    fun insert(timestamp: Long, alarmIndex: Int, status: Int) {
        writableDatabase.insert("records", null, android.content.ContentValues().apply {
            put("timestamp", timestamp)
            put("alarmIndex", alarmIndex)
            put("status", status)
        })
    }

    fun query(date: Long): List<MedicationEntry> {
        val startOfDay = date - (date % (24 * 60 * 60 * 1000))
        val endOfDay = startOfDay + (24 * 60 * 60 * 1000)
        val list = mutableListOf<MedicationEntry>()
        readableDatabase.query("records", null, "timestamp >= ? AND timestamp < ?",
            arrayOf(startOfDay.toString(), endOfDay.toString()), null, null, "timestamp DESC").use { cursor ->
            while (cursor.moveToNext()) {
                list.add(MedicationEntry(
                    timestamp = cursor.getLong(cursor.getColumnIndexOrThrow("timestamp")),
                    alarmIndex = cursor.getInt(cursor.getColumnIndexOrThrow("alarmIndex")),
                    status = cursor.getInt(cursor.getColumnIndexOrThrow("status"))
                ))
            }
        }
        return list
    }

    fun queryAll(): List<MedicationEntry> {
        val list = mutableListOf<MedicationEntry>()
        readableDatabase.query("records", null, null, null, null, null, "timestamp DESC").use { cursor ->
            while (cursor.moveToNext()) {
                list.add(MedicationEntry(
                    timestamp = cursor.getLong(cursor.getColumnIndexOrThrow("timestamp")),
                    alarmIndex = cursor.getInt(cursor.getColumnIndexOrThrow("alarmIndex")),
                    status = cursor.getInt(cursor.getColumnIndexOrThrow("status"))
                ))
            }
        }
        return list
    }

    fun deleteAll() {
        writableDatabase.delete("records", null, null)
    }
}

data class MedicationEntry(val timestamp: Long, val alarmIndex: Int, val status: Int) {
    val statusEmoji: String get() = when (status) {
        1 -> "✅"
        2 -> "⏰"
        3 -> "❌"
        4 -> "⏱"
        else -> "📋"
    }
    val statusText: String get() = when (status) {
        1 -> "已服药"
        2 -> "超时"
        3 -> "未服药"
        4 -> "提前"
        else -> "未知"
    }
}