package com.blue.demo

import android.content.Context
import org.json.JSONObject
import java.util.Locale

/**
 * Demo App multi-language string management
 * Loads translations from assets/locales/{lang}.json
 * To add a new language, just add a JSON file + one line in effectiveLang
 */
object S {
    private var strings: JSONObject = JSONObject()
    private var fallback: JSONObject = JSONObject()
    private var userLang: String? = null

    val isZh: Boolean get() = effectiveLang == "zh"
    val isDe: Boolean get() = effectiveLang == "de"

    /** Called at app startup to load translation files */
    fun init(context: Context) {
        fallback = loadJson(context, "en")
        reload(context)
    }

    /** Set user-selected language */
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

    /** Get string by key, fall back to English, then return key itself if not found */
    operator fun get(key: String): String {
        return strings.optString(key, fallback.optString(key, key))
    }

    // MARK: - Compile-time safe properties (callers keep using S.xxx unchanged)

    // Main page
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

    // Sound/Volume/Time format
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

    // Log
    val log get() = this["log"]
    val clear get() = this["clear"]

    // Dialogs
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

    // Connection status
    val userCancelled get() = this["user_cancelled"]
    val disconnected get() = this["disconnected"]
    val connectFirst get() = this["connect_first"]
    val scanningAuto get() = this["scanning_auto"]

    // Operation logs
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

    // Language selection
    val selectLanguage get() = this["select_language"]
    val languageSettings get() = this["language_settings"]
    val langChinese get() = "中文"
    val langEnglish get() = "English"
    val langGerman get() = "Deutsch"

    // Notifications
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

    // Alarm management
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
    val am get() = this["am"]
    val pm get() = this["pm"]
    val delete get() = this["delete"]
    val back get() = this["back"]
    val send get() = this["send"]
    val weekdays: List<String> get() = listOf(
        this["weekday_sun"], this["weekday_mon"], this["weekday_tue"],
        this["weekday_wed"], this["weekday_thu"], this["weekday_fri"], this["weekday_sat"]
    )

    // Device list
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

    // Scan page
    val scanDevicesTitle get() = this["scan_devices_title"]
    val searchingNearby get() = this["searching_nearby"]
    val rescan get() = this["rescan"]
    val noNewDevices get() = this["no_new_devices"]
    val devicesFoundCount get() = this["devices_found_count"]
    val scanningFoundCount get() = this["scanning_found_count"]
    val scanError get() = this["scan_error"]
    val bind get() = this["bind"]
    val bluetoothPermissionRequired get() = this["bluetooth_permission_required"]

    // Medication records
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

    // Protocol test
    val startTest get() = this["start_test"]
    val testing get() = this["testing"]
    val runningProtocolTest get() = this["running_protocol_test"]
    val testSkipped get() = this["test_skipped"]
    val retest get() = this["retest"]
    val allTestsPassed get() = this["all_tests_passed"]
    val testSummary get() = this["test_summary"]
    val protocolTestHint get() = this["protocol_test_hint"]

    // Debug panel
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

    // Next alarm / medication records i18n
    val nextAlarmTitle get() = this["next_alarm_title"]
    val noActiveAlarms get() = this["no_active_alarms"]
    val nextAlarmHoursMins get() = this["next_alarm_hours_mins"]
    val nextAlarmMins get() = this["next_alarm_mins"]
    val alarmIndexStatus get() = this["alarm_index_status"]
    val scheduledActualTime get() = this["scheduled_actual_time"]
    val statusTaken get() = this["status_taken"]
    val statusLate get() = this["status_late"]
    val statusMissed get() = this["status_missed"]
    val statusEarly get() = this["status_early"]
    val statusUnknown get() = this["status_unknown"]
    val medRecordLog get() = this["med_record_log"]
}
