// DemoStrings.swift
// BlueSDK Example - Demo App 多语言字符串（中/英/德）
// Demo App trilingual strings (zh/en/de)

import Foundation
import BlueSDK

/// Demo App 多语言字符串
/// Demo App trilingual strings
enum S {
    static var isZh: Bool { SDKLocale.isZh }
    static var isDe: Bool { SDKLocale.isDe }

    // MARK: - 主页按钮 / Main buttons

    static var scan: String { t("扫描", "Scan", "Scannen") }
    static var stopScan: String { t("停止扫描", "Stop", "Stopp") }
    static var disconnect: String { t("断开", "Disconnect", "Trennen") }
    static var deviceInfo: String { t("设备信息", "Device", "Gerät") }
    static var syncTime: String { t("同步时间", "Sync Time", "Zeit sync.") }
    static var alarmManager: String { t("闹钟管理", "Alarms", "Alarme") }
    static var medicationRecords: String { t("用药记录", "Records", "Aufzeichn.") }
    static var protocolTest: String { t("指令验证", "Protocol", "Protokoll") }
    static var faq: String { t("常见问题", "FAQ", "FAQ") }
    static var clearAlarms: String { t("清空闹钟", "Clear Alarms", "Alarme lösch.") }
    static var restoreFactory: String { t("恢复出厂", "Reset", "Werksreset") }
    static var clearBinding: String { t("解绑设备", "Unbind", "Entkoppeln") }
    static var debug: String { t("调试", "Debug", "Debug") }

    // MARK: - 音频设置标签 / Audio labels

    static var soundType: String { t("铃声", "Sound", "Klingelton") }
    static var volume: String { t("音量", "Vol", "Lautst.") }
    static var timeFormat: String { t("时制", "Format", "Format") }
    static var silence: String { t("静音", "Mute", "Stumm") }
    static var duration: String { t("持续", "Dur", "Dauer") }
    static var minutes: String { t("分", "min", "Min") }
    static var setBtn: String { t("设置", "Set", "Setzen") }

    // MARK: - 日志区 / Log

    static var log: String { t("日志", "Log", "Protokoll") }
    static var clear: String { t("清空", "Clear", "Löschen") }

    // MARK: - 状态 / Status

    static var notConnected: String { t("未连接", "Not Connected", "Nicht verbunden") }
    static var connecting: String { t("连接中...", "Connecting...", "Verbinden...") }
    static var authenticating: String { t("认证中...", "Authenticating...", "Authentifizieren...") }
    static var connected: String { t("已连接", "Connected", "Verbunden") }
    static var reconnecting: String { t("重连中...", "Reconnecting...", "Neuverbinden...") }
    static var scanning: String { t("扫描中...", "Scanning...", "Scannen...") }
    static var scanFailed: String { t("扫描失败", "Scan Failed", "Scan fehlgeschlagen") }
    static var scanConnecting: String { t("扫描连接中...", "Scanning...", "Scannen...") }
    static var connectingAuth: String { t("连接认证中...", "Authenticating...", "Authentifizieren...") }
    static var userCancelled: String { t("用户取消连接", "Cancelled", "Abgebrochen") }
    static var sdkStarted: String { t("SDK 已启动", "SDK started", "SDK gestartet") }

    // MARK: - 对话框 / Dialogs

    static var cancel: String { t("取消", "Cancel", "Abbrechen") }
    static var confirm: String { t("确定", "OK", "OK") }
    static var clearAlarmsTitle: String { t("清空闹钟", "Clear Alarms", "Alarme löschen") }
    static var clearAlarmsMsg: String { t("确定清空所有闹钟？", "Clear all alarms?", "Alle Alarme löschen?") }
    static var restoreFactoryTitle: String { t("恢复出厂", "Factory Reset", "Werksreset") }
    static var restoreFactoryMsg: String { t("确定恢复出厂设置？", "Confirm factory reset?", "Werkseinstellungen wiederherstellen?") }
    static var clearBindingTitle: String { t("解绑设备", "Unbind Device", "Gerät entkoppeln") }
    static var clearBindingMsg: String { t("确定解绑设备？解绑后需重新配对。", "Unbind device? Re-pairing required.", "Gerät entkoppeln? Erneutes Koppeln nötig.") }
    static var authFailedTitle: String { t("认证失败", "Auth Failed", "Authentifizierung fehlgeschlagen") }
    static var authFailedMsg: String { t("密钥不一致，请对设备长按按键恢复出厂设置后重试。", "Key mismatch. Long-press device button to factory reset, then retry.", "Schlüssel stimmt nicht. Taste am Gerät lang drücken für Werksreset.") }

    // MARK: - 日志消息 / Log messages

    static var alarmsCleared: String { t("所有闹钟已清空", "All alarms cleared", "Alle Alarme gelöscht") }
    static var factoryRestored: String { t("已恢复出厂", "Factory restored", "Werkseinstellungen wiederhergestellt") }
    static var bindingCleared: String { t("本地绑定已清除", "Binding cleared", "Lokale Bindung gelöscht") }
    static var scanningAuto: String { t("扫描中...（自动密钥）", "Scanning... (auto key)", "Scannen... (Auto-Schlüssel)") }
    static var scanStopped: String { t("扫描超时", "Scan timeout", "Scan-Timeout") }

    // MARK: - 用药通知 / Medication notifications

    static var alarmRingingTitle: String { t("💊 闹钟响铃", "💊 Alarm Ringing", "💊 Alarm klingelt") }
    static var alarmRingingMsg: String { t("请及时取药", "Please take your medication", "Bitte nehmen Sie Ihre Medikamente") }
    static var missedTitle: String { t("用药提醒", "Medication Reminder", "Medikamenten-Erinnerung") }
    static var missedMsg: String { t("您已超时未取药，请尽快服药！", "You missed your medication!", "Sie haben Ihre Medikamente verpasst!") }
    static var takenTitle: String { t("👏 按时服药", "👏 Well Done", "👏 Gut gemacht") }
    static var takenMsg: String { t("太棒了！坚持按时服药有助于健康。", "Great! Keep taking medication on time.", "Toll! Nehmen Sie weiter pünktlich Ihre Medikamente.") }
    static var ok: String { t("知道了", "OK", "OK") }

    // MARK: - 断开提示 / Disconnect alert

    static var disconnectedTitle: String { t("连接断开", "Disconnected", "Verbindung getrennt") }
    static var disconnectedMsg: String { t("设备连接已断开，请检查设备状态后重新连接。", "Device disconnected. Check device and reconnect.", "Gerät getrennt. Überprüfen und erneut verbinden.") }

    // MARK: - 响铃时长 / Duration

    static var durationError: String { t("响铃时长范围：1~5分钟", "Duration range: 1~5 min", "Dauer: 1~5 Min") }

    // MARK: - 工具方法

    private static func t(_ zh: String, _ en: String, _ de: String) -> String {
        switch SDKLocale.current {
        case .zh: return zh
        case .en: return en
        case .de: return de
        }
    }
}
