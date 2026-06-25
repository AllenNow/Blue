package com.blue.demo

import android.content.Context
import org.json.JSONObject
import java.util.Locale

/**
 * Demo App 多语言字符串管理
 * 从 assets/locales/{lang}.json 加载翻译
 * 加新语言只需新增 JSON 文件 + effectiveLang 加一行判断
 */
object S {
    private var strings: JSONObject = JSONObject()
    private var fallback: JSONObject = JSONObject()
    private var userLang: String? = null

    val isZh: Boolean get() = effectiveLang == "zh"
    val isDe: Boolean get() = effectiveLang == "de"

    /** App 启动时调用，加载翻译文件 */
    fun init(context: Context) {
        fallback = loadJson(context, "en")
        reload(context)
    }

    /** 设置用户选择的语言 */
    fun setUserLanguage(lang: String?, context: Context? = null) {
        userLang = lang
        context?.let { reload(it) }
    }

    private val effectiveLang: String get() {
        val lang = userLang ?: Locale.getDefault().language
        return when {
            lang.startsWith("zh") -> "zh"
            lang.startsWith("de") -> "de"
            else -> "en"
        }
    }

    private fun reload(context: Context) {
        strings = loadJson(context, effectiveLang)
    }

    private fun loadJson(context: Context, lang: String): JSONObject {
        return try {
            val text = context.assets.open("locales/$lang.json")
                .bufferedReader().use { it.readText() }
            JSONObject(text)
        } catch (e: Exception) {
            JSONObject()
        }
    }

    /** 按 key 取字符串，找不到时用英文兜底，再找不到返回 key 本身 */
    operator fun get(key: String): String {
        return strings.optString(key, fallback.optString(key, key))
    }

    // MARK: - 编译期安全属性（调用端保持 S.xxx 不变）

    // 主页
    val scan get() = this["scan"]
    val stopScan get() = this["stop_scan"]
    val disconnect get() = this["disconnect"]
    val notConnected get() = this["not_connected"]
    val connecting get() = this["connecting"]
    val authenticating get() = this["authenticating"]
    val connected get() = this["connected"]
    val reconnecting get() = this["reconnecting"]
    val scanning get() = this["scanning"]
    val scanFailed get() = this["scan_failed"]
    val connectingAuth get() = this["connecting_auth"]
    val scanConnecting get() = this["scan_connecting"]

    val deviceInfo get() = this["device_info"]
    val syncTime get() = this["sync_time"]
    val alarmManager get() = this["alarm_manager"]
    val medicationRecords get() = this["medication_records"]
    val protocolTest get() = this["protocol_test"]
    val faq get() = this["faq"]
    val clearAlarms get() = this["clear_alarms"]
    val restoreFactory get() = this["restore_factory"]
    val clearBinding get() = this["clear_binding"]

    // 铃声/音量/时制
    val soundType get() = this["sound_type"]
    val volume get() = this["volume"]
    val timeFormat get() = this["time_format"]
    val silence get() = this["silence"]
    val duration get() = this["duration"]
    val minutes get() = this["minutes"]
    val set get() = this["set"]
    val low get() = this["low"]
    val medium get() = this["medium"]
    val high get() = this["high"]

    // 日志
    val log get() = this["log"]
    val clear get() = this["clear"]

    // 对话框
    val cancel get() = this["cancel"]
    val confirm get() = this["confirm"]
    val clearAlarmsTitle get() = this["clear_alarms_title"]
    val clearAlarmsMsg get() = this["clear_alarms_msg"]
    val restoreFactoryTitle get() = this["restore_factory_title"]
    val restoreFactoryMsg get() = this["restore_factory_msg"]
    val clearBindingTitle get() = this["clear_binding_title"]
    val clearBindingMsg get() = this["clear_binding_msg"]
    val authFailedTitle get() = this["auth_failed_title"]
    val authFailedMsg get() = this["auth_failed_msg"]

    // 连接状态
    val userCancelled get() = this["user_cancelled"]
    val disconnected get() = this["disconnected"]
    val connectFirst get() = this["connect_first"]
    val scanningAuto get() = this["scanning_auto"]

    // 操作日志
    val queryingDevice get() = this["querying_device"]
    val syncingTime get() = this["syncing_time"]
    val timeSynced get() = this["time_synced"]
    val alarmsCleared get() = this["alarms_cleared"]
    val restoringFactory get() = this["restoring_factory"]
    val factoryRestored get() = this["factory_restored"]
    val bindingCleared get() = this["binding_cleared"]
    val sdkStarted get() = this["sdk_started"]
    val permDenied get() = this["perm_denied"]
    val scanStopped get() = this["scan_stopped"]
    val found get() = this["found"]

    // 语言选择
    val selectLanguage get() = this["select_language"]
    val languageSettings get() = this["language_settings"]
    val langChinese get() = "中文"
    val langEnglish get() = "English"
    val langGerman get() = "Deutsch"

