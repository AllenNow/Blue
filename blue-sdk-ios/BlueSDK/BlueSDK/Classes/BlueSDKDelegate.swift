// BlueSDKDelegate.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// SDK 公开事件回调协议
// 所有回调在主线程派发（ARCH-06）

import Foundation

/// BlueSDK 事件回调协议
/// 所有回调在主线程派发
@objc public protocol BlueSDKDelegate: AnyObject {

    // MARK: - 连接状态（Epic 2）

    /// 连接状态变化（FR04）
    @objc optional func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState)

    // MARK: - 认证（Epic 3）

    /// 认证结果（FR09）
    @objc optional func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError)

    // MARK: - 设备信息（Epic 4）

    /// 设备信息查询结果（FR12）
    @objc optional func blueSDK(_ sdk: BlueSDK, didReceiveDeviceInfo info: DeviceInfo)

    /// 设备请求时间同步（FR13）
    @objc optional func blueSDKDidRequestTimeSync(_ sdk: BlueSDK)

    // MARK: - 闹钟（Epic 5）

    /// 设备端闹钟变更上报（FR18）
    @objc optional func blueSDK(_ sdk: BlueSDK, didUpdateAlarm alarm: AlarmInfo)

    // MARK: - 用药事件（Epic 6）

    /// 闹钟开始响铃（FR20）
    @objc optional func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo)

    /// 闹钟超时未取药（FR21）
    @objc optional func blueSDK(_ sdk: BlueSDK, didAlarmTimeout alarmIndex: Int, alarmInfo: AlarmInfo)

    /// 用药结果事件（FR22）
    @objc optional func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus)

    /// 用药记录上报（FR23）
    @objc optional func blueSDK(_ sdk: BlueSDK, didReceiveMedicationRecord record: MedicationRecord)

    // MARK: - 音频设置（Epic 7）

    /// 铃声类型变更上报（FR27）
    @objc optional func blueSDK(_ sdk: BlueSDK, didChangeSoundType type: SoundType)

    /// 时间格式变更上报（FR31）
    @objc optional func blueSDK(_ sdk: BlueSDK, didChangeTimeFormat format: TimeFormat)
}
