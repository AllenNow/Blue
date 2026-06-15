// BlueSDKDelegate.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// SDK 公开事件回调协议
// 所有回调在主线程派发（ARCH-06）

import Foundation

/// BlueSDK 事件回调协议
/// 所有回调在主线程派发
/// 所有方法均为可选实现（通过协议扩展提供默认空实现）
public protocol BlueSDKDelegate: AnyObject {

    // MARK: - 连接状态（Epic 2）

    /// 连接状态变化（FR04）
    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState)

    // MARK: - 认证（Epic 3）

    /// 认证结果（FR09）
    func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?)

    // MARK: - 设备信息（Epic 4）

    /// 设备信息查询结果（FR12）
    func blueSDK(_ sdk: BlueSDK, didReceiveDeviceInfo info: DeviceInfo)

    /// 设备请求时间同步（FR13）
    func blueSDKDidRequestTimeSync(_ sdk: BlueSDK)

    // MARK: - 闹钟（Epic 5）

    /// 设备端闹钟变更上报（FR18）
    func blueSDK(_ sdk: BlueSDK, didUpdateAlarm alarm: AlarmInfo)

    // MARK: - 用药事件（Epic 6）

    /// 闹钟开始响铃（FR20）
    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo)

    /// 闹钟超时未取药（FR21）
    func blueSDK(_ sdk: BlueSDK, didAlarmTimeout alarmIndex: Int, alarmInfo: AlarmInfo)

    /// 用药结果事件（FR22）
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus)

    /// 用药记录上报（FR23）
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationRecord record: MedicationRecord)

    // MARK: - 音频设置（Epic 7）

    /// 铃声类型变更上报（FR27）
    func blueSDK(_ sdk: BlueSDK, didChangeSoundType type: SoundType)

    /// 时间格式变更上报（FR31）
    func blueSDK(_ sdk: BlueSDK, didChangeTimeFormat format: TimeFormat)

    // MARK: - 设备状态

    /// 设备低电上报
    func blueSDKDidReportLowBattery(_ sdk: BlueSDK)

    /// 设备端执行解绑操作上报（Story 9.3）
    func blueSDKDidReportDeviceUnbound(_ sdk: BlueSDK)

    /// 连接错误（超时、断开等）
    func blueSDK(_ sdk: BlueSDK, didEncounterError error: BlueError)

    /// 正在自动重连
    func blueSDK(_ sdk: BlueSDK, didStartReconnecting attempt: Int, maxAttempts: Int)

    /// 自动重连失败，已达最大尝试次数
    func blueSDKDidFailReconnection(_ sdk: BlueSDK)
}

// MARK: - 默认空实现（所有方法可选）

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
    func blueSDKDidReportDeviceUnbound(_ sdk: BlueSDK) {}
    func blueSDK(_ sdk: BlueSDK, didEncounterError error: BlueError) {}
    func blueSDK(_ sdk: BlueSDK, didStartReconnecting attempt: Int, maxAttempts: Int) {}
    func blueSDKDidFailReconnection(_ sdk: BlueSDK) {}
}