    // 通知
    val alarmRingingTitle get() = this["alarm_ringing_title"]
    val alarmRingingMsg get() = this["alarm_ringing_msg"]
    val missedTitle get() = this["missed_title"]
    val missedMsg get() = this["missed_msg"]
    val takenTitle get() = this["taken_title"]
    val takenMsg get() = this["taken_msg"]
    val ok get() = this["ok"]
    val disconnectedTitle get() = this["disconnected_title"]
    val disconnectedMsg get() = this["disconnected_msg"]
    val deviceDisconnectedToast get() = this["device_disconnected_toast"]
    val durationError get() = this["duration_error"]

    // 闹钟管理
    val clearAll get() = this["clear_all"]
    val alarmSlotLabel get() = this["alarm_slot_label"]
    val alarmStatusOn get() = this["alarm_status_on"]
    val alarmStatusOff get() = this["alarm_status_off"]
    val alarmStatusUnset get() = this["alarm_status_unset"]
    val saveAlarm get() = this["save_alarm"]
    val deleteAlarm get() = this["delete_alarm"]
    val setAlarmFailed get() = this["set_alarm_failed"]
    val deleteAlarmFailed get() = this["delete_alarm_failed"]
    val repeatLabel get() = this["repeat_label"]
    val weekdayDaily get() = this["weekday_daily"]
    val weekdayWeekdays get() = this["weekday_weekdays"]
    val weekdayWeekend get() = this["weekday_weekend"]
    val delete get() = this["delete"]
    val back get() = this["back"]
    val send get() = this["send"]
    val weekdays: List<String> get() = listOf(
        this["weekday_mon"], this["weekday_tue"], this["weekday_wed"],
        this["weekday_thu"], this["weekday_fri"], this["weekday_sat"], this["weekday_sun"]
    )

    // 设备列表
    val noBoundDevices get() = this["no_bound_devices"]
    val noBoundDevicesHint get() = this["no_bound_devices_hint"]
    val deviceOnline get() = this["device_online"]
    val deviceOffline get() = this["device_offline"]
    val deviceNotFound get() = this["device_not_found"]
    val bluetoothUnavailable get() = this["bluetooth_unavailable"]
    val connectFailed get() = this["connect_failed"]
    val removeDeviceTitle get() = this["remove_device_title"]
    val removeDeviceMsg get() = this["remove_device_msg"]
    val authKeyLabel get() = this["auth_key_label"]
    val customKeyHint get() = this["custom_key_hint"]
    val authFailedStatus get() = this["auth_failed_status"]
    val unbindSuccess get() = this["unbind_success"]
    val unbindFailed get() = this["unbind_failed"]
    val scanningCustomKey get() = this["scanning_custom_key"]
    val scanningFixedKey get() = this["scanning_fixed_key"]
    val scanTimeout get() = this["scan_timeout"]

    // 扫描页
    val scanDevicesTitle get() = this["scan_devices_title"]
    val searchingNearby get() = this["searching_nearby"]
    val rescan get() = this["rescan"]
    val noNewDevices get() = this["no_new_devices"]
    val devicesFoundCount get() = this["devices_found_count"]
    val scanningFoundCount get() = this["scanning_found_count"]
    val scanError get() = this["scan_error"]
    val bind get() = this["bind"]
    val bluetoothPermissionRequired get() = this["bluetooth_permission_required"]

    // 用药记录
    val byDate get() = this["by_date"]
    val allRecords get() = this["all_records"]
    val legendTaken get() = this["legend_taken"]
    val legendLate get() = this["legend_late"]
    val legendMissed get() = this["legend_missed"]
    val legendEarly get() = this["legend_early"]
    val scheduledVsActual get() = this["scheduled_vs_actual"]
    val noRecordsForDate get() = this["no_records_for_date"]
    val clearRecords get() = this["clear_records"]
    val clearRecordsConfirmMsg get() = this["clear_records_confirm_msg"]
    val totalRecordsCount get() = this["total_records_count"]
    val dateRecordsCount get() = this["date_records_count"]

    // 协议测试
    val startTest get() = this["start_test"]
    val testing get() = this["testing"]
    val runningProtocolTest get() = this["running_protocol_test"]
    val testSkipped get() = this["test_skipped"]
    val retest get() = this["retest"]
    val allTestsPassed get() = this["all_tests_passed"]
    val testSummary get() = this["test_summary"]
    val protocolTestHint get() = this["protocol_test_hint"]

    // 调试面板
    val debugPanelTitle get() = this["debug_panel_title"]
    val exportLog get() = this["export_log"]
    val debugInputHint get() = this["debug_input_hint"]
    val debugReadyMsg get() = this["debug_ready_msg"]
    val debugCrcHint get() = this["debug_crc_hint"]
    val debugErrorEven get() = this["debug_error_even"]
    val debugErrorInvalidHex get() = this["debug_error_invalid_hex"]
    val autoCrcLabel get() = this["auto_crc_label"]

    // FAQ
    val faqTitle get() = this["faq_title"]
    val searchPlaceholder get() = this["search_placeholder"]
    val noMatchingQuestions get() = this["no_matching_questions"]
}
