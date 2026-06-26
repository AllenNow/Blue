// AlarmInfo.kt
// BlueSDK - 闹钟信息数据模型
// BlueSDK - Alarm info data model

package com.blue.sdk.model

/**
 * 闹钟信息数据模型
 * Alarm info data model
 *
 * @param index 闹钟槽位索引（1~7）/ Alarm slot index (1~7)
 * @param hour 小时（0~23）/ Hour (0~23)
 * @param minute 分钟（0~59）/ Minute (0~59)
 * @param weekMask 星期周期掩码 / Week repeat bitmask
 * @param ringingState 响铃状态 / Ringing state (0=idle, 1=ringing, 2=ended)
 * @param eventStatus 事件状态 / Event status (0=none, 1=ringing, 2=timeout/taken)
 */
data class AlarmInfo(
    val index: Int,
    val isEnabled: Boolean = true,
    val hour: Int,
    val minute: Int,
    val weekMask: Int,
    val ringingState: Int = 0,
    val eventStatus: Int = 0
) {
    /** 是否为无效/删除状态（未使能且时间超出有效范围）*/
    val isDeleted: Boolean get() = !isEnabled || hour > 23 || minute > 59

    /**
     * 闹钟运行状态
     * Alarm running state
     */
    enum class RunState {
        /** 空闲/等待下次触发 / Idle, waiting for next trigger */
        IDLE,
        /** 正在响铃中 / Currently ringing */
        RINGING,
        /** 响铃结束（超时或已取药）/ Ringing ended (timeout or taken) */
        ENDED
    }

    /** 当前运行状态 / Current running state */
    val runState: RunState get() = when {
        ringingState == 0 && eventStatus == 1 -> RunState.RINGING
        ringingState == 1 -> RunState.ENDED
        else -> RunState.IDLE
    }

    // 向后兼容旧字段名
    @Deprecated("使用 ringingState 替代", ReplaceWith("ringingState"))
    val advanceStatus: Int get() = eventStatus
}
