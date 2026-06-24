// BlueSDKDelegate.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
// BlueSDK - LX-PD02 Smart Pill Box BLE SDK
// BlueSDK - LX-PD02 Intelligente Pillendose BLE SDK
//
// SDK 公开事件回调协议
// SDK public event callback protocol
// SDK öffentliches Event-Callback-Protokoll
//
// 所有回调在主线程派发（ARCH-06）
// All callbacks are dispatched on the main thread (ARCH-06)
// Alle Callbacks werden auf dem Main-Thread ausgeführt (ARCH-06)

import Foundation

/// BlueSDK 事件回调协议
/// BlueSDK event callback protocol
/// BlueSDK Event-Callback-Protokoll
///
/// 所有回调在主线程派发
/// All callbacks are dispatched on the main thread
/// Alle Callbacks werden auf dem Main-Thread ausgeführt
///
/// 所有方法均为可选实现（通过协议扩展提供默认空实现）
/// All methods are optional (default empty implementations via protocol extension)
/// Alle Methoden sind optional (Standard-Leerimplementierungen über Protokollerweiterung)
public protocol BlueSDKDelegate: AnyObject {

    // MARK: - 连接状态 / Connection State / Verbindungsstatus（Epic 2）

    /// 连接状态变化（FR04）
    /// Connection state changed (FR04)
    /// Verbindungsstatus geändert (FR04)
    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState)

    // MARK: - 认证 / Authentication / Authentifizierung（Epic 3）

    /// 认证结果（FR09）
    /// Authentication result (FR09)
    /// Authentifizierungsergebnis (FR09)
    func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?)

    // MARK: - 设备信息 / Device Info / Geräteinformationen（Epic 4）

    /// 设备信息查询结果（FR12）
    /// Device info query result (FR12)
    /// Geräteinformationen-Abfrageergebnis (FR12)
    func blueSDK(_ sdk: BlueSDK, didReceiveDeviceInfo info: DeviceInfo)

    /// 设备请求时间同步（FR13）
    /// Device requests time sync (FR13)
    /// Gerät fordert Zeitsynchronisation an (FR13)
    func blueSDKDidRequestTimeSync(_ sdk: BlueSDK)

    // MARK: - 闹钟 / Alarms / Alarme（Epic 5）

    /// 设备端闹钟变更上报（FR18）
    /// Device reports alarm configuration change (FR18)
    /// Gerät meldet Alarmkonfigurationsänderung (FR18)
    func blueSDK(_ sdk: BlueSDK, didUpdateAlarm alarm: AlarmInfo)

    // MARK: - 用药事件 / Medication Events / Medikamenten-Ereignisse（Epic 6）

    /// 闹钟开始响铃（FR20）
    /// Alarm starts ringing (FR20)
    /// Alarm beginnt zu klingeln (FR20)
    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo)

    /// 闹钟超时未取药（FR21）
    /// Alarm timed out without medication taken (FR21)
    /// Alarm abgelaufen ohne Medikamenteneinnahme (FR21)
    func blueSDK(_ sdk: BlueSDK, didAlarmTimeout alarmIndex: Int, alarmInfo: AlarmInfo)

    /// 用药结果实时事件（FR22）
    /// Real-time medication result event (FR22)
    /// Echtzeit-Medikamentenergebnis-Ereignis (FR22)
    /// 注意：此事件不携带完整时间，完整记录请监听 didReceiveMedicationRecord
    /// Note: Lacks full time info; for complete records use didReceiveMedicationRecord
    /// Hinweis: Ohne vollständige Zeitinfo; für vollständige Aufzeichnungen didReceiveMedicationRecord verwenden
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus)

    /// 用药记录上报（FR23）— 包含完整的设定时间和实际取药时间
    /// Medication record reported (FR23) — includes scheduled time and actual time
    /// Medikamentenaufzeichnung gemeldet (FR23) — enthält geplante und tatsächliche Einnahmezeit
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationRecord record: MedicationRecord)

    // MARK: - 音频设置 / Audio Settings / Audioeinstellungen（Epic 7）

    /// 铃声类型变更上报（FR27）
    /// Sound type change reported (FR27)
    /// Klingeltontyp-Änderung gemeldet (FR27)
    func blueSDK(_ sdk: BlueSDK, didChangeSoundType type: SoundType)

    /// 提醒持续时间变更上报
    /// Alert duration change reported (minutes)
    /// Alarmdauer-Änderung gemeldet (Minuten)
    func blueSDK(_ sdk: BlueSDK, didChangeAlertDuration minutes: Int)

    /// 时间格式变更上报（FR31）
    /// Time format change reported (FR31)
    /// Zeitformat-Änderung gemeldet (FR31)
    func blueSDK(_ sdk: BlueSDK, didChangeTimeFormat format: TimeFormat)

    // MARK: - 设备状态 / Device Status / Gerätestatus

    /// 设备低电上报
    /// Device reports low battery
    /// Gerät meldet niedrigen Akkustand
    func blueSDKDidReportLowBattery(_ sdk: BlueSDK)

    /// 用药结果通知（设备闹钟响铃/超时/取药）
    /// Medication notification (alarm ringing / timeout / taken)
    /// Medikamentenbenachrichtigung (Alarm klingelt / Zeitüberschreitung / eingenommen)
    /// - Parameter type: 1=开始响铃等待取药, 2=超时未取药, 3=用户已取药
    /// - Parameter type: 1=ringing waiting, 2=timeout missed, 3=taken
    /// - Parameter type: 1=Klingeln wartet, 2=Zeitüberschreitung, 3=eingenommen
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationNotification type: Int)

    /// 设备端执行解绑操作上报
    /// Device reports unbind operation
    /// Gerät meldet Entbindungsvorgang
    func blueSDKDidReportDeviceUnbound(_ sdk: BlueSDK)

    /// 连接错误（超时、断开等）
    /// Connection error (timeout, disconnect, etc.)
    /// Verbindungsfehler (Zeitüberschreitung, Trennung usw.)
    func blueSDK(_ sdk: BlueSDK, didEncounterError error: BlueError)

    /// 正在自动重连
    /// Auto-reconnecting in progress
    /// Automatische Wiederverbindung läuft
    func blueSDK(_ sdk: BlueSDK, didStartReconnecting attempt: Int, maxAttempts: Int)

    /// 自动重连失败，已达最大尝试次数
    /// Auto-reconnection failed, max attempts reached
    /// Automatische Wiederverbindung fehlgeschlagen, maximale Versuche erreicht
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
    func blueSDK(_ sdk: BlueSDK, didChangeAlertDuration minutes: Int) {}
    func blueSDK(_ sdk: BlueSDK, didChangeTimeFormat format: TimeFormat) {}
    func blueSDKDidReportLowBattery(_ sdk: BlueSDK) {}
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationNotification type: Int) {}
    func blueSDKDidReportDeviceUnbound(_ sdk: BlueSDK) {}
    func blueSDK(_ sdk: BlueSDK, didEncounterError error: BlueError) {}
    func blueSDK(_ sdk: BlueSDK, didStartReconnecting attempt: Int, maxAttempts: Int) {}
    func blueSDKDidFailReconnection(_ sdk: BlueSDK) {}
}
