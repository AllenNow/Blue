// DeviceStorage.kt
// BlueSDK Demo - Local persistence for bound device list
// Uses SharedPreferences + JSON to store bound devices

package com.blue.demo

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Bound device data model
 */
data class BoundDevice(
    val deviceId: String,           // MAC address (unique identifier)
    val deviceName: String,         // Device broadcast name
    val bindTime: Long,             // Bind timestamp
    val lastConnectedTime: Long = 0 // Last connection timestamp
)

/**
 * Bound device local storage manager
 * Uses SharedPreferences + JSON to persist bound device list
 */
object DeviceStorage {

    private const val PREFS_NAME = "bound_devices_prefs"
    private const val KEY_DEVICES = "bound_devices_v1"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** Load all bound devices (sorted by last connected time, descending) */
    fun loadAll(context: Context): List<BoundDevice> {
        val json = prefs(context).getString(KEY_DEVICES, null) ?: return emptyList()
        return try {
            val arr = JSONArray(json)
            (0 until arr.length()).map { i ->
                val obj = arr.getJSONObject(i)
                BoundDevice(
                    deviceId = obj.getString("deviceId"),
                    deviceName = obj.getString("deviceName"),
                    bindTime = obj.getLong("bindTime"),
                    lastConnectedTime = obj.optLong("lastConnectedTime", 0)
                )
            }.sortedByDescending { it.lastConnectedTime }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /** Add bound device (updates name if already exists) */
    fun add(context: Context, device: BoundDevice) {
        val all = loadAll(context).toMutableList()
        val existing = all.indexOfFirst { it.deviceId == device.deviceId }
        if (existing >= 0) {
            all[existing] = device
        } else {
            all.add(device)
        }
        persist(context, all)
    }

    /** Remove bound device */
    fun remove(context: Context, deviceId: String) {
        val all = loadAll(context).toMutableList()
        all.removeAll { it.deviceId == deviceId }
        persist(context, all)
    }

    /** Update last connected time */
    fun updateLastConnected(context: Context, deviceId: String) {
        val all = loadAll(context).toMutableList()
        val idx = all.indexOfFirst { it.deviceId == deviceId }
        if (idx >= 0) {
            all[idx] = all[idx].copy(lastConnectedTime = System.currentTimeMillis())
            persist(context, all)
        }
    }

    /** Check if device is already bound */
    fun isBound(context: Context, deviceId: String): Boolean {
        return loadAll(context).any { it.deviceId == deviceId }
    }

    /** Clear all bindings */
    fun clearAll(context: Context) {
        persist(context, emptyList())
    }

    // MARK: - Private

    private fun persist(context: Context, devices: List<BoundDevice>) {
        val arr = JSONArray()
        for (d in devices) {
            arr.put(JSONObject().apply {
                put("deviceId", d.deviceId)
                put("deviceName", d.deviceName)
                put("bindTime", d.bindTime)
                put("lastConnectedTime", d.lastConnectedTime)
            })
        }
        prefs(context).edit().putString(KEY_DEVICES, arr.toString()).apply()
    }
}
