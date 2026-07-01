// AlarmStorage.kt
// BlueSDK Demo - Local persistence for alarm configuration
// Uses SharedPreferences to store alarm slot configs, preserved after exiting

package com.blue.demo

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Alarm local storage manager
 * Uses SharedPreferences + JSON to persist 7 alarm slot configurations
 */
object AlarmStorage {

    private const val PREFS_NAME = "alarm_slots_prefs"
    private const val KEY_SLOTS = "alarm_slots_v1"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** Save a single alarm slot */
    fun save(context: Context, slot: AlarmSlot) {
        val all = loadAll(context).toMutableList()
        if (slot.index in 1..7) {
            all[slot.index - 1] = slot
        }
        persist(context, all)
    }

    /** Save all alarm slots */
    fun saveAll(context: Context, slots: List<AlarmSlot>) {
        persist(context, slots)
    }

    /** Load all alarm slots (7 total) */
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

    /** Clear a specific slot */
    fun clear(context: Context, index: Int) {
        val all = loadAll(context).toMutableList()
        if (index in 1..7) {
            all[index - 1] = AlarmSlot(index, false, 0, 0, 0x7F, false)
        }
        persist(context, all)
    }

    /** Clear all */
    fun clearAll(context: Context) {
        persist(context, defaultSlots())
    }

    // MARK: - Private

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
