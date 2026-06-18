// BlueSDKDelegate.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
// BlueSDK - LX-PD02 Smart Pill Box BLE SDK
//
// SDK 公开事件回调协议
// SDK public event callback protocol
//
// 所有回调在主线程派发（ARCH-06）
// All callbacks are dispatched on the main thread (ARCH-06)

import Foundation

/// BlueSDK 事件回调协议
/// BlueSDK event callback protocol
///
/// 所有回调在主线程派发
/// All callbacks are dispatched on the main thread
///
/// 所有方法均为可选实现（通过协议扩展提供默认空实现）
/// All methods are optional (default empty implementations via protocol extension)
public protocol BlueSDKDelegate: AnyObject {

    // MARK: - 连接状态 / Connection State（Epic 2）

    /// 连接状态变化（FR04）
    /// Connection state changed (FR04)
    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState)

    // MARK: - 认证 / Authentication（Epic 3）

    /// 认证结果（FR09）
    /// Authentication result (FR09)
    func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?)

    // MARK: - 设备信息 / Device Info（Epic 4）

    /// 设备信息查询结果（FR12）
    /// Device info query result (FR12)
    func blueSDK(_ sdk: BlueSDK, didReceiveDeviceInfo info: DeviceInfo)

    /// 设备请求时间同步（FR13）
    /// Device requests time sync (FR13)
    func blueSDKDidRequestTimeSync(_ sdk: BlueSDK)

    // MARK: - 闹钟 / Alarms（Epic 5）

    /// 设备端闹钟变更上报（FR18）
    /// Device reports alarm configuration change (FR18)
    func blueSDK(_ sdk: BlueSDK, didUpdateAlarm alarm: AlarmInfo)

    // MARK: - 用药事件 / Medication Events（Epic 6）

    /// 闹钟开始响铃（FR20）
    /// Alarm starts ringing (FR20)
    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo)

    /// 闹钟超时未取药（FR21）
    /// Alarm timed out without medication taken (FR21)
    func blueSDK(_ sdk: BlueSDK, didAlarmTimeout alarmIndex: Int, alarmInfo: AlarmInfo)

    /// 用药结果实时事件（FR22）
    /// Real-time medication result event (FR22)
    /// 注意：此事件不携带完整时间，完整记录请监听 didReceiveMedicationRecord
    /// Note: Lacks full time info; for complete records use didReceiveMedicationRecord
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus)

    /// 用药记录上报（FR23）— 包含完整的设定时间和实际取药时间
    /// Medication record reported (FR23) — includes scheduled time and actual time
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationRecord record: MedicationRecord)

    // MARK: - 音频设置 / Audio Settings（Epic 7）

    /// 铃声类型变更上报（FR27）
    /// Sound type change reported (FR27)
    func blueSDK(_ sdk: BlueSDK, didChangeSoundType type: SoundType)

    /// 时间格式变更上报（FR31）
    /// Time format change reported (FR31)
    func blueSDK(_ sdk: BlueSDK, didChangeTimeFormat format: TimeFormat)

    // MARK: - 设备状态 / Device Status

    /// 设备低电上报
    /// Device reports low battery
    func blueSDKDidReportLowBattery(_ sdk: BlueSDK)

    /// 用药结果通知（设备闹钟响铃/超时/取药）
    /// Medication notification (alarm ringing / timeout / taken)
    /// - Parameter type: 1=开始响铃等待取药, 2=超时未取药, 3=用户已取药
    /// - Parameter type: 1=ringing waiting, 2=timeout missed, 3=taken
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationNotification type: Int)

    /// 设备端执行解绑操作上报
    /// Device reports unbind operation
    func blueSDKDidReportDeviceUnbound(_ sdk: BlueSDK)

    /// 连接错误（超时、断开等）
    /// Connection error (timeout, disconnect, etc.)
    func blueSDK(_ sdk: BlueSDK, didEncounterError error: BlueError)

    /// 正在自动重连
    /// Auto-reconnecting in progress
    func blueSDK(_ sdk: BlueSDK, didStartReconnecting attempt: Int, maxAttempts: Int)

    /// 自动重连失败，已达最大尝试次数
    /// Auto-reconnection failed, max attempts reached
    func blueSDKDidFailReconnection(_ sdk: BlueSDK)
}

// MARK: - 默认空实现（所有方法可选）
// MARK: - Default empty implementations (all methods optional)

public extension BlueSDKDelegate {
    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState) {}
    func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?) {}
    func blueSDK(_ sdk: BlueSDK, didReceiveDeviceInfo info: DeviceInfo) {}
    func blueSDKDidRequestTimeSync(_ sdk: BlueSDK) {}
    func blueSDK(_ sdk: BlueSDK, didUpdateAlarm alarm: AlarmInfo) {}
    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo) {}
    func blueSDK(_ sdk: BlueSDK, didAlarmTimeout alarmIndex: Int, alarmInfo: AlarmInfo) {}
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus) {}
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationRecord record: MedicationRecord) {}
    func blueSDK(_ sdk: BlueSDK, didChangeSoundType type: SoundType) {}
    func blueSDK(_ sdk: BlueSDK, didChangeTimeFormat format: TimeFormat) {}
    func blueSDKDidReportLowBattery(_ sdk: BlueSDK) {}
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationNotification type: Int) {}
    func blueSDKDidReportDeviceUnbound(_ sdk: BlueSDK) {}
    func blueSDK(_ sdk: BlueSDK, didEncounterError error: BlueError) {}
    func blueSDK(_ sdk: BlueSDK, didStartReconnecting attempt: Int, maxAttempts: Int) {}
    func blueSDKDidFailReconnection(_ sdk: BlueSDK) {}
}
