// DeviceGroup.kt
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 设备分组模型：支持将多个设备归入命名分组
// 用于命令广播时按分组发送

package com.blue.sdk.model

/**
 * 设备分组
 * 一个命名的设备 ID 集合，用于批量命令下发
 */
data class DeviceGroup(
    /** 分组名称（唯一标识） */
    val name: String,
    /** 分组内设备 ID 列表 */
    private val _deviceIds: MutableSet<String> = mutableSetOf()
) {
    /** 分组内设备 ID 列表（只读视图） */
    val deviceIds: Set<String> get() = _deviceIds.toSet()

    constructor(name: String, deviceIds: List<String>) : this(name, deviceIds.toMutableSet())

    /** 添加设备到分组 */
    fun addDevice(deviceId: String) { _deviceIds.add(deviceId) }

    /** 从分组移除设备 */
    fun removeDevice(deviceId: String) { _deviceIds.remove(deviceId) }

    /** 分组是否包含指定设备 */
    fun contains(deviceId: String): Boolean = _deviceIds.contains(deviceId)

    /** 分组内设备数量 */
    val count: Int get() = _deviceIds.size
}

/**
 * 命令目标 — 指定命令发送给哪些设备
 */
sealed class DeviceTarget {
    /** 发送给所有已连接且已认证的设备 */
    object All : DeviceTarget()

    /** 发送给指定分组内已连接且已认证的设备 */
    data class Group(val name: String) : DeviceTarget()

    /** 发送给指定的一个或多个设备 */
    data class Devices(val ids: List<String>) : DeviceTarget()

    /** 发送给单个设备（便利写法） */
    data class Device(val id: String) : DeviceTarget()

    /** 获取目标设备 ID 集合 */
    internal fun resolve(groups: Map<String, DeviceGroup>, connectedDeviceIds: List<String>): List<String> {
        return when (this) {
            is All -> connectedDeviceIds
            is Group -> {
                val group = groups[name] ?: return emptyList()
                connectedDeviceIds.filter { group.contains(it) }
            }
            is Devices -> connectedDeviceIds.filter { ids.contains(it) }
            is Device -> if (connectedDeviceIds.contains(id)) listOf(id) else emptyList()
        }
    }
}

/**
 * 多设备命令执行结果
 * 记录每台设备的执行成功/失败状态
 */
data class MultiDeviceResult<T>(
    /** 成功的设备结果 */
    val successes: List<DeviceResult<T>>,
    /** 失败的设备结果 */
    val failures: List<DeviceFailure>
) {
    /** 是否全部成功 */
    val allSucceeded: Boolean get() = failures.isEmpty()

    /** 是否全部失败 */
    val allFailed: Boolean get() = successes.isEmpty()
}

data class DeviceResult<T>(val deviceId: String, val value: T)
data class DeviceFailure(val deviceId: String, val error: com.blue.sdk.error.BlueError)
