package com.blue.demo

import android.Manifest
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.text.method.ScrollingMovementMethod
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import com.blue.sdk.BlueSDK
import com.blue.sdk.BlueSDKListener
import com.blue.sdk.enums.*
import com.blue.sdk.error.BlueError
import com.blue.sdk.model.AlarmInfo
import com.blue.sdk.model.MedicationRecord
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : AppCompatActivity(), BlueSDKListener {

    private lateinit var statusDot: View
    private lateinit var statusLabel: TextView
    private lateinit var logTextView: TextView
    private lateinit var durationInput: EditText

    private val sdk get() = BlueSDK.getInstance(this)
    private val timeFmt = SimpleDateFormat("HH:mm:ss", Locale.getDefault())

    private val bgDark = Color.parseColor("#1C1C1E")
    private val bgCard = Color.parseColor("#2C2C2E")
    private val bgSegment = Color.parseColor("#3A3A3C")
    private val textWhite = Color.WHITE
    private val textGray = Color.parseColor("#8E8E93")
    private val accentBlue = Color.parseColor("#007AFF")
    private val accentRed = Color.parseColor("#FF3B30")
    private val accentPurple = Color.parseColor("#5856D6")
    private val accentPink = Color.parseColor("#FF2D55")
    private val accentOrange = Color.parseColor("#FF9500")
    private val accentCyan = Color.parseColor("#32D4D4")
    private val accentViolet = Color.parseColor("#AF52DE")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = bgDark
        window.navigationBarColor = bgDark
        supportActionBar?.hide()
        setContentView(buildRoot())
        sdk.listener = this
        log("SDK 已启动")
    }

    override fun onDestroy() { super.onDestroy(); sdk.listener = null }

    // ==================== UI ====================

    private fun buildRoot(): View {
        val scroll = ScrollView(this).apply { setBackgroundColor(bgDark) }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(32))
        }

        // 状态栏
        val statusRow = row()
        statusDot = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(12), dp(12)).apply {
                gravity = Gravity.CENTER_VERTICAL; marginEnd = dp(8)
            }
            background = roundDrawable(Color.GRAY, dp(6))
        }
        statusLabel = TextView(this).apply {
            text = "未连接"; setTextColor(textWhite); textSize = 16f
            layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
        }
        statusRow.addView(statusDot)
        statusRow.addView(statusLabel)
        statusRow.addView(pillBtn("扫描", accentBlue) { requestPermsAndScan() })
        statusRow.addView(pillBtn("断开", accentRed) { sdk.disconnect(); log("已断开") })
        root.addView(statusRow)
        root.addView(gap(12))

        // 功能按钮行
        val funcRow = row()
        funcRow.addView(pillBtn("设备信息", accentPink) { queryDeviceInfo() })
        funcRow.addView(pillBtn("同步时间", accentPurple) { syncTime() })
        funcRow.addView(pillBtn("闹钟管理", accentPurple) { startActivity(android.content.Intent(this, AlarmManagerActivity::class.java)) })
        root.addView(funcRow)
        root.addView(gap(16))

        // 铃声
        root.addView(segmentRow("铃声", listOf(
            "A" to { sdk.setSoundType(SoundType.TYPE_A) { logR("铃声A", it) } },
            "B" to { sdk.setSoundType(SoundType.TYPE_B) { logR("铃声B", it) } },
            "C" to { sdk.setSoundType(SoundType.TYPE_C) { logR("铃声C", it) } }
        )))
        root.addView(gap(8))

        // 音量
        root.addView(segmentRow("音量", listOf(
            "低" to { sdk.setVolume(VolumeLevel.LOW) { logR("音量低", it) } },
            "中" to { sdk.setVolume(VolumeLevel.MEDIUM) { logR("音量中", it) } },
            "高" to { sdk.setVolume(VolumeLevel.HIGH) { logR("音量高", it) } }
        )))
        root.addView(gap(8))

        // 时制
        root.addView(segmentRow("时制", listOf(
            "12H" to { sdk.setTimeFormat(TimeFormat.HOUR_12) { logR("12H", it) } },
            "24H" to { sdk.setTimeFormat(TimeFormat.HOUR_24) { logR("24H", it) } }
        )))
        root.addView(gap(8))

        // 静音
        val silRow = row()
        silRow.addView(label("静音"))
        val sw = Switch(this).apply {
            setOnCheckedChangeListener { _, on ->
                sdk.setSilence(on) { logR(if (on) "静音开" else "静音关", it) }
            }
        }
        silRow.addView(sw)
        root.addView(silRow)
        root.addView(gap(8))

        // 持续时长
        val durRow = row()
        durRow.addView(label("持续"))
        durationInput = EditText(this).apply {
            setText("5"); inputType = android.text.InputType.TYPE_CLASS_NUMBER
            setTextColor(textWhite); textSize = 14f
            background = roundDrawable(bgSegment, dp(6))
            setPadding(dp(12), dp(8), dp(12), dp(8))
            layoutParams = LinearLayout.LayoutParams(dp(60), WRAP_CONTENT).apply { marginEnd = dp(8) }
        }
        durRow.addView(durationInput)
        durRow.addView(TextView(this).apply {
            text = "分"; setTextColor(textGray); textSize = 14f
            layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply { marginEnd = dp(12) }
        })
        durRow.addView(pillBtn("设置", accentCyan) {
            val m = durationInput.text.toString().toIntOrNull() ?: 5
            sdk.setAlertDuration(m) { logR("持续${m}分", it) }
        })
        root.addView(durRow)
        root.addView(gap(16))

        // 系统操作
        val sysRow = row()
        sysRow.addView(pillBtn("恢复出厂", accentOrange) { sdk.restoreFactory { logR("恢复出厂", it) } })
        sysRow.addView(pillBtn("清除绑定", accentOrange) { sdk.clearBinding { logR("清除绑定", it) } })
        root.addView(sysRow)
        root.addView(gap(8))

        // 用药记录 / 指令验证
        val toolRow = row()
        toolRow.addView(pillBtn("用药记录", accentPink) { startActivity(android.content.Intent(this, MedicationRecordsActivity::class.java)) })
        toolRow.addView(pillBtn("指令验证", accentViolet) { openDebugPanel() })
        root.addView(toolRow)
        root.addView(gap(8))

        // 密钥认证
        val authRow = row()
        authRow.addView(pillBtn("密钥认证", accentCyan) { authenticate() })
        root.addView(authRow)
        root.addView(gap(16))

        // 日志头
        val logHead = row()
        logHead.addView(TextView(this).apply {
            text = "日志"; setTextColor(textWhite); textSize = 14f
            layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
        })
        logHead.addView(pillBtn("清空", bgSegment) { logTextView.text = "" })
        root.addView(logHead)
        root.addView(gap(4))

        // 日志区
        logTextView = TextView(this).apply {
            setTextColor(Color.parseColor("#4AF626")); textSize = 11f
            typeface = Typeface.MONOSPACE; setBackgroundColor(bgCard)
            setPadding(dp(12), dp(12), dp(12), dp(12))
            movementMethod = ScrollingMovementMethod()
            gravity = Gravity.TOP
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(260))
            background = roundDrawable(bgCard, dp(8))
        }
        root.addView(logTextView)

        scroll.addView(root)
        return scroll
    }

    // ==================== 操作 ====================

    private fun requestPermsAndScan() {
        val perms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        ActivityCompat.requestPermissions(this, perms, 100)
        startScan()
    }

    private fun startScan() {
        log("扫描中...")
        sdk.startScan(timeoutMs = 10000L) { event ->
            when (event) {
                is com.blue.sdk.model.ScanEvent.DeviceFound -> {
                    log("📡 ${event.device.deviceName} RSSI:${event.device.rssi}")
                    sdk.connect(event.device)
                    sdk.stopScan()
                }
                is com.blue.sdk.model.ScanEvent.Error -> log("❌ ${event.error.message}")
                is com.blue.sdk.model.ScanEvent.Stopped -> log("⏹ 扫描已停止")
            }
        }
    }

    private fun authenticate() {
        val p = byteArrayOf(0xC7.toByte(), 0x50, 0xB2.toByte(), 0xAA.toByte(), 0xC3.toByte(), 0xF3.toByte())
        val d = byteArrayOf(0xA6.toByte(), 0xC0.toByte(), 0x82.toByte(), 0x00, 0xA1.toByte(), 0xC2.toByte())
        sdk.authenticate(p, d) { it.fold({ log("✅ 认证成功") }, { log("❌ ${(it as BlueError).message}") }) }
    }

    private fun queryDeviceInfo() {
        sdk.queryDeviceInfo { it.fold({ log("✅ 固件：${it.firmwareVersion}") }, { log("❌ ${(it as BlueError).message}") }) }
    }

    private fun syncTime() {
        sdk.syncTime { it.fold({ log("✅ 时间已同步") }, { log("❌ ${(it as BlueError).message}") }) }
    }

    private fun openDebugPanel() {
        startActivity(android.content.Intent(this, ProtocolTestActivity::class.java))
    }

    private fun <T> logR(a: String, r: Result<T>) {
        r.fold({ log("✅ $a") }, { log("❌ $a：${(it as BlueError).message}") })
    }

    // ==================== Listener ====================

    override fun onConnectionStateChanged(state: ConnectionState) {
        val (t, c) = when (state) {
            ConnectionState.DISCONNECTED -> "未连接" to Color.GRAY
            ConnectionState.CONNECTING -> "连接中..." to Color.YELLOW
            ConnectionState.CONNECTED -> "已连接" to Color.CYAN
            ConnectionState.AUTHENTICATED -> "已认证" to Color.GREEN
            ConnectionState.RECONNECTING -> "重连中..." to Color.YELLOW
        }
        runOnUiThread { statusLabel.text = t; statusDot.background = roundDrawable(c, dp(6)) }
        log("🔗 $t")
    }

    override fun onAuthResult(success: Boolean, error: BlueError?) { log(if (success) "🔐 成功" else "🔐 失败") }
    override fun onTimeSyncRequested() { log("⏰ 同步请求"); sdk.syncTime { _ -> } }
    override fun onAlarmUpdated(alarm: AlarmInfo) { log("⏰ 闹钟${alarm.index}变更") }
    override fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) { log("🔔 响铃！") }
    override fun onAlarmTimeout(alarmIndex: Int, alarmInfo: AlarmInfo) { log("⚠️ 超时！") }
    override fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {
        log("💊 $status")
        val statusInt = when (status) {
            MedicationStatus.TAKEN -> 1; MedicationStatus.TIMEOUT -> 2
            MedicationStatus.MISSED -> 3; MedicationStatus.EARLY -> 4
        }
        MedicationDatabase.getInstance(this).insert(System.currentTimeMillis(), alarmIndex, statusInt)
    }
    override fun onMedicationRecordReported(record: MedicationRecord) {
        log("📋 ${record.status}")
        val statusInt = when (record.status) {
            MedicationStatus.TAKEN -> 1; MedicationStatus.TIMEOUT -> 2
            MedicationStatus.MISSED -> 3; MedicationStatus.EARLY -> 4
        }
        MedicationDatabase.getInstance(this).insert(record.timestamp, record.alarmIndex, statusInt)
    }
    override fun onSoundTypeChanged(type: SoundType) { log("🔊 $type") }
    override fun onTimeFormatChanged(format: TimeFormat) { log("🕐 $format") }
    override fun onLowBattery() { log("🪫 低电量") }
    override fun onDeviceUnbound() { log("🔓 解绑") }

    // ==================== 日志 ====================

    private fun log(msg: String) {
        val t = timeFmt.format(Date())
        runOnUiThread { logTextView.append("[$t] $msg\n") }
    }

    // ==================== UI 工具 ====================

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    private fun row() = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
        gravity = Gravity.CENTER_VERTICAL
    }

    private fun gap(dpVal: Int) = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(dpVal))
    }

    private fun label(text: String) = TextView(this).apply {
        this.text = text; setTextColor(textWhite); textSize = 14f
        layoutParams = LinearLayout.LayoutParams(dp(48), WRAP_CONTENT)
    }

    private fun roundDrawable(color: Int, radius: Int): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radius.toFloat()
            setColor(color)
        }
    }

    private fun pillBtn(text: String, bgColor: Int, onClick: () -> Unit): Button {
        return Button(this).apply {
            this.text = text; setTextColor(textWhite); isAllCaps = false; textSize = 13f
            background = roundDrawable(bgColor, dp(8))
            setPadding(dp(12), dp(6), dp(12), dp(6))
            layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f).apply { marginEnd = dp(6) }
            setOnClickListener { onClick() }
        }
    }

    private fun segmentRow(labelText: String, options: List<Pair<String, () -> Unit>>): LinearLayout {
        val r = row()
        r.addView(label(labelText))
        val seg = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            background = roundDrawable(bgSegment, dp(8))
            layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
            setPadding(dp(2), dp(2), dp(2), dp(2))
        }
        options.forEach { (t, action) ->
            seg.addView(Button(this).apply {
                this.text = t; setTextColor(textWhite); isAllCaps = false; textSize = 13f
                background = roundDrawable(Color.TRANSPARENT, dp(6))
                layoutParams = LinearLayout.LayoutParams(0, dp(36), 1f)
                setOnClickListener {
                    // 高亮当前选中
                    (parent as LinearLayout).children().forEach { (it as Button).background = roundDrawable(Color.TRANSPARENT, dp(6)) }
                    background = roundDrawable(Color.parseColor("#636366"), dp(6))
                    action()
                }
            })
        }
        r.addView(seg)
        return r
    }

    private fun LinearLayout.children(): List<View> = (0 until childCount).map { getChildAt(it) }
}
