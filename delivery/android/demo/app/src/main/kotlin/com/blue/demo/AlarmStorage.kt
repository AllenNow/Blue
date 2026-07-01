// AlarmStorage.kt
// BlueSDK Demo - 闹钟配置本地持久化
// 使用 SharedPreferences 存储闹钟槽位配置，退出界面后保留

package com.blue.demo

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * 闹钟本地存储管理器
 * 使用 SharedPreferences + JSON 持久化 7 个闹钟槽位配置
 */
object AlarmStorage {

    private const val PREFS_NAME = "alarm_slots_prefs"
    private const val KEY_SLOTS = "alarm_slots_v1"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** 保存单个闹钟槽位 */
    fun save(context: Context, slot: AlarmSlot) {
        val all = loadAll(context).toMutableList()
        if (slot.index in 1..7) {
            all[slot.index - 1] = slot
        }
        persist(context, all)
    }

    /** 保存所有闹钟槽位 */
    fun saveAll(context: Context, slots: List<AlarmSlot>) {
        persist(context, slots)
    }

    /** 加载所有闹钟槽位（7个） */
    fun loadAll(context: Context): List<AlarmSlot> {
        val json = prefs(context).getString(KEY_SLOTS, null) ?: return defaultSlots()
        return try {
            val arr = JSONArray(json)
            if (arr.length() != 7) return defaultSlots()
            (0 until 7).map { i ->
                val obj = arr.getJSONObject(i)
                AlarmSlot(
                    index = obj.getInt("index"),
                    isEnabled = obj.getBoolean("isEnabled"),
                    hour = obj.getInt("hour"),
                    minute = obj.getInt("minute"),
                    weekMask = obj.getInt("weekMask"),
                    isSet = obj.getBoolean("isSet")
                )
            }
        } catch (e: Exception) {
            defaultSlots()
        }
    }

    /** 清除指定槽位 */
    fun clear(context: Context, index: Int) {
        val all = loadAll(context).toMutableList()
        if (index in 1..7) {
            all[index - 1] = AlarmSlot(index, false, 0, 0, 0x7F, false)
        }
        persist(context, all)
    }

    /** 清除所有 */
    fun clearAll(context: Context) {
        persist(context, defaultSlots())
    }

    // MARK: - 私有

    private fun defaultSlots(): List<AlarmSlot> =
        (1..7).map { AlarmSlot(it, false, 0, 0, 0x7F, false) }

    private fun persist(context: Context, slots: List<AlarmSlot>) {
        val arr = JSONArray()
        for (slot in slots) {
            arr.put(JSONObject().apply {
                put("index", slot.index)
                put("isEnabled", slot.isEnabled)
                put("hour", slot.hour)
                put("minute", slot.minute)
                put("weekMask", slot.weekMask)
                put("isSet", slot.isSet)
            })
        }
        prefs(context).edit().putString(KEY_SLOTS, arr.toString()).apply()
    }
}
