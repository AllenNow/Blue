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
    private lateinit var loadingOverlay: FrameLayout

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
            text = S.notConnected
            setTextColor(textWhite)
            textSize = 16f
            layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
        }

        scanButton = pillBtn(S.scan, accentBlue) {
            if (isScanning) {
                stopScan()
            } else {
                requestPermsAndScan()
            }
        }
        disconnectButton = pillBtn(S.disconnect, accentRed) { sdk.disconnect(); log(S.disconnected) }.apply { visibility = View.GONE }

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
        funcRow.addView(pillBtn(S.deviceInfo, accentPink) { queryDeviceInfo() })
        funcRow.addView(pillBtn(S.syncTime, accentPurple) { syncTime() })
        funcRow.addView(pillBtn(S.alarmManager, accentPurple) { startActivity(android.content.Intent(this, AlarmManagerActivity::class.java)) })
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
            text = S.minutes
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
        toolRow.addView(pillBtn(S.medicationRecords, accentPink) { startActivity(android.content.Intent(this, MedicationRecordsActivity::class.java)) })
        toolRow.addView(pillBtn(S.protocolTest, accentViolet) { openDebugPanel() })
        toolRow.addView(pillBtn(S.faq, Color.parseColor("#30D158")) { startActivity(android.content.Intent(this, FAQActivity::class.java)) })
        content.addView(toolRow)

        content.addView(gap(8))

        val sysRow2 = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        sysRow2.addView(pillBtn(S.clearAlarms, accentCyan) { clearAllAlarms() })
        sysRow2.addView(pillBtn(S.restoreFactory, accentOrange) { restoreFactory() })
        sysRow2.addView(pillBtn(S.clearBinding, accentOrange) { clearLocalBinding() })
        content.addView(sysRow2)

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
            text = S.log
            setTextColor(textWhite)
            textSize = 14f
            layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
        })
        logHead.addView(pillBtn(S.clear, bgSegment) { logTextView.text = "" })
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

        // Loading 遮罩（连接认证中显示）
        loadingOverlay = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#66000000"))
            visibility = View.GONE
            layoutParams = FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT)
            setOnClickListener { /* 拦截点击 */ }

            val card = LinearLayout(this@MainActivity).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                background = roundDrawable(bgCard, dp(12))
                setPadding(dp(24), dp(20), dp(24), dp(20))
                layoutParams = FrameLayout.LayoutParams(dp(200), WRAP_CONTENT).apply {
                    gravity = Gravity.CENTER
                }
            }
            card.addView(ProgressBar(this@MainActivity).apply {
                layoutParams = LinearLayout.LayoutParams(dp(36), dp(36)).apply { bottomMargin = dp(12) }
            })
            card.addView(TextView(this@MainActivity).apply {
                text = S.connectingAuth
                setTextColor(textWhite); textSize = 15f; gravity = Gravity.CENTER
                tag = "loading_label"
            })
            card.addView(Button(this@MainActivity).apply {
                text = S.cancel; setTextColor(accentRed); isAllCaps = false; textSize = 14f
                background = null
                layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply { topMargin = dp(8) }
                setOnClickListener { cancelConnection() }
            })
            addView(card)
        }

        // 包裹为 FrameLayout 以叠加 loading
        val frame = FrameLayout(this).apply {
            layoutParams = ViewGroup.LayoutParams(MATCH_PARENT, MATCH_PARENT)
        }
        frame.addView(root)
        frame.addView(loadingOverlay)

        return frame
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
        isAuthFailed = false
        scanButton.text = S.stopScan
        scanButton.isEnabled = true
        log(S.scanningAuto)
        showLoading(S.scanConnecting)
        updateStatus(S.scanning, Color.parseColor("#FF9500"))

        sdk.startScan(timeoutMs = 10000L) { event ->
            when (event) {
                is com.blue.sdk.model.ScanEvent.DeviceFound -> {
                    log("${S.found} ${event.device.deviceName}")
                    showLoading(S.connectingAuth)
                    updateStatus(S.connectingAuth, Color.YELLOW)
                    sdk.connect(event.device)
                    sdk.stopScan()
                    resetScanButton()
                }
                is com.blue.sdk.model.ScanEvent.Error -> {
                    log("❌ ${event.error.message}")
                    updateStatus(S.scanFailed, Color.RED)
                    hideLoading()
                    resetScanButton()
                }
                is com.blue.sdk.model.ScanEvent.Stopped -> {
                    log("⏹ ${S.scanStopped}")
                    hideLoading()
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
        scanButton.text = S.scan
    }

    private fun queryDeviceInfo() {
        log("📱 查询设备信息...")
        sdk.queryDeviceInfo { it.fold(
            { log("📱 MAC:${it.macAddress} v${it.firmwareVersion}") },
            { log("❌ ${(it as BlueError).message}") }
        )}
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
        confirm(S.clearAlarmsTitle, S.clearAlarmsMsg) {
            sdk.clearAllAlarms { it.fold({ log("⏰ ${S.alarmsCleared}") }, { log("❌ ${(it as BlueError).message}") }) }
        }
    }

    private fun restoreFactory() {
        if (sdk.connectionState != ConnectionState.AUTHENTICATED) {
            log("❌ 请先连接设备")
            return
        }
        confirm(S.restoreFactoryTitle, S.restoreFactoryMsg) {
            log("🔄 ${S.restoringFactory}")
            sdk.restoreFactory { it.fold({ log("✅ ${S.factoryRestored}") }, { log("❌ ${(it as BlueError).message}") }) }
        }
    }

    private fun clearLocalBinding() {
        confirm(S.clearBindingTitle, S.clearBindingMsg) {
            sdk.clearBinding()
            log("✅ ${S.bindingCleared}")
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

    private fun showLoading(text: String = "连接认证中...") {
        runOnUiThread {
            loadingOverlay.findViewWithTag<TextView>("loading_label")?.text = text
            loadingOverlay.visibility = View.VISIBLE
        }
    }

    private fun hideLoading() {
        runOnUiThread { loadingOverlay.visibility = View.GONE }
    }

    private fun cancelConnection() {
        sdk.stopScan()
        sdk.disconnect()
        hideLoading()
        resetScanButton()
        updateStatus(S.notConnected, Color.GRAY)
        runOnUiThread {
            scanButton.visibility = View.VISIBLE
            scanButton.isEnabled = true
        }
        log("用户取消连接")
    }

    override fun onConnectionStateChanged(state: ConnectionState) {
        val (text, color) = when (state) {
            ConnectionState.DISCONNECTED -> S.notConnected to Color.GRAY
            ConnectionState.CONNECTING -> S.connecting to Color.parseColor("#FF9500")
            ConnectionState.CONNECTED -> S.authenticating to Color.YELLOW
            ConnectionState.AUTHENTICATED -> S.connected to Color.GREEN
            ConnectionState.RECONNECTING -> S.reconnecting to Color.parseColor("#FF9500")
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
                    hideLoading()
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
            hideLoading()
            runOnUiThread {
                statusLabel.text = if (S.isZh) "认证失败" else "Auth Failed"
                statusDot.background = roundDrawable(Color.RED, dp(6))
                scanButton.visibility = View.VISIBLE
                disconnectButton.visibility = View.GONE
                scanButton.isEnabled = true
                AlertDialog.Builder(this)
                    .setTitle(S.authFailedTitle)
                    .setMessage(S.authFailedMsg)
                    .setPositiveButton(S.confirm, null)
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
        // onMedicationResult 不携带闹钟设定时间，用 0 填充
        MedicationDatabase.getInstance(this).insert(System.currentTimeMillis(), alarmIndex, 0, 0, statusInt)
    }

    override fun onMedicationRecordReported(record: MedicationRecord) {
        log("📋 用药记录已保存")
        val statusInt = when (record.status) {
            MedicationStatus.TAKEN -> 1; MedicationStatus.TIMEOUT -> 2
            MedicationStatus.MISSED -> 3; MedicationStatus.EARLY -> 4
        }
        MedicationDatabase.getInstance(this).insert(record.timestamp, record.alarmIndex, record.alarmHour, record.alarmMinute, statusInt)
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
