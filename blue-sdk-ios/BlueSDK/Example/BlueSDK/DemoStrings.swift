// DemoStrings.swift
// BlueSDK Example - Demo App 多语言字符串
// 从 Locales/*.json 加载翻译，加新语言只需新增 JSON 文件

import Foundation
import BlueSDK

/// Demo App 多语言字符串
/// 从 JSON 文件加载，支持运行时切换
enum S {
    private static var strings: [String: String] = [:]
    private static var fallback: [String: String] = [:]

    static var isZh: Bool { effectiveLang == "zh" }
    static var isDe: Bool { effectiveLang == "de" }

    /// App 启动时调用
    static func initialize() {
        fallback = loadJSON(lang: "en")
        reload()
    }

    /// 切换语言后调用
    static func setLanguage(_ lang: String?) {
        UserDefaults.standard.set(lang, forKey: "demo_language")
        reload()
    }

    private static func reload() {
        strings = loadJSON(lang: effectiveLang)
    }

    private static var effectiveLang: String {
        if let saved = UserDefaults.standard.string(forKey: "demo_language") {
            if saved.hasPrefix("zh") { return "zh" }
            if saved.hasPrefix("de") { return "de" }
            return "en"
        }
        let sysLang = Locale.preferredLanguages.first ?? "en"
        if sysLang.hasPrefix("zh") { return "zh" }
        if sysLang.hasPrefix("de") { return "de" }
        return "en"
    }

    private static func loadJSON(lang: String) -> [String: String] {
        guard let url = Bundle.main.url(forResource: lang, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: String]
        else { return [:] }
        return dict
    }

    /// 按 key 取字符串
    static subscript(key: String) -> String {
        strings[key] ?? fallback[key] ?? key
    }

    // MARK: - 编译期安全属性（调用端保持 S.xxx 不变）

    // 主页按钮
    static var scan: String { self["scan"] }
    static var stopScan: String { self["stop_scan"] }
    static var disconnect: String { self["disconnect"] }
    static var deviceInfo: String { self["device_info"] }
    static var syncTime: String { self["sync_time"] }
    static var alarmManager: String { self["alarm_manager"] }
    static var medicationRecords: String { self["medication_records"] }
    static var protocolTest: String { self["protocol_test"] }
    static var faq: String { self["faq"] }
    static var clearAlarms: String { self["clear_alarms"] }
    static var restoreFactory: String { self["restore_factory"] }
    static var clearBinding: String { self["clear_binding"] }
    static var debug: String { self["debug"] }

    // 音频设置
    static var soundType: String { self["sound_type"] }
    static var volume: String { self["volume"] }
    static var timeFormat: String { self["time_format"] }
    static var silence: String { self["silence"] }
    static var duration: String { self["duration"] }
    static var minutes: String { self["minutes"] }
    static var setBtn: String { self["set"] }
    static var low: String { self["low"] }
    static var medium: String { self["medium"] }
    static var high: String { self["high"] }

    // 日志区
    static var log: String { self["log"] }
    static var clear: String { self["clear"] }

    // 状态
    static var notConnected: String { self["not_connected"] }
    static var connecting: String { self["connecting"] }
    static var authenticating: String { self["authenticating"] }
    static var connected: String { self["connected"] }
    static var reconnecting: String { self["reconnecting"] }
    static var scanning: String { self["scanning"] }
    static var scanFailed: String { self["scan_failed"] }
    static var scanConnecting: String { self["scan_connecting"] }
    static var connectingAuth: String { self["connecting_auth"] }
    static var userCancelled: String { self["user_cancelled"] }
    static var sdkStarted: String { self["sdk_started"] }

    // 对话框
    static var cancel: String { self["cancel"] }
    static var confirm: String { self["confirm"] }
    static var clearAlarmsTitle: String { self["clear_alarms_title"] }
    static var clearAlarmsMsg: String { self["clear_alarms_msg"] }
    static var restoreFactoryTitle: String { self["restore_factory_title"] }
    static var restoreFactoryMsg: String { self["restore_factory_msg"] }
    static var clearBindingTitle: String { self["clear_binding_title"] }
    static var clearBindingMsg: String { self["clear_binding_msg"] }
    static var authFailedTitle: String { self["auth_failed_title"] }
    static var authFailedMsg: String { self["auth_failed_msg"] }

    // 日志消息
    static var found: String { self["found"] }
    static var disconnected: String { self["disconnected"] }
    static var alarmsCleared: String { self["alarms_cleared"] }
    static var factoryRestored: String { self["factory_restored"] }
    static var bindingCleared: String { self["binding_cleared"] }
    static var scanningAuto: String { self["scanning_auto"] }
    static var scanStopped: String { self["scan_stopped"] }

    // 用药通知
    static var alarmRingingTitle: String { self["alarm_ringing_title"] }
    static var alarmRingingMsg: String { self["alarm_ringing_msg"] }
    static var missedTitle: String { self["missed_title"] }
    static var missedMsg: String { self["missed_msg"] }
    static var takenTitle: String { self["taken_title"] }
    static var takenMsg: String { self["taken_msg"] }
    static var ok: String { self["ok"] }

    // 断开提示
    static var disconnectedTitle: String { self["disconnected_title"] }
    static var disconnectedMsg: String { self["disconnected_msg"] }
    static var deviceDisconnectedToast: String { self["device_disconnected_toast"] }

