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
 * 常见问题页面 — 列表 + 搜索 + 点击进入详情 + 中英双语
 */
class FAQActivity : AppCompatActivity() {

    data class FAQItem(
        val questionZh: String, val questionEn: String,
        val answerZh: String, val answerEn: String,
        val category: String
    ) {
        val question: String get() = if (isZh) questionZh else questionEn
        val answer: String get() = if (isZh) answerZh else answerEn
    }

    companion object {
        val isZh: Boolean get() = Locale.getDefault().language.startsWith("zh")
    }

    private val allItems = listOf(
        FAQItem("扫描不到设备怎么办？", "Can't find the device when scanning?",
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
            "连接 / Connection"),

        FAQItem("认证失败是什么原因？", "Why does authentication fail?",
"""认证失败常见原因：
1. 设备已被其他手机绑定 → 对设备恢复出厂，调用 clearBinding()
2. fixedAuthKey 错误 → 确认为4位十六进制或设为null自动计算
3. 固件不兼容 → queryDeviceInfo() 查看版本""",
"""Common causes:
1. Device bound to another phone → Factory reset, call clearBinding()
2. fixedAuthKey incorrect → Ensure 4-char hex or null for auto
3. Firmware incompatibility → Check via queryDeviceInfo()""",
            "连接 / Connection"),

        FAQItem("连接后自动断开是怎么回事？", "Why does it disconnect after connecting?",
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
            "连接 / Connection"),

        FAQItem("华为手机扫描不到设备？", "Huawei phone can't scan devices?",
"""Android 6~11 需要开启「位置服务」才能 BLE 扫描（系统限制）。
解决：扫描前检查位置服务，提示用户开启GPS。""",
"""Android 6~11 requires Location Services for BLE scanning (system limitation).
Solution: Check location services before scanning, prompt user to enable GPS.""",
            "连接 / Connection"),

        FAQItem("小米手机后台断连？", "Xiaomi phone disconnects in background?",
"""MIUI「省电优化」会杀后台蓝牙。需要：
1.「自启动管理」允许 APP
2.「电量和性能」关闭省电优化
3. 锁定在最近任务列表""",
"""MIUI battery optimization kills background BLE. Solutions:
1. Allow app in "Auto-start management"
2. Disable battery optimization for the app
3. Lock app in recent tasks""",
            "连接 / Connection"),

        FAQItem("最多能设置几个闹钟？", "How many alarms can be set?",
"""LX-PD02 支持最多 7 个闹钟槽位（index 1~7）。
每个可独立设置时间和重复周期（WeekDays）。""",
"""LX-PD02 supports up to 7 alarm slots (index 1~7).
Each has independent time and repeat schedule (WeekDays).""",
            "闹钟 / Alarm"),

        FAQItem("批量设置闹钟会覆盖已有的吗？", "Does batch setting overwrite existing alarms?",
"""是的。setAlarms() 按索引逐个设置，已有闹钟会被覆盖。
追加闹钟：先 queryAlarm() 找空闲槽位（isDeleted=true）。""",
"""Yes. setAlarms() sets by index, overwriting existing ones.
To append: query free slots via queryAlarm() where isDeleted=true.""",
            "闹钟 / Alarm"),

        FAQItem("用药事件有哪几种状态？", "What medication statuses are there?",
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
            "用药 / Medication"),

        FAQItem("设备断线后用药记录会丢失吗？", "Will records be lost after disconnection?",
"""不会。设备本地缓存记录，重连后自动上报。
建议 APP 使用 SQLite 持久化存储。""",
"""No. Device caches records locally, auto-reports after reconnection.
Recommend using SQLite for persistent storage.""",
            "用药 / Medication"),

        FAQItem("铃声和静音是什么关系？", "Relationship between sound type and silence?",
"""静音 = 设置铃声类型为 MUTE(0x00)。
• setSilence(true) = setSoundType(MUTE)
• setSilence(false) = setSoundType(TYPE_A)""",
"""Silence = setting sound type to MUTE(0x00).
• setSilence(true) = setSoundType(MUTE)
• setSilence(false) = setSoundType(TYPE_A)""",
            "音频 / Audio"),

        FAQItem("多个指令可以连续调用吗？", "Can multiple commands be called consecutively?",
"""可以。SDK 内部 CommandQueue 自动串行排队。
• 同时只有一条指令等待应答
• 间隔至少 200ms
• 超时 5 秒，重试最多 3 次""",
"""Yes. Internal CommandQueue handles serial queuing.
• Only one command awaits response at a time
• Minimum 200ms interval
• 5-second timeout, up to 3 retries""",
            "SDK"),

        FAQItem("SDK 初始化耗时多久？", "How long does initialization take?",
"""initialize() < 100ms，仅内存初始化。
建议在 Application.onCreate() 调用一次。""",
"""initialize() < 100ms, memory initialization only.
Recommended: call once in Application.onCreate().""",
            "SDK"),

        FAQItem("如何调试 BLE 通信问题？", "How to debug BLE communication?",
"""1. setLogLevel(LogLevel.DEBUG) 开启帧日志
2. setLogHandler { } 自定义处理器
3. exportLog() 导出最近 1000 条
4. 使用「协议验证」页面自动化测试""",
"""1. setLogLevel(LogLevel.DEBUG) for frame logs
2. setLogHandler { } for custom handler
3. exportLog() exports last 1000 entries
4. Use "Protocol Test" page for automated testing""",
            "SDK"),

        FAQItem("恢复出厂设置后需要做什么？", "What to do after factory reset?",
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
            "设备 / Device"),
    )

    private var filteredItems: List<FAQItem> = emptyList()
    private lateinit var listLayout: LinearLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        supportActionBar?.title = if (isZh) "常见问题" else "FAQ"
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
        // 搜索框
        val searchInput = EditText(this).apply {
            hint = if (isZh) "搜索问题..." else "Search..."
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
                text = if (isZh) "没有匹配的问题" else "No matching questions"
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
