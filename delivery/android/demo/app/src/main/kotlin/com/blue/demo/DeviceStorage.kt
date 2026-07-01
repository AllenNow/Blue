// DeviceStorage.kt
// BlueSDK Demo - 绑定设备列表本地持久化
// 使用 SharedPreferences + JSON 存储已绑定设备列表

package com.blue.demo

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * 绑定设备数据模型
 */
data class BoundDevice(
    val deviceId: String,           // MAC 地址（唯一标识）
    val deviceName: String,         // 设备广播名称
    val bindTime: Long,             // 绑定时间戳
    val lastConnectedTime: Long = 0 // 最后连接时间戳
)

/**
 * 绑定设备本地存储管理器
 * 使用 SharedPreferences + JSON 持久化绑定设备列表
 */
object DeviceStorage {

    private const val PREFS_NAME = "bound_devices_prefs"
    private const val KEY_DEVICES = "bound_devices_v1"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** 加载所有绑定设备（按最后连接时间倒序） */
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

    /** 添加绑定设备（如已存在则更新名称） */
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

    /** 删除绑定设备 */
    fun remove(context: Context, deviceId: String) {
        val all = loadAll(context).toMutableList()
        all.removeAll { it.deviceId == deviceId }
        persist(context, all)
    }

    /** 更新最后连接时间 */
    fun updateLastConnected(context: Context, deviceId: String) {
        val all = loadAll(context).toMutableList()
        val idx = all.indexOfFirst { it.deviceId == deviceId }
        if (idx >= 0) {
            all[idx] = all[idx].copy(lastConnectedTime = System.currentTimeMillis())
            persist(context, all)
        }
    }

    /** 检查设备是否已绑定 */
    fun isBound(context: Context, deviceId: String): Boolean {
        return loadAll(context).any { it.deviceId == deviceId }
    }

    /** 清空所有绑定 */
    fun clearAll(context: Context) {
        persist(context, emptyList())
    }

    // MARK: - 私有

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
