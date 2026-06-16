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
import android.view.ViewGroup
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.*
import androidx.appcompat.app.AlertDialog
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
    private lateinit var scanButton: Button
    private lateinit var disconnectButton: Button

    private var isScanning = false

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

    private var isAuthFailed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = bgDark
        window.navigationBarColor = bgDark
        supportActionBar?.hide()
        setContentView(buildRoot())
        sdk.initialize()
        sdk.listener = this
        sdk.setLogHandler { level, tag, message ->
            val prefix = when (level) {
                LogLevel.DEBUG -> "📋"
                LogLevel.INFO -> "ℹ️"
                LogLevel.WARN -> "⚠️"
                LogLevel.ERROR -> "❌"
                else -> ""
            }
            log("$prefix $message")
        }
        log("SDK 已启动")
    }

    override fun onDestroy() {
        super.onDestroy()
        sdk.listener = null
        sdk.setLogHandler(null)
    }

    private fun buildRoot(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(bgDark)
            layoutParams = ViewGroup.LayoutParams(MATCH_PARENT, MATCH_PARENT)
        }

        val scrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f)
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))
        }

        val connCard = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(bgCard)
            background = roundDrawable(bgCard, dp(12))
            setPadding(dp(16), dp(16), dp(16), dp(16))
        }

        statusDot = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(12), dp(12)).apply { marginEnd = dp(12) }
            background = roundDrawable(Color.GRAY, dp(6))
        }

        statusLabel = TextView(this).apply {
            text = "未连接"
            setTextColor(textWhite)
            textSize = 16f
            layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
        }

        scanButton = pillBtn("扫描", accentBlue) {
            if (isScanning) {
                stopScan()
            } else {
                requestPermsAndScan()
            }
        }
        disconnectButton = pillBtn("断开", accentRed) { sdk.disconnect(); log("已断开") }.apply { visibility = View.GONE }

        connCard.addView(statusDot)
        connCard.addView(statusLabel)
        connCard.addView(scanButton)
        connCard.addView(disconnectButton)
        content.addView(connCard)

        content.addView(gap(16))

        val funcRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        funcRow.addView(pillBtn("设备信息", accentPink) { queryDeviceInfo() })
        funcRow.addView(pillBtn("同步时间", accentPurple) { syncTime() })
        funcRow.addView(pillBtn("闹钟管理", accentPurple) { startActivity(android.content.Intent(this, AlarmManagerActivity::class.java)) })
        content.addView(funcRow)

        content.addView(gap(16))

        val audioCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(bgCard)
            background = roundDrawable(bgCard, dp(12))
            setPadding(dp(16), dp(16), dp(16), dp(16))
        }

        audioCard.addView(segmentRow("铃声", listOf(
            "A" to { sdk.setSoundType(SoundType.TYPE_A) { logR("铃声A", it) } },
            "B" to { sdk.setSoundType(SoundType.TYPE_B) { logR("铃声B", it) } },
            "C" to { sdk.setSoundType(SoundType.TYPE_C) { logR("铃声C", it) } }
        )))
        audioCard.addView(gap(12))

        audioCard.addView(segmentRow("音量", listOf(
            "低" to { sdk.setVolume(VolumeLevel.LOW) { logR("音量低", it) } },
            "中" to { sdk.setVolume(VolumeLevel.MEDIUM) { logR("音量中", it) } },
            "高" to { sdk.setVolume(VolumeLevel.HIGH) { logR("音量高", it) } }
        )))
        audioCard.addView(gap(12))

        audioCard.addView(segmentRow("时制", listOf(
            "12H" to { sdk.setTimeFormat(TimeFormat.HOUR_12) { logR("12H", it) } },
            "24H" to { sdk.setTimeFormat(TimeFormat.HOUR_24) { logR("24H", it) } }
        )))
        audioCard.addView(gap(12))

        val silRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        silRow.addView(label("静音"))
        val sw = Switch(this).apply {
            setOnCheckedChangeListener { _, on ->
                sdk.setSilence(on) { logR(if (on) "静音开" else "静音关", it) }
            }
        }
        silRow.addView(sw)
        audioCard.addView(silRow)
        audioCard.addView(gap(12))

        val durRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        durRow.addView(label("持续"))
        durationInput = EditText(this).apply {
            setText("5")
            inputType = android.text.InputType.TYPE_CLASS_NUMBER
            setTextColor(textWhite)
            textSize = 14f
            background = roundDrawable(bgSegment, dp(6))
            setPadding(dp(12), dp(8), dp(12), dp(8))
            layoutParams = LinearLayout.LayoutParams(dp(60), WRAP_CONTENT).apply { marginEnd = dp(8) }
        }
        durRow.addView(durationInput)
        durRow.addView(TextView(this).apply {
            text = "分"
            setTextColor(textGray)
            textSize = 14f
            layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply { marginEnd = dp(12) }
        })
        durRow.addView(pillBtn("设置", accentCyan) {
            val m = durationInput.text.toString().toIntOrNull() ?: 5
            sdk.setAlertDuration(m) { logR("持续${m}分", it) }
        })
        audioCard.addView(durRow)
        content.addView(audioCard)

        content.addView(gap(16))

        val toolRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        toolRow.addView(pillBtn("用药记录", accentPink) { startActivity(android.content.Intent(this, MedicationRecordsActivity::class.java)) })
        toolRow.addView(pillBtn("指令验证", accentViolet) { openDebugPanel() })
        toolRow.addView(pillBtn("清空闹钟", accentCyan) { clearAllAlarms() })
        content.addView(toolRow)

        content.addView(gap(8))

        val sysRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        sysRow.addView(pillBtn("恢复出厂", accentOrange) { restoreFactory() })
        sysRow.addView(pillBtn("清除绑定", accentOrange) { clearLocalBinding() })
        content.addView(sysRow)

        content.addView(gap(16))

        val logCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(bgCard)
            background = roundDrawable(bgCard, dp(12))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(200))
        }

        val logHead = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(12), dp(12), dp(8))
        }
        logHead.addView(TextView(this).apply {
            text = "日志"
            setTextColor(textWhite)
            textSize = 14f
            layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
        })
        logHead.addView(pillBtn("清空", bgSegment) { logTextView.text = "" })
        logCard.addView(logHead)

        logTextView = TextView(this).apply {
            setTextColor(textWhite)
            textSize = 10f
            typeface = Typeface.MONOSPACE
            setBackgroundColor(bgDark)
            setPadding(dp(12), dp(8), dp(12), dp(12))
            movementMethod = ScrollingMovementMethod()
            gravity = Gravity.TOP
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f)
        }
        logCard.addView(logTextView)
        content.addView(logCard)

        scrollView.addView(content)
        root.addView(scrollView)

        return root
    }

    private fun requestPermsAndScan() {
        val perms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        ActivityCompat.requestPermissions(this, perms, 100)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 100) {
            val allGranted = grantResults.all { it == android.content.pm.PackageManager.PERMISSION_GRANTED }
            if (allGranted) {
                startScan()
            } else {
                log("❌ 权限未授予")
                scanButton.isEnabled = true
            }
        }
    }

    private fun startScan() {
        isScanning = true
        scanButton.text = "停止扫描"
        scanButton.isEnabled = true
        log("扫描中...（自动密钥）")
        updateStatus("扫描中...", Color.parseColor("#FF9500"))

        sdk.startScan(timeoutMs = 10000L) { event ->
            when (event) {
                is com.blue.sdk.model.ScanEvent.DeviceFound -> {
                    log("发现 ${event.device.deviceName}")
                    updateStatus("连接认证中...", Color.YELLOW)
                    sdk.connect(event.device)
                    sdk.stopScan()
                    resetScanButton()
                }
                is com.blue.sdk.model.ScanEvent.Error -> {
                    log("❌ ${event.error.message}")
                    updateStatus("扫描失败", Color.RED)
                    resetScanButton()
                }
                is com.blue.sdk.model.ScanEvent.Stopped -> {
                    log("⏹ 扫描已停止")
                    resetScanButton()
                }
            }
        }
    }

    private fun stopScan() {
        sdk.stopScan()
    }

    private fun resetScanButton() {
        isScanning = false
        scanButton.text = "扫描"
    }

    private fun queryDeviceInfo() {
        if (sdk.connectionState != ConnectionState.AUTHENTICATED) {
            log("❌ 请先连接设备")
            return
        }
        log("📱 查询设备信息...")
        sdk.queryDeviceInfo { it.fold({ log("📱 v${it.firmwareVersion}") }, { log("❌ ${(it as BlueError).message}") }) }
    }

    private fun syncTime() {
        if (sdk.connectionState != ConnectionState.AUTHENTICATED) {
            log("❌ 请先连接设备")
            return
        }
        log("⏰ 同步时间...")
        sdk.syncTime { it.fold({ log("⏰ 时间已同步") }, { log("❌ ${(it as BlueError).message}") }) }
    }

    private fun clearAllAlarms() {
        if (sdk.connectionState != ConnectionState.AUTHENTICATED) {
            log("❌ 请先连接设备")
            return
        }
        confirm("清空闹钟", "确定清空所有闹钟？") {
            sdk.clearAllAlarms { it.fold({ log("⏰ 所有闹钟已清空") }, { log("❌ ${(it as BlueError).message}") }) }
        }
    }

    private fun restoreFactory() {
        if (sdk.connectionState != ConnectionState.AUTHENTICATED) {
            log("❌ 请先连接设备")
            return
        }
        confirm("恢复出厂", "确定恢复出厂设置？") {
            log("🔄 恢复出厂中...")
            sdk.restoreFactory { it.fold({ log("✅ 已恢复出厂") }, { log("❌ ${(it as BlueError).message}") }) }
        }
    }

    private fun clearLocalBinding() {
        confirm("清除绑定", "清除本地密钥，设备也需恢复出厂。") {
            sdk.clearBinding()
            log("✅ 本地绑定已清除")
        }
    }

    private fun openDebugPanel() {
        startActivity(android.content.Intent(this, ProtocolTestActivity::class.java))
    }

    private fun <T> logR(a: String, r: Result<T>) {
        r.fold({ log("✅ $a") }, { log("❌ $a：${(it as BlueError).message}") })
    }

    private fun confirm(title: String, msg: String, action: () -> Unit) {
        AlertDialog.Builder(this)
            .setTitle(title)
            .setMessage(msg)
            .setNegativeButton("取消", null)
            .setPositiveButton("确定") { _, _ -> action() }
            .show()
    }

    private fun updateStatus(text: String, color: Int) {
        runOnUiThread {
            statusLabel.text = text
            statusDot.background = roundDrawable(color, dp(6))
        }
    }

    override fun onConnectionStateChanged(state: ConnectionState) {
        val (text, color) = when (state) {
            ConnectionState.DISCONNECTED -> "未连接" to Color.GRAY
            ConnectionState.CONNECTING -> "连接中..." to Color.parseColor("#FF9500")
            ConnectionState.CONNECTED -> "认证中..." to Color.YELLOW
            ConnectionState.AUTHENTICATED -> "已连接" to Color.GREEN
            ConnectionState.RECONNECTING -> "重连中..." to Color.parseColor("#FF9500")
        }
        runOnUiThread {
            when (state) {
                ConnectionState.DISCONNECTED -> {
                    scanButton.visibility = View.VISIBLE
                    disconnectButton.visibility = View.GONE
                    if (!isAuthFailed) {
                        updateStatus(text, color)
                        scanButton.isEnabled = true
                    }
                }
                ConnectionState.CONNECTING -> {
                    scanButton.visibility = View.GONE
                    disconnectButton.visibility = View.GONE
                    updateStatus(text, color)
                }
                ConnectionState.CONNECTED -> {
                    scanButton.visibility = View.GONE
                    disconnectButton.visibility = View.GONE
                    updateStatus(text, color)
                }
                ConnectionState.AUTHENTICATED -> {
                    scanButton.visibility = View.GONE
                    disconnectButton.visibility = View.VISIBLE
                    updateStatus(text, color)
                }
                ConnectionState.RECONNECTING -> {
                    scanButton.visibility = View.GONE
                    disconnectButton.visibility = View.GONE
                    updateStatus(text, color)
                }
            }
        }
        log("🔗 $text")
    }

    override fun onAuthResult(success: Boolean, error: BlueError?) {
        if (!success) {
            isAuthFailed = true
            log("🔐 认证失败")
            runOnUiThread {
                statusLabel.text = "认证失败"
                statusDot.background = roundDrawable(Color.RED, dp(6))
                scanButton.visibility = View.VISIBLE
                disconnectButton.visibility = View.GONE
                scanButton.isEnabled = true
                AlertDialog.Builder(this)
                    .setTitle("认证失败")
                    .setMessage("密钥不一致，请对设备长按按键恢复出厂设置后重试。")
                    .setPositiveButton("确定", null)
                    .show()
            }
        }
    }

    override fun onTimeSyncRequested() { log("⏰ 同步请求"); sdk.syncTime { _ -> } }
    override fun onAlarmUpdated(alarm: AlarmInfo) { log("⏰ 闹钟${alarm.index} ${String.format("%02d:%02d", alarm.hour, alarm.minute)}") }
    override fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) { log("🔔 闹钟${alarmIndex}响铃") }
    override fun onAlarmTimeout(alarmIndex: Int, alarmInfo: AlarmInfo) { log("⚠️ 闹钟${alarmIndex}超时") }

    override fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {
        log("💊 闹钟${alarmIndex} $status")
        val statusInt = when (status) {
            MedicationStatus.TAKEN -> 1; MedicationStatus.TIMEOUT -> 2
            MedicationStatus.MISSED -> 3; MedicationStatus.EARLY -> 4
        }
        MedicationDatabase.getInstance(this).insert(System.currentTimeMillis(), alarmIndex, statusInt)
    }

    override fun onMedicationRecordReported(record: MedicationRecord) {
        log("📋 用药记录已保存")
        val statusInt = when (record.status) {
            MedicationStatus.TAKEN -> 1; MedicationStatus.TIMEOUT -> 2
            MedicationStatus.MISSED -> 3; MedicationStatus.EARLY -> 4
        }
        MedicationDatabase.getInstance(this).insert(record.timestamp, record.alarmIndex, statusInt)
    }

    override fun onSoundTypeChanged(type: SoundType) { log("🔊 铃声变更") }
    override fun onTimeFormatChanged(format: TimeFormat) { log("🕐 时制变更") }
    override fun onLowBattery() { log("🪫 低电") }
    override fun onDeviceUnbound() { log("🔓 解绑") }

    private fun log(msg: String) {
        val t = timeFmt.format(Date())
        runOnUiThread {
            if (::logTextView.isInitialized) {
                logTextView.append("[$t] $msg\n")
                logTextView.layout?.let { layout ->
                    logTextView.scrollTo(0, layout.getLineTop(logTextView.lineCount - 1))
                }
            }
        }
    }

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    private fun gap(dpVal: Int) = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(dpVal))
    }

    private fun label(text: String) = TextView(this).apply {
        this.text = text
        setTextColor(textWhite)
        textSize = 14f
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
            this.text = text
            setTextColor(textWhite)
            isAllCaps = false
            textSize = 13f
            background = roundDrawable(bgColor, dp(8))
            setPadding(dp(12), dp(6), dp(12), dp(6))
            layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f).apply { marginEnd = dp(6) }
            setOnClickListener { onClick() }
        }
    }

    private fun segmentRow(labelText: String, options: List<Pair<String, () -> Unit>>): LinearLayout {
        val r = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        r.addView(label(labelText))
        val seg = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            background = roundDrawable(bgSegment, dp(8))
            layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
            setPadding(dp(2), dp(2), dp(2), dp(2))
        }
        options.forEach { (t, action) ->
            seg.addView(Button(this).apply {
                this.text = t
                setTextColor(textWhite)
                isAllCaps = false
                textSize = 13f
                background = roundDrawable(Color.TRANSPARENT, dp(6))
                layoutParams = LinearLayout.LayoutParams(0, dp(36), 1f)
                setOnClickListener {
                    (parent as? LinearLayout)?.children()?.forEach {
                        if (it is Button) {
                            it.background = roundDrawable(Color.TRANSPARENT, dp(6))
                        }
                    }
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
