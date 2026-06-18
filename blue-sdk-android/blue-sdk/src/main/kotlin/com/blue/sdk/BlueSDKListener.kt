// BlueSDKListener.kt
// BlueSDK - SDK 公开事件回调接口
// BlueSDK - SDK public event callback interface
//
// 所有回调在主线程派发（ARCH-06）
// All callbacks are dispatched on the main thread (ARCH-06)

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
 * BlueSDK event callback interface
 *
 * 所有回调在主线程派发，实现时无需切换线程
 * All callbacks are dispatched on the main thread; no thread switching needed
 */
interface BlueSDKListener {

    // MARK: - 连接状态 / Connection State（Epic 2）

    /**
     * 连接状态变化（FR04）
     * Connection state changed (FR04)
     */
    fun onConnectionStateChanged(state: ConnectionState) {}

    // MARK: - 认证 / Authentication（Epic 3）

    /**
     * 认证结果（FR09）
     * Authentication result (FR09)
     * @param success 是否成功 / Whether authentication succeeded
     * @param error 失败时的错误信息 / Error info on failure, null on success
     */
    fun onAuthResult(success: Boolean, error: BlueError?) {}

    // MARK: - 设备信息 / Device Info（Epic 4）

    /**
     * 设备信息查询结果（FR12）
     * Device info query result (FR12)
     */
    fun onDeviceInfoReceived(info: DeviceInfo) {}

    /**
     * 设备请求时间同步（FR13）
     * Device requests time sync (FR13)
     */
    fun onTimeSyncRequested() {}

    // MARK: - 闹钟 / Alarms（Epic 5）

    /**
     * 设备端闹钟变更上报（FR18）
     * Device reports alarm configuration change (FR18)
     */
    fun onAlarmUpdated(alarm: AlarmInfo) {}

    // MARK: - 用药事件 / Medication Events（Epic 6）

    /**
     * 闹钟开始响铃（FR20）
     * Alarm starts ringing (FR20)
     */
    fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) {}

    /**
     * 闹钟超时未取药（FR21）
     * Alarm timed out without medication taken (FR21)
     */
    fun onAlarmTimeout(alarmIndex: Int, alarmInfo: AlarmInfo) {}

    /**
     * 用药结果实时事件（FR22）
     * Real-time medication result event (FR22)
     * 注意：此事件不携带完整时间信息，完整记录请监听 onMedicationRecordReported
     * Note: This event lacks full time info; for complete records use onMedicationRecordReported
     */
    fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {}

    /**
     * 用药记录上报（FR23）— 包含完整的设定时间和实际取药时间
     * Medication record reported (FR23) — includes scheduled time and actual time
     */
    fun onMedicationRecordReported(record: MedicationRecord) {}

    // MARK: - 音频设置 / Audio Settings（Epic 7）

    /**
     * 铃声类型变更上报（FR27）
     * Sound type change reported (FR27)
     */
    fun onSoundTypeChanged(type: SoundType) {}

    /**
     * 时间格式变更上报（FR31）
     * Time format change reported (FR31)
     */
    fun onTimeFormatChanged(format: TimeFormat) {}

    // MARK: - 设备状态 / Device Status

    /**
     * 设备低电量上报
     * Device reports low battery
     */
    fun onLowBattery() {}

    /**
     * 用药结果通知（设备闹钟响铃/超时/取药）
     * Medication notification (alarm ringing / timeout / taken)
     * @param type 通知类型：1=开始响铃等待取药, 2=超时未取药, 3=用户已取药
     * @param type Notification type: 1=ringing waiting, 2=timeout missed, 3=taken
     */
    fun onMedicationNotification(type: Int) {}

    /**
     * 设备端执行解绑操作上报
     * Device reports unbind operation
     */
    fun onDeviceUnbound() {}

    /**
     * 连接错误（超时、断开等）
     * Connection error (timeout, disconnect, etc.)
     */
    fun onError(error: BlueError) {}

    /**
     * 正在自动重连
     * Auto-reconnecting in progress
     * @param attempt 当前第几次尝试 / Current attempt number
     * @param maxAttempts 最大尝试次数 / Maximum attempts
     */
    fun onReconnecting(attempt: Int, maxAttempts: Int) {}

    /**
     * 自动重连失败，已达最大尝试次数
     * Auto-reconnection failed, max attempts reached
     */
    fun onReconnectFailed() {}
}
