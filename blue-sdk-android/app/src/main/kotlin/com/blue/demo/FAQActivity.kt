package com.blue.demo

import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import java.util.Locale

/**
 * FAQ page — list + search + click to detail + multilingual
 */
class FAQActivity : AppCompatActivity() {

    data class FAQItem(
        val questionZh: String, val questionEn: String, val questionDe: String,
        val answerZh: String, val answerEn: String, val answerDe: String,
        val category: String
    ) {
        val question: String get() = when {
            S.isDe -> questionDe
            S.isZh -> questionZh
            else -> questionEn
        }
        val answer: String get() = when {
            S.isDe -> answerDe
            S.isZh -> answerZh
            else -> answerEn
        }
    }

    companion object {
        val isZh: Boolean get() = S.isZh
    }

    private val allItems = listOf(
        FAQItem("扫描不到设备怎么办？", "Can't find the device when scanning?", "Gerät beim Scannen nicht gefunden?",
"""1. 确认设备已开机且蓝牙指示灯闪烁
2. 确认手机蓝牙已开启
3. Android 6~11 需要开启位置服务（系统限制）
4. Android 12+ 需要授予 BLUETOOTH_SCAN 权限
5. 确认设备在手机 3 米范围内
6. 如果之前连接过其他手机，需对设备恢复出厂
7. 尝试重启手机蓝牙后再扫描""",
"""1. Confirm device is powered on and Bluetooth LED is blinking
2. Confirm phone Bluetooth is enabled
3. Android 6~11 requires Location Services enabled
4. Android 12+ requires BLUETOOTH_SCAN permission
5. Confirm device is within 3 meters
6. If previously paired with another phone, factory reset the device
7. Try toggling Bluetooth off/on and scan again""",
"""1. Gerät ist eingeschaltet und Bluetooth-LED blinkt
2. Telefon-Bluetooth ist aktiviert
3. Android 6–11 erfordert aktivierte Standortdienste
4. Android 12+ erfordert BLUETOOTH_SCAN-Berechtigung
5. Gerät innerhalb von 3 Metern
6. Falls mit anderem Telefon gekoppelt: Werksreset durchführen
7. Bluetooth aus-/einschalten und erneut scannen""",
            "连接 / Connection / Verbindung"),

        FAQItem("认证失败是什么原因？", "Why does authentication fail?", "Warum schlägt die Authentifizierung fehl?",
"""认证失败常见原因：
1. 设备已被其他手机绑定 → 对设备恢复出厂，调用 clearBinding()
2. fixedAuthKey 错误 → 确认为4位十六进制或设为null自动计算
3. 固件不兼容 → queryDeviceInfo() 查看版本""",
"""Common causes:
1. Device bound to another phone → Factory reset, call clearBinding()
2. fixedAuthKey incorrect → Ensure 4-char hex or null for auto
3. Firmware incompatibility → Check via queryDeviceInfo()""",
"""Häufige Ursachen:
1. Gerät an anderes Telefon gebunden → Werksreset, clearBinding() aufrufen
2. fixedAuthKey falsch → 4-stellig hex oder null für Auto
3. Firmware-Inkompatibilität → Version über queryDeviceInfo() prüfen""",
            "连接 / Connection / Verbindung"),

        FAQItem("连接后自动断开是怎么回事？", "Why does it disconnect after connecting?", "Warum trennt es sich nach dem Verbinden?",
"""常见原因：
1. 认证失败后 SDK 自动断开
2. 设备电量不足
3. 距离过远（>3米）或有障碍物
4. 华为/小米省电策略杀后台

SDK 自动重连（最多5次，间隔2s/4s/8s）。""",
"""Common causes:
1. Auth failed — SDK disconnects automatically
2. Low device battery
3. Distance too far (>3m) or obstacles
4. Huawei/Xiaomi battery optimization kills background

SDK auto-reconnects (up to 5 times, 2s/4s/8s delays).""",
"""Häufige Ursachen:
1. Authentifizierung fehlgeschlagen — SDK trennt automatisch
2. Gerätebatterie niedrig
3. Entfernung zu groß (>3m) oder Hindernisse
4. Huawei/Xiaomi Energiesparmodus beendet Hintergrundprozesse

SDK verbindet automatisch erneut (bis zu 5 Mal, 2s/4s/8s Intervall).""",
            "连接 / Connection / Verbindung"),

        FAQItem("华为手机扫描不到设备？", "Huawei phone can't scan devices?", "Huawei-Telefon findet keine Geräte?",
"""Android 6~11 需要开启「位置服务」才能 BLE 扫描（系统限制）。
解决：扫描前检查位置服务，提示用户开启GPS。""",
"""Android 6~11 requires Location Services for BLE scanning (system limitation).
Solution: Check location services before scanning, prompt user to enable GPS.""",
"""Android 6–11 erfordert Standortdienste für BLE-Scan (Systemeinschränkung).
Lösung: Standortdienste vor dem Scannen prüfen, Benutzer auffordern GPS zu aktivieren.""",
            "连接 / Connection / Verbindung"),

        FAQItem("小米手机后台断连？", "Xiaomi phone disconnects in background?", "Xiaomi-Telefon trennt im Hintergrund?",
"""MIUI「省电优化」会杀后台蓝牙。需要：
1.「自启动管理」允许 APP
2.「电量和性能」关闭省电优化
3. 锁定在最近任务列表""",
"""MIUI battery optimization kills background BLE. Solutions:
1. Allow app in "Auto-start management"
2. Disable battery optimization for the app
3. Lock app in recent tasks""",
"""MIUI-Energiesparmodus beendet Hintergrund-BLE. Lösungen:
1. App unter „Autostart-Verwaltung" erlauben
2. Energiesparmodus für die App deaktivieren
3. App in der Liste der letzten Aufgaben sperren""",
            "连接 / Connection / Verbindung"),

        FAQItem("最多能设置几个闹钟？", "How many alarms can be set?", "Wie viele Alarme können eingestellt werden?",
"""LX-PD02 支持最多 7 个闹钟槽位（index 1~7）。
每个可独立设置时间和重复周期（WeekDays）。""",
"""LX-PD02 supports up to 7 alarm slots (index 1~7).
Each has independent time and repeat schedule (WeekDays).""",
"""LX-PD02 unterstützt bis zu 7 Alarm-Slots (Index 1–7).
Jeder hat unabhängige Zeit und Wiederholungsplan (WeekDays).""",
            "闹钟 / Alarm / Alarm"),

        FAQItem("批量设置闹钟会覆盖已有的吗？", "Does batch setting overwrite existing alarms?", "Überschreibt das Stapel-Setzen vorhandene Alarme?",
"""是的。setAlarms() 按索引逐个设置，已有闹钟会被覆盖。
追加闹钟：先 queryAlarm() 找空闲槽位（isDeleted=true）。""",
"""Yes. setAlarms() sets by index, overwriting existing ones.
To append: query free slots via queryAlarm() where isDeleted=true.""",
"""Ja. setAlarms() setzt nach Index und überschreibt vorhandene.
Zum Hinzufügen: freie Slots über queryAlarm() finden (isDeleted=true).""",
            "闹钟 / Alarm / Alarm"),

        FAQItem("用药事件有哪几种状态？", "What medication statuses are there?", "Welche Medikamentenstatus gibt es?",
"""MedicationStatus 有 4 种：
• TAKEN (0x01) — 按时取药
• TIMEOUT (0x02) — 超时取药
• MISSED (0x03) — 漏服
• EARLY (0x04) — 提前取药""",
"""MedicationStatus has 4 types:
• TAKEN (0x01) — Taken on time
• TIMEOUT (0x02) — Taken late
• MISSED (0x03) — Missed dose
• EARLY (0x04) — Taken early""",
"""MedicationStatus hat 4 Typen:
• TAKEN (0x01) — Pünktlich eingenommen
• TIMEOUT (0x02) — Verspätet eingenommen
• MISSED (0x03) — Vergessen
• EARLY (0x04) — Vorzeitig eingenommen""",
            "用药 / Medication / Medikation"),

        FAQItem("设备断线后用药记录会丢失吗？", "Will records be lost after disconnection?", "Gehen Aufzeichnungen nach Trennung verloren?",
"""不会。设备本地缓存记录，重连后自动上报。
建议 APP 使用 SQLite 持久化存储。""",
"""No. Device caches records locally, auto-reports after reconnection.
Recommend using SQLite for persistent storage.""",
"""Nein. Gerät speichert Aufzeichnungen lokal, meldet nach Neuverbindung automatisch.
Empfohlen: SQLite für dauerhafte Speicherung verwenden.""",
            "用药 / Medication / Medikation"),

        FAQItem("铃声和静音是什么关系？", "Relationship between sound type and silence?", "Beziehung zwischen Klingelton und Stummschaltung?",
"""静音 = 设置铃声类型为 MUTE(0x00)。
• setSilence(true) = setSoundType(MUTE)
• setSilence(false) = setSoundType(TYPE_A)""",
"""Silence = setting sound type to MUTE(0x00).
• setSilence(true) = setSoundType(MUTE)
• setSilence(false) = setSoundType(TYPE_A)""",
"""Stummschaltung = Klingeltontyp auf MUTE(0x00) setzen.
• setSilence(true) = setSoundType(MUTE)
• setSilence(false) = setSoundType(TYPE_A)""",
            "音频 / Audio / Audio"),

        FAQItem("多个指令可以连续调用吗？", "Can multiple commands be called consecutively?", "Können mehrere Befehle nacheinander aufgerufen werden?",
"""可以。SDK 内部 CommandQueue 自动串行排队。
• 同时只有一条指令等待应答
• 间隔至少 200ms
• 超时 5 秒，重试最多 3 次""",
"""Yes. Internal CommandQueue handles serial queuing.
• Only one command awaits response at a time
• Minimum 200ms interval
• 5-second timeout, up to 3 retries""",
"""Ja. Interne CommandQueue serialisiert automatisch.
• Nur ein Befehl wartet gleichzeitig auf Antwort
• Mindestens 200ms Intervall
• 5 Sekunden Timeout, bis zu 3 Wiederholungen""",
            "SDK"),

        FAQItem("SDK 初始化耗时多久？", "How long does initialization take?", "Wie lange dauert die Initialisierung?",
"""initialize() < 100ms，仅内存初始化。
建议在 Application.onCreate() 调用一次。""",
"""initialize() < 100ms, memory initialization only.
Recommended: call once in Application.onCreate().""",
"""initialize() < 100ms, nur Speicherinitialisierung.
Empfohlen: einmal in Application.onCreate() aufrufen.""",
            "SDK"),

        FAQItem("如何调试 BLE 通信问题？", "How to debug BLE communication?", "Wie debuggt man BLE-Kommunikation?",
"""1. 初始化时设置 rawFrameLogEnabled = true 开启帧日志
2. setLogHandler { } 自定义处理器
3. exportLog() 导出最近 1000 条""",
"""1. Set rawFrameLogEnabled = true in config for frame logs
2. setLogHandler { } for custom handler
3. exportLog() exports last 1000 entries""",
"""1. rawFrameLogEnabled = true in Config für Frame-Logs setzen
2. setLogHandler { } für benutzerdefinierten Handler
3. exportLog() exportiert die letzten 1000 Einträge""",
            "SDK"),

        FAQItem("恢复出厂设置后需要做什么？", "What to do after factory reset?", "Was ist nach einem Werksreset zu tun?",
"""1. 设备断开蓝牙
2. 设备清除所有闹钟和配对信息
3. APP 调用 clearBinding()
4. 重新扫描连接
注意：不可逆操作。""",
"""1. Device disconnects Bluetooth
2. Device clears all alarms and pairing info
3. Call clearBinding() in your app
4. Re-scan and connect
Note: This is irreversible.""",
"""1. Gerät trennt Bluetooth
2. Gerät löscht alle Alarme und Kopplungsinformationen
3. clearBinding() in Ihrer App aufrufen
4. Erneut scannen und verbinden
Hinweis: Dieser Vorgang ist nicht umkehrbar.""",
            "设备 / Device / Gerät"),

        FAQItem("设备同时只能连一台手机吗？", "Can the device connect to only one phone at a time?", "Kann das Gerät nur mit einem Telefon verbunden sein?",
"""是的。LX-PD02 采用绑定机制，认证成功后设备会记住手机密钥。
• 同一时间只能有一台手机连接
• 如需换手机使用，需先对设备恢复出厂设置
• 恢复后旧手机调用 clearBinding() 清除本地密钥""",
"""Yes. LX-PD02 uses a binding mechanism — after authentication, the device remembers the phone's key.
• Only one phone can connect at a time
• To switch phones, factory reset the device first
• After reset, call clearBinding() on the old phone to clear local key""",
"""Ja. LX-PD02 verwendet einen Bindungsmechanismus — nach der Authentifizierung merkt sich das Gerät den Telefonschlüssel.
• Nur ein Telefon kann gleichzeitig verbunden sein
• Zum Wechseln: zuerst Werksreset am Gerät durchführen
• Nach dem Reset: clearBinding() auf dem alten Telefon aufrufen""",
            "连接 / Connection / Verbindung"),

        FAQItem("闹钟时间设为 0:00 有效吗？", "Is alarm time 0:00 valid?", "Ist die Alarmzeit 0:00 gültig?",
"""有效。0:00 表示午夜（凌晨 12 点整）。
• 有效范围：hour 0~23, minute 0~59
• 无效值（如 hour=24 或 minute=60）SDK 会自动校正为 23:59
• 闹钟还有启用/禁用开关（isEnabled），禁用后不触发""",
"""Yes. 0:00 means midnight (12:00 AM).
• Valid range: hour 0~23, minute 0~59
• Invalid values (e.g., hour=24 or minute=60) are auto-corrected to 23:59 by SDK
• Alarms also have an enable/disable toggle (isEnabled) — disabled alarms won't trigger""",
"""Ja. 0:00 bedeutet Mitternacht (12:00 AM).
• Gültiger Bereich: Stunde 0–23, Minute 0–59
• Ungültige Werte (z.B. Stunde=24 oder Minute=60) werden vom SDK automatisch auf 23:59 korrigiert
• Alarme haben auch einen Aktivieren/Deaktivieren-Schalter (isEnabled) — deaktivierte Alarme lösen nicht aus""",
            "闹钟 / Alarm / Alarm"),

        FAQItem("如何判断设备是否在线？", "How to check if a device is online?", "Wie prüft man, ob ein Gerät online ist?",
"""SDK 提供 connectionState 属性实时查询：
• AUTHENTICATED = 在线且可操作
• CONNECTING/CONNECTED = 正在连接中
• DISCONNECTED = 离线

也可通过短时扫描（5秒）检测设备是否在蓝牙范围内：
startScan(timeoutMs = 5000) { event ->
    if (event is DeviceFound && event.device.deviceId == targetId) { /* 在线 */ }
}""",
"""SDK provides the connectionState property for real-time status:
• AUTHENTICATED = online and operable
• CONNECTING/CONNECTED = connection in progress
• DISCONNECTED = offline

You can also do a short scan (5s) to detect if device is in BLE range:
startScan(timeout: 5) { event in
    if case .deviceFound(let d) = event, d.deviceId == targetId { /* online */ }
}""",
"""SDK bietet die connectionState-Eigenschaft zur Echtzeit-Statusabfrage:
• AUTHENTICATED = online und betriebsbereit
• CONNECTING/CONNECTED = Verbindung wird hergestellt
• DISCONNECTED = offline

Sie können auch einen kurzen Scan (5s) durchführen:
startScan(timeoutMs = 5000) { event ->
    if (event is DeviceFound && event.device.deviceId == targetId) { /* online */ }
}""",
            "连接 / Connection / Verbindung"),

        FAQItem("如何切换 12/24 小时制？", "How to switch between 12H/24H time format?", "Wie wechselt man zwischen 12H/24H-Zeitformat?",
"""调用 setTimeFormat 即可切换：
• sdk.setTimeFormat(TimeFormat.HOUR_12) { } — 12 小时制
• sdk.setTimeFormat(TimeFormat.HOUR_24) { } — 24 小时制

切换后：
• SDK 内部 currentTimeFormat 属性自动更新
• 设备上报 onTimeFormatChanged 回调
• 界面应跟随此值显示时间（AM/PM 或 24H 格式）""",
"""Call setTimeFormat to switch:
• sdk.setTimeFormat(TimeFormat.HOUR_12) { } — 12-hour format
• sdk.setTimeFormat(TimeFormat.HOUR_24) { } — 24-hour format

After switching:
• SDK's currentTimeFormat property updates automatically
• Device reports onTimeFormatChanged callback
• UI should follow this value for time display (AM/PM or 24H)""",
"""Rufen Sie setTimeFormat auf:
• sdk.setTimeFormat(TimeFormat.HOUR_12) { } — 12-Stunden-Format
• sdk.setTimeFormat(TimeFormat.HOUR_24) { } — 24-Stunden-Format

Nach dem Wechsel:
• SDK-Eigenschaft currentTimeFormat wird automatisch aktualisiert
• Gerät meldet onTimeFormatChanged-Callback
• UI sollte diesem Wert folgen (AM/PM oder 24H-Anzeige)""",
            "设备 / Device / Gerät"),
    )