    // 响铃时长
    static var durationError: String { self["duration_error"] }

    // 闹钟管理
    static var clearAll: String { self["clear_all"] }
    static var alarmSlotLabel: String { self["alarm_slot_label"] }
    static var alarmStatusOn: String { self["alarm_status_on"] }
    static var alarmStatusOff: String { self["alarm_status_off"] }
    static var alarmStatusUnset: String { self["alarm_status_unset"] }
    static var saveAlarm: String { self["save_alarm"] }
    static var deleteAlarm: String { self["delete_alarm"] }
    static var setAlarmFailed: String { self["set_alarm_failed"] }
    static var deleteAlarmFailed: String { self["delete_alarm_failed"] }
    static var repeatLabel: String { self["repeat_label"] }
    static var weekdayDaily: String { self["weekday_daily"] }
    static var weekdayWeekdays: String { self["weekday_weekdays"] }
    static var weekdayWeekend: String { self["weekday_weekend"] }
    static var delete: String { self["delete"] }
    static var back: String { self["back"] }
    static var send: String { self["send"] }
    static var alarmRinging: String { self["alarm_ringing"] }
    static var alarmDone: String { self["alarm_done"] }
    static var weekdays: [String] {
        [self["weekday_mon"], self["weekday_tue"], self["weekday_wed"],
         self["weekday_thu"], self["weekday_fri"], self["weekday_sat"], self["weekday_sun"]]
    }

    // 设备列表
    static var noBoundDevices: String { self["no_bound_devices"] }
    static var noBoundDevicesHint: String { self["no_bound_devices_hint"] }
    static var deviceOnline: String { self["device_online"] }
    static var deviceOffline: String { self["device_offline"] }
    static var deviceNotFound: String { self["device_not_found"] }
    static var bluetoothUnavailable: String { self["bluetooth_unavailable"] }
    static var connectFailed: String { self["connect_failed"] }
    static var removeDeviceTitle: String { self["remove_device_title"] }
    static var removeDeviceMsg: String { self["remove_device_msg"] }
    static var authKeyLabel: String { self["auth_key_label"] }
    static var customKeyHint: String { self["custom_key_hint"] }
    static var authFailedStatus: String { self["auth_failed_status"] }
    static var unbindSuccess: String { self["unbind_success"] }
    static var unbindFailed: String { self["unbind_failed"] }
    static var scanningCustomKey: String { self["scanning_custom_key"] }
    static var scanningFixedKey: String { self["scanning_fixed_key"] }
    static var scanTimeout: String { self["scan_timeout"] }

    // 扫描页
    static var scanDevicesTitle: String { self["scan_devices_title"] }
    static var searchingNearby: String { self["searching_nearby"] }
    static var rescan: String { self["rescan"] }
    static var noNewDevices: String { self["no_new_devices"] }
    static var devicesFoundCount: String { self["devices_found_count"] }
    static var scanningFoundCount: String { self["scanning_found_count"] }
    static var scanError: String { self["scan_error"] }
    static var bind: String { self["bind"] }
    static var bluetoothPermissionRequired: String { self["bluetooth_permission_required"] }

    // 用药记录
    static var byDate: String { self["by_date"] }
    static var allRecords: String { self["all_records"] }
    static var legendTaken: String { self["legend_taken"] }
    static var legendLate: String { self["legend_late"] }
    static var legendMissed: String { self["legend_missed"] }
    static var legendEarly: String { self["legend_early"] }
    static var scheduledVsActual: String { self["scheduled_vs_actual"] }
    static var noRecordsForDate: String { self["no_records_for_date"] }
    static var clearRecords: String { self["clear_records"] }
    static var clearRecordsConfirmMsg: String { self["clear_records_confirm_msg"] }
    static var recordTitleFormat: String { self["record_title_format"] }
    static var scheduledActualFormat: String { self["scheduled_actual_format"] }
    static var totalRecordsCount: String { self["total_records_count"] }
    static var dateRecordsCount: String { self["date_records_count"] }

    // 协议测试
    static var startTest: String { self["start_test"] }
    static var testing: String { self["testing"] }
    static var runningProtocolTest: String { self["running_protocol_test"] }
    static var testSkipped: String { self["test_skipped"] }
    static var retest: String { self["retest"] }
    static var allTestsPassed: String { self["all_tests_passed"] }
    static var testSummary: String { self["test_summary"] }
    static var protocolTestHint: String { self["protocol_test_hint"] }

    // 调试面板
    static var debugPanelTitle: String { self["debug_panel_title"] }
    static var exportLog: String { self["export_log"] }
    static var debugInputHint: String { self["debug_input_hint"] }
    static var debugReadyMsg: String { self["debug_ready_msg"] }
    static var debugCrcHint: String { self["debug_crc_hint"] }
    static var debugErrorEven: String { self["debug_error_even"] }
    static var debugErrorInvalidHex: String { self["debug_error_invalid_hex"] }
    static var autoCrcLabel: String { self["auto_crc_label"] }

    // FAQ
    static var faqTitle: String { self["faq_title"] }
    static var searchPlaceholder: String { self["search_placeholder"] }
    static var noMatchingQuestions: String { self["no_matching_questions"] }
}
