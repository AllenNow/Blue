package com.blue.demo

import java.util.Locale

/**
 * Demo App 多语言字符串管理
 * 优先使用用户手动选择的语言，否则跟随系统语言
 */
object S {
    /** 用户手动选择的语言代码（null 表示未选择，跟随系统） */
    private var userLang: String? = null

    /** 由 App 启动时从 SharedPreferences 加载 */
    fun setUserLanguage(lang: String?) {
        userLang = lang
    }

    /** 当前生效的语言代码 */
    private val effectiveLang: String get() = userLang ?: Locale.getDefault().language

    val isZh: Boolean get() = effectiveLang.startsWith("zh")
    val isDe: Boolean get() = effectiveLang.startsWith("de")

    // 主页
    val scan get() = t("扫描", "Scan", "Scannen")
    val stopScan get() = t("停止扫描", "Stop Scan", "Stoppen")
    val disconnect get() = t("断开", "Disconnect", "Trennen")
    val notConnected get() = t("未连接", "Not Connected", "Nicht verbunden")
    val connecting get() = t("连接中...", "Connecting...", "Verbinden...")
    val authenticating get() = t("认证中...", "Authenticating...", "Authentifizieren...")
    val connected get() = t("已连接", "Connected", "Verbunden")
    val reconnecting get() = t("重连中...", "Reconnecting...", "Neuverbinden...")
    val scanning get() = t("扫描中...", "Scanning...", "Scannen...")
    val scanFailed get() = t("扫描失败", "Scan Failed", "Scan fehlgeschlagen")
    val connectingAuth get() = t("连接认证中...", "Authenticating...", "Authentifizieren...")
    val scanConnecting get() = t("扫描连接中...", "Scanning...", "Scannen...")

    val deviceInfo get() = t("设备信息", "Device Info", "Geräteinfo")
    val syncTime get() = t("同步时间", "Sync Time", "Zeit sync.")
    val alarmManager get() = t("闹钟管理", "Alarms", "Alarme")
    val medicationRecords get() = t("用药记录", "Records", "Aufzeichn.")
    val protocolTest get() = t("指令验证", "Protocol", "Protokoll")
    val faq get() = t("常见问题", "FAQ", "FAQ")
    val clearAlarms get() = t("清空闹钟", "Clear Alarms", "Alarme lösch.")
    val restoreFactory get() = t("恢复出厂", "Factory Reset", "Werksreset")
    val clearBinding get() = t("解绑设备", "Unbind", "Entkoppeln")

    // 铃声/音量/时制
    val soundType get() = t("铃声", "Sound", "Klingelton")
    val volume get() = t("音量", "Volume", "Lautstärke")
    val timeFormat get() = t("时制", "Format", "Format")
    val silence get() = t("静音", "Mute", "Stumm")
    val duration get() = t("持续", "Duration", "Dauer")
    val minutes get() = t("分", "min", "Min")
    val set get() = t("设置", "Set", "Setzen")
    val low get() = t("低", "Low", "Niedrig")
    val medium get() = t("中", "Med", "Mittel")
    val high get() = t("高", "High", "Hoch")

    // 日志
    val log get() = t("日志", "Log", "Protokoll")
    val clear get() = t("清空", "Clear", "Löschen")

    // 对话框
    val cancel get() = t("取消", "Cancel", "Abbrechen")
    val confirm get() = t("确定", "OK", "OK")
    val clearAlarmsTitle get() = t("清空闹钟", "Clear Alarms", "Alarme löschen")
    val clearAlarmsMsg get() = t("确定清空所有闹钟？", "Clear all alarms?", "Alle Alarme löschen?")
    val restoreFactoryTitle get() = t("恢复出厂", "Factory Reset", "Werksreset")
    val restoreFactoryMsg get() = t("确定恢复出厂设置？", "Confirm factory reset?", "Werkseinstellungen wiederherstellen?")
    val clearBindingTitle get() = t("解绑设备", "Unbind Device", "Gerät entkoppeln")
    val clearBindingMsg get() = t("确定解绑设备？解绑后需重新配对。", "Unbind device? Re-pairing required afterwards.", "Gerät entkoppeln? Erneutes Koppeln erforderlich.")
    val authFailedTitle get() = t("认证失败", "Auth Failed", "Authentifizierung fehlgeschl.")
    val authFailedMsg get() = t("密钥不一致，请对设备长按按键恢复出厂设置后重试。", "Key mismatch. Long-press device button to factory reset, then retry.", "Schlüssel stimmt nicht überein. Taste am Gerät lang drücken für Werksreset.")

    // 连接状态
    val userCancelled get() = t("用户取消连接", "Connection cancelled", "Verbindung abgebrochen")
    val disconnected get() = t("已断开", "Disconnected", "Getrennt")
    val connectFirst get() = t("请先连接设备", "Connect device first", "Bitte zuerst Gerät verbinden")
    val scanningAuto get() = t("扫描中...（自动密钥）", "Scanning... (auto key)", "Scannen... (Auto-Schlüssel)")

    // 操作日志
    val queryingDevice get() = t("查询设备信息...", "Querying device info...", "Geräteinfo abfragen...")
    val syncingTime get() = t("同步时间...", "Syncing time...", "Zeit synchronisieren...")
    val timeSynced get() = t("时间已同步", "Time synced", "Zeit synchronisiert")
    val alarmsCleared get() = t("所有闹钟已清空", "All alarms cleared", "Alle Alarme gelöscht")
    val restoringFactory get() = t("恢复出厂中...", "Restoring factory...", "Werksreset läuft...")
    val factoryRestored get() = t("已恢复出厂", "Factory restored", "Werkseinstellungen wiederhergestellt")
    val bindingCleared get() = t("本地绑定已清除", "Local binding cleared", "Lokale Bindung gelöscht")
    val sdkStarted get() = t("SDK 已启动", "SDK started", "SDK gestartet")
    val permDenied get() = t("权限未授予", "Permission denied", "Berechtigung verweigert")
    val scanStopped get() = t("扫描已停止", "Scan stopped", "Scan gestoppt")
    val found get() = t("发现", "Found", "Gefunden")

    // 语言选择页
    val selectLanguage get() = t("选择语言", "Select Language", "Sprache wählen")
    val languageSettings get() = t("语言设置", "Language", "Sprache")
    val langChinese get() = "中文"
    val langEnglish get() = "English"
    val langGerman get() = "Deutsch"

    private fun t(zh: String, en: String, de: String) = when {
        isZh -> zh
        isDe -> de
        else -> en
    }
}