    private var filteredItems: List<FAQItem> = emptyList()
    private lateinit var listLayout: LinearLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        supportActionBar?.title = S.faqTitle
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        filteredItems = allItems
        setContentView(buildUI())
        renderList()
    }

    override fun onSupportNavigateUp(): Boolean { finish(); return true }

    private fun buildUI(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.BLACK)
        }
        // Search input
        val searchInput = EditText(this).apply {
            hint = S.searchPlaceholder
            setTextColor(Color.WHITE); setHintTextColor(Color.GRAY); textSize = 14f
            background = roundBg(Color.parseColor("#2C2C2E"), dp(8))
            setPadding(dp(16), dp(12), dp(16), dp(12))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply {
                setMargins(dp(12), dp(12), dp(12), dp(8))
            }
            addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                override fun afterTextChanged(s: Editable?) { filterItems(s?.toString() ?: "") }
            })
        }
        root.addView(searchInput)

        val scroll = ScrollView(this).apply { layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f) }
        listLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), 0, dp(12), dp(16))
        }
        scroll.addView(listLayout)
        root.addView(scroll)
        return root
    }

    private fun filterItems(query: String) {
        filteredItems = if (query.isBlank()) allItems
        else allItems.filter {
            it.question.contains(query, ignoreCase = true) ||
            it.answer.contains(query, ignoreCase = true) ||
            it.questionZh.contains(query, ignoreCase = true) ||
            it.answerZh.contains(query, ignoreCase = true)
        }
        renderList()
    }

    private fun renderList() {
        listLayout.removeAllViews()
        val categories = filteredItems.map { it.category }.distinct()
        categories.forEach { category ->
            listLayout.addView(TextView(this).apply {
                text = category; setTextColor(Color.GRAY); textSize = 12f
                typeface = Typeface.DEFAULT_BOLD; setPadding(dp(4), dp(12), 0, dp(6))
            })
            filteredItems.filter { it.category == category }.forEach { item ->
                val row = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
                    background = roundBg(Color.parseColor("#2C2C2E"), dp(8))
                    setPadding(dp(14), dp(14), dp(14), dp(14))
                    layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { bottomMargin = dp(4) }
                    setOnClickListener { showDetail(item) }
                }
                row.addView(TextView(this).apply {
                    text = item.question; setTextColor(Color.WHITE); textSize = 14f
                    layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
                })
                row.addView(TextView(this).apply { text = "›"; setTextColor(Color.GRAY); textSize = 18f })
                listLayout.addView(row)
            }
        }
        if (filteredItems.isEmpty()) {
            listLayout.addView(TextView(this).apply {
                text = S.noMatchingQuestions
                setTextColor(Color.GRAY); textSize = 14f; gravity = Gravity.CENTER
                setPadding(0, dp(40), 0, 0)
            })
        }
    }

    private fun showDetail(item: FAQItem) {
        startActivity(android.content.Intent(this, FAQDetailActivity::class.java).apply {
            putExtra("question", item.question)
            putExtra("answer", item.answer)
            putExtra("category", item.category)
        })
    }

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()
    private fun roundBg(c: Int, r: Int) = GradientDrawable().apply { shape = GradientDrawable.RECTANGLE; cornerRadius = r.toFloat(); setColor(c) }
}
