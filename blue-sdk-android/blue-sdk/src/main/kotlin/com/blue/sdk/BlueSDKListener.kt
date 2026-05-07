// BlueSDKListener.kt
// BlueSDK - SDK 公开事件回调接口
// 所有回调在主线程派发（ARCH-06）

package com.blue.sdk

import com.blue.sdk.enums.ConnectionState
import com.blue.sdk.enums.MedicationStatus
import com.blue.sdk.enums.SoundType
import com.blue.sdk.enums.TimeFormat
import com.blue.sdk.error.BlueError
import com.blue.sdk.model.AlarmInfo
import com.blue.sdk.model.DeviceInfo
import com.blue.sdk.model.MedicationRecord

/**
 * BlueSDK 事件回调接口
 * 所有回调在主线程派发，实现时无需切换线程
 */
interface BlueSDKListener {

    // MARK: - 连接状态（Epic 2）

    /** 连接状态变化（FR04）*/
    fun onConnectionStateChanged(state: ConnectionState) {}

    // MARK: - 认证（Epic 3）

    /** 认证结果（FR09）*/
    fun onAuthResult(success: Boolean, error: BlueError?) {}

    // MARK: - 设备信息（Epic 4）

    /** 设备信息查询结果（FR12）*/
    fun onDeviceInfoReceived(info: DeviceInfo) {}

    /** 设备请求时间同步（FR13）*/
    fun onTimeSyncRequested() {}

    // MARK: - 闹钟（Epic 5）

    /** 设备端闹钟变更上报（FR18）*/
    fun onAlarmUpdated(alarm: AlarmInfo) {}

    // MARK: - 用药事件（Epic 6）

    /** 闹钟开始响铃（FR20）*/
    fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) {}

    /** 闹钟超时未取药（FR21）*/
    fun onAlarmTimeout(alarmIndex: Int, alarmInfo: AlarmInfo) {}

    /** 用药结果事件（FR22）*/
    fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {}

    /** 用药记录上报（FR23）*/
    fun onMedicationRecordReported(record: MedicationRecord) {}

    // MARK: - 音频设置（Epic 7）

    /** 铃声类型变更上报（FR27）*/
    fun onSoundTypeChanged(type: SoundType) {}

    /** 时间格式变更上报（FR31）*/
    fun onTimeFormatChanged(format: TimeFormat) {}
}
