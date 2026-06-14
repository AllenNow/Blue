// MainActivity.kt
// BlueSDK Android Demo - 紧凑单页布局主页
// 对齐 iOS 版本 ViewController.swift 的所有功能

package com.blue.demo

import android.Manifest
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import com.blue.sdk.BlueSDK
import com.blue.sdk.BlueSDKListener
import com.blue.sdk.enums.*
import com.blue.sdk.error.BlueError
import com.blue.sdk.model.AlarmInfo
import com.blue.sdk.model.MedicationRecord
import com.blue.sdk.model.ScannedDevice
import java.text.SimpleDateFormat
import java.util.*

class MainActivity : AppCompatActivity(), BlueSDKListener {

    // MARK: - UI 组件
    private lateinit var statusDot: View
    private lateinit var statusLabel: TextView
    private lateinit var authKeyEditText: EditText
    private lateinit var scanButton: Button
    private lateinit var disconnectButton: Button
    private lateinit var logTextView: TextView
    private lateinit var logScrollView: ScrollView
    private lateinit var silenceSwitch: Switch
    private lateinit var durationEditText: EditText

    // MARK: - Loading 遮罩
    private lateinit var loadingOverlay: FrameLayout
    private lateinit var loadingLabel: TextView

    // MARK: - 状态
    private val sdk get() = BlueSDK.getInstance(this)
    private val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
    private var scannedDevices = mutableListOf<ScannedDevice>()
    private var previousConnectionState: ConnectionState = ConnectionState.DISCONNECTED

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = "BlueSDK"
        buildUI()
        sdk.listener = this
        // 将 SDK 内部日志转发到界面日志窗口
        sdk.setLogHandler { level, tag, message ->
            val prefix = when (level) {
                LogLevel.DEBUG -> "📋"
                LogLevel.INFO -> "ℹ️"
                LogLevel.WARN -> "⚠️"
                LogLevel.ERROR -> "❌"
                LogLevel.NONE -> ""
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

    // MARK: - UI 构建

    private fun buildUI() {
        val rootScroll = ScrollView(this).apply {
            layoutParams = ViewGroup.LayoutParams(-1, -1)
        }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(12), dp(12), dp(12))
        }
        rootScroll.addView(content)

        // 1. 连接状态卡片
        val connCard = makeCard()
        val connRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(14), dp(10), dp(14), dp(10))
        }

        statusDot = View(this).apply {
            val size = dp(10)
            layoutParams = LinearLayout.LayoutParams(size, size)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.GRAY)
            }
        }
        connRow.addView(statusDot)

        statusLabel = TextView(this).apply {
            text = "未连接"
            textSize = 14f
            setPadding(dp(8), 0, 0, 0)
            layoutParams = LinearLayout.LayoutParams(0, -2, 1f)
        }
        connRow.addView(statusLabel)

        scanButton = makeCompactButton("扫描", 0xFF2196F3.toInt()) { startScan() }
        connRow.addView(scanButton)

        disconnectButton = makeCompactButton("断开", 0xFFF44336.toInt()) { disconnect() }
        disconnectButton.apply { setPadding(dp(10), dp(6), dp(10), dp(6)) }
        connRow.addView(disconnectButton)

        connCard.addView(connRow)

        // 密钥输入框行
        val keyRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(14), dp(0), dp(14), dp(10))
        }
        keyRow.addView(makeSmallLabel("密钥").apply {
            layoutParams = LinearLayout.LayoutParams(-2, -2)
        })
        authKeyEditText = EditText(this).apply {
            hint = "密钥如05FA，留空自动"
            textSize = 13f
            inputType = android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
            layoutParams = LinearLayout.LayoutParams(0, -2, 1f).apply {
                marginStart = dp(8)
            }
            setPadding(dp(8), dp(6), dp(8), dp(6))
        }
        keyRow.addView(authKeyEditText)
        connCard.addView(keyRow)

        content.addView(connCard, marginParams(bottom = dp(8)))

        // 2. 快捷操作行
        content.addView(makeButtonRow(listOf(
            Triple("设备信息", 0xFF3F51B5.toInt()) { queryDeviceInfo() },
            Triple("同步时间", 0xFF3F51B5.toInt()) { syncTime() },
            Triple("闹钟管理", 0xFF3F51B5.toInt()) { showAlarmManager() }
        )), marginParams(bottom = dp(8)))

        // 3. 音频设置卡片
        val audioCard = makeCard()
        val audioStack = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(10), dp(10), dp(10), dp(10))
        }

        // 铃声 - 分段按钮
        val soundGroup = makeSegmentGroup(listOf("A", "B", "C"), 0) { pos ->
            val type = arrayOf(SoundType.TYPE_A, SoundType.TYPE_B, SoundType.TYPE_C)[pos]
            sdk.setSoundType(type) { r -> logResult("设置铃声", r) }
        }
        audioStack.addView(makeLabeledRow("铃声", soundGroup))

        // 音量 - 分段按钮
        val volumeGroup = makeSegmentGroup(listOf("低", "中", "高"), 1) { pos ->
            val level = arrayOf(VolumeLevel.LOW, VolumeLevel.MEDIUM, VolumeLevel.HIGH)[pos]
            sdk.setVolume(level) { r -> logResult("设置音量", r) }
        }
        audioStack.addView(makeLabeledRow("音量", volumeGroup))

        // 时制 - 分段按钮
        val timeGroup = makeSegmentGroup(listOf("12H", "24H"), 1) { pos ->
            val fmt = if (pos == 0) TimeFormat.HOUR_12 else TimeFormat.HOUR_24
            sdk.setTimeFormat(fmt) { r -> logResult("设置时制", r) }
        }
        audioStack.addView(makeLabeledRow("时制", timeGroup))

        // 静音
        silenceSwitch = Switch(this)
        silenceSwitch.setOnCheckedChangeListener { _, isChecked ->
            sdk.setSilence(isChecked) { r -> logResult(if (isChecked) "静音开" else "静音关", r) }
        }
        audioStack.addView(makeLabeledRow("静音", silenceSwitch))

        // 持续时间
        val durRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        durRow.addView(makeSmallLabel("持续"))
        durationEditText = EditText(this).apply {
            setText("5")
            textSize = 14f
            inputType = android.text.InputType.TYPE_CLASS_NUMBER
            layoutParams = LinearLayout.LayoutParams(dp(44), -2)
            gravity = Gravity.CENTER
        }
        durRow.addView(durationEditText)
        durRow.addView(makeSmallLabel("分"))
        durRow.addView(makeCompactButton("设置", 0xFF009688.toInt()) {
            val mins = durationEditText.text.toString().toIntOrNull() ?: return@makeCompactButton
            if (mins > 0) sdk.setAlertDuration(mins) { r -> logResult("持续时间${mins}分", r) }
        })
        audioStack.addView(durRow)

        audioCard.addView(audioStack)
        content.addView(audioCard, marginParams(bottom = dp(8)))

        // 4. 工具入口
        content.addView(makeButtonRow(listOf(
            Triple("用药记录", 0xFFFF9800.toInt()) { showRecords() },
            Triple("指令验证", 0xFF9C27B0.toInt()) { showProtocolTest() }
        )), marginParams(bottom = dp(8)))

        // 5. 系统
        content.addView(makeButtonRow(listOf(
            Triple("恢复出厂", 0xFFF44336.toInt()) { restoreFactory() },
            Triple("清除绑定", 0xFFF44336.toInt()) { clearLocalBinding() }
        )), marginParams(bottom = dp(8)))

        // 旧密钥认证（临时）
        content.addView(makeButtonRow(listOf(
            Triple("旧密钥认证(05FA)", 0xFF795548.toInt()) { authWithOldKey() }
        )), marginParams(bottom = dp(8)))

        // 6. 日志
        val logHeader = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        logHeader.addView(makeSmallLabel("日志").apply {
            layoutParams = LinearLayout.LayoutParams(0, -2, 1f)
        })
        logHeader.addView(makeCompactButton("清空", Color.GRAY) { logTextView.text = "" })
        content.addView(logHeader, marginParams(bottom = dp(4)))

        logTextView = TextView(this).apply {
            textSize = 10f
            setTextColor(resolveThemeColor(android.R.attr.textColorPrimary))
            setBackgroundColor(resolveThemeColor(android.R.attr.colorButtonNormal))
            setPadding(dp(8), dp(8), dp(8), dp(8))
            typeface = android.graphics.Typeface.MONOSPACE
        }
        logScrollView = ScrollView(this).apply {
            addView(logTextView)
        }
        content.addView(logScrollView, LinearLayout.LayoutParams(-1, dp(150)))

        // 全屏 Loading 遮罩
        val rootFrame = FrameLayout(this)
        rootFrame.addView(rootScroll, FrameLayout.LayoutParams(-1, -1))

        loadingOverlay = FrameLayout(this).apply {
            setBackgroundColor(0x66000000)
            visibility = View.GONE
        }
        val loadingContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(0xFFFFFFFF.toInt())
            setPadding(dp(24), dp(20), dp(24), dp(12))
            val params = FrameLayout.LayoutParams(dp(200), dp(180))
            params.gravity = Gravity.CENTER
            layoutParams = params
        }
        loadingContainer.addView(ProgressBar(this).apply {
            layoutParams = LinearLayout.LayoutParams(-2, -2).apply { gravity = Gravity.CENTER_HORIZONTAL }
        })
        loadingLabel = TextView(this).apply {
            text = "连接认证中..."
            textSize = 15f
            gravity = Gravity.CENTER
            setPadding(0, dp(12), 0, dp(12))
        }
        loadingContainer.addView(loadingLabel)
        loadingContainer.addView(makeCompactButton("取消", 0xFFF44336.toInt()) { cancelConnection() }.apply {
            layoutParams = LinearLayout.LayoutParams(-2, -2).apply { gravity = Gravity.CENTER_HORIZONTAL }
        })
        loadingOverlay.addView(loadingContainer)
        // 点击外部取消
        loadingOverlay.setOnClickListener { /* 消费点击事件 */ }
        rootFrame.addView(loadingOverlay, FrameLayout.LayoutParams(-1, -1))

        setContentView(rootFrame)
    }

    // MARK: - UI 工具方法

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    /** 创建分段按钮组（模拟 iOS UISegmentedControl） */
    private fun makeSegmentGroup(items: List<String>, defaultIndex: Int, onSelect: (Int) -> Unit): LinearLayout {
        val group = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            val bgColor = resolveThemeColor(android.R.attr.colorButtonNormal)
            background = GradientDrawable().apply {
                setColor(bgColor)
                cornerRadius = dp(6).toFloat()
            }
            setPadding(dp(2), dp(2), dp(2), dp(2))
        }
        val buttons = mutableListOf<TextView>()
        var initialized = false

        items.forEachIndexed { index, title ->
            val btn = TextView(this).apply {
                text = title
                textSize = 13f
                gravity = Gravity.CENTER
                setPadding(dp(12), dp(8), dp(12), dp(8))
                layoutParams = LinearLayout.LayoutParams(0, -2, 1f)
            }
            btn.setOnClickListener {
                // 更新视觉状态
                buttons.forEachIndexed { i, b ->
                    if (i == index) {
                        b.setTextColor(resolveThemeColor(android.R.attr.textColorPrimary))
                        b.background = GradientDrawable().apply {
                            setColor(resolveThemeColor(android.R.attr.colorBackground))
                            cornerRadius = dp(4).toFloat()
                        }
                    } else {
                        b.setTextColor(resolveThemeColor(android.R.attr.textColorSecondary))
                        b.background = null
                    }
                }
                // 只在用户交互时发送指令
                if (initialized) {
                    onSelect(index)
                }
            }
            buttons.add(btn)
            group.addView(btn)
        }
        // 设置默认选中（不触发 onSelect）
        buttons[defaultIndex].performClick()
        initialized = true
        return group
    }

    /** 从当前主题中解析颜色属性 */
    private fun resolveThemeColor(attr: Int): Int {
        val tv = TypedValue()
        return if (theme.resolveAttribute(attr, tv, true) && tv.type >= TypedValue.TYPE_FIRST_COLOR_INT && tv.type <= TypedValue.TYPE_LAST_COLOR_INT) {
            tv.data
        } else {
            // fallback 安全色
            val isDark = (resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES
            when (attr) {
                android.R.attr.colorBackground -> if (isDark) 0xFF1C1C1E.toInt() else Color.WHITE
                android.R.attr.textColorPrimary -> if (isDark) Color.WHITE else Color.BLACK
                android.R.attr.textColorSecondary -> if (isDark) 0xFFAAAAAA.toInt() else 0xFF666666.toInt()
                else -> if (isDark) 0xFF2C2C2E.toInt() else 0xFFE8E8E8.toInt() // card bg
            }
        }
    }

    private fun makeCard(): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val bg = GradientDrawable().apply {
                setColor(resolveThemeColor(android.R.attr.colorButtonNormal))
                cornerRadius = dp(10).toFloat()
            }
            background = bg
        }
    }

    private fun makeCompactButton(title: String, color: Int, onClick: () -> Unit): Button {
        return Button(this).apply {
            text = title
            textSize = 13f
            setTextColor(Color.WHITE)
            val bg = GradientDrawable().apply {
                setColor(color)
                cornerRadius = dp(6).toFloat()
            }
            background = bg
            setPadding(dp(10), dp(6), dp(10), dp(6))
            minHeight = 0
            minimumHeight = 0
            isAllCaps = false
            val lp = LinearLayout.LayoutParams(-2, -2)
            lp.marginStart = dp(6)
            layoutParams = lp
            setOnClickListener { onClick() }
        }
    }

    private fun makeButtonRow(items: List<Triple<String, Int, () -> Unit>>): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            items.forEach { (title, color, action) ->
                val btn = makeCompactButton(title, color, action)
                btn.layoutParams = LinearLayout.LayoutParams(0, -2, 1f).apply {
                    marginStart = dp(4)
                    marginEnd = dp(4)
                }
                addView(btn)
            }
        }
    }

    private fun makeLabeledRow(label: String, control: View): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(4), 0, dp(4))
            addView(makeSmallLabel(label).apply {
                layoutParams = LinearLayout.LayoutParams(dp(44), -2)
            })
            addView(control, LinearLayout.LayoutParams(0, -2, 1f))
        }
    }

    private fun makeSmallLabel(text: String): TextView {
        return TextView(this).apply {
            this.text = text
            textSize = 13f
            setTextColor(0xFF888888.toInt())
        }
    }

    private fun marginParams(bottom: Int = 0): LinearLayout.LayoutParams {
        return LinearLayout.LayoutParams(-1, -2).apply {
            bottomMargin = bottom
        }
    }

    // MARK: - Loading

    private fun showLoading(text: String = "连接认证中...") {
        loadingLabel.text = text
        loadingOverlay.visibility = View.VISIBLE
    }

    private fun hideLoading() {
        loadingOverlay.visibility = View.GONE
    }

    private fun cancelConnection() {
        sdk.stopScan()
        sdk.disconnect()
        hideLoading()
        scannedDevices.clear()
        scanButton.isEnabled = true
        statusLabel.text = "未连接"
        updateStatusDot(Color.GRAY)
        previousConnectionState = ConnectionState.DISCONNECTED
        log("用户取消连接")
    }

    // MARK: - 扫描连接

    private fun startScan() {
        if (scannedDevices.isNotEmpty()) return
        // 读取密钥输入框，设置 fixedAuthKey
        val keyInput = authKeyEditText.text.toString().trim().uppercase()
        if (keyInput.isNotEmpty() && keyInput.length == 4) {
            sdk.fixedAuthKey = keyInput
            log("使用固定密钥: $keyInput")
        } else {
            sdk.fixedAuthKey = null
        }
        // 检查权限
        if (!hasPermissions()) {
            requestPermissions()
            return
        }
        scanButton.isEnabled = false
        showLoading("扫描连接中...")
        log("扫描中...")
        updateStatus("扫描中...", 0xFFFF9800.toInt())
        scannedDevices.clear()
        sdk.startScan(
            onDeviceFound = { device ->
                if (scannedDevices.isEmpty()) {
                    scannedDevices.add(device)
                    log("发现 ${device.deviceName}")
                    showLoading("连接认证中...")
                    sdk.connect(device)
                    sdk.stopScan()
                }
            },
            onError = { error ->
                log("❌ ${error.message}")
                updateStatus("扫描失败", 0xFFF44336.toInt())
                hideLoading()
                runOnUiThread { scanButton.isEnabled = true }
            }
        )
    }

    private fun disconnect() {
        sdk.disconnect()
        log("已断开")
    }

    // MARK: - 操作

    private fun queryDeviceInfo() {
        sdk.queryDeviceInfo { result ->
            result.fold(
                onSuccess = { log("📱 v${it.firmwareVersion}") },
                onFailure = { log("❌ ${(it as BlueError).message}") }
            )
        }
    }

    private fun syncTime() {
        sdk.syncTime { result ->
            result.fold(
                onSuccess = { log("⏰ 时间已同步") },
                onFailure = { log("❌ ${(it as BlueError).message}") }
            )
        }
    }

    private fun showAlarmManager() {
        startActivity(Intent(this, AlarmManagerActivity::class.java))
    }

    private fun showRecords() {
        startActivity(Intent(this, MedicationRecordsActivity::class.java))
    }

    private fun showProtocolTest() {
        startActivity(Intent(this, ProtocolTestActivity::class.java))
    }

    private fun restoreFactory() {
        confirm("恢复出厂", "确定恢复出厂设置？") {
            sdk.restoreFactory { result ->
                result.fold(
                    onSuccess = { log("✅ 已恢复出厂") },
                    onFailure = { log("❌ ${(it as BlueError).message}") }
                )
            }
        }
    }

    private fun clearLocalBinding() {
        confirm("清除绑定", "清除本地密钥，设备也需恢复出厂。") {
            sdk.clearBinding()
            log("✅ 本地绑定已清除")
        }
    }

    private fun authWithOldKey() {
        log("尝试用旧密钥 05FA 认证...")
        sdk.authenticateWithKey(0x05, 0xFA.toByte()) { result ->
            result.fold(
                onSuccess = {
                    log("✅ 旧密钥认证成功！")
                    updateStatus("已连接(旧密钥)", 0xFF4CAF50.toInt())
                    hideLoading()
                },
                onFailure = { log("❌ 旧密钥认证也失败：${(it as BlueError).message}") }
            )
        }
    }

    // MARK: - 权限

    private fun hasPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestPermissions() {
        val perms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        ActivityCompat.requestPermissions(this, perms, 100)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 100 && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            log("✅ 权限已授予")
        } else {
            log("❌ 权限被拒绝")
        }
    }

    // MARK: - BlueSDKListener

    override fun onConnectionStateChanged(state: ConnectionState) {
        runOnUiThread {
            when (state) {
                ConnectionState.DISCONNECTED -> {
                    updateStatus("未连接", Color.GRAY)
                    scanButton.isEnabled = true
                    hideLoading()
                }
                ConnectionState.CONNECTING -> {
                    updateStatus("连接中...", 0xFFFF9800.toInt())
                }
                ConnectionState.CONNECTED -> {
                    updateStatus("认证中...", 0xFFFFEB3B.toInt())
                }
                ConnectionState.AUTHENTICATED -> {
                    updateStatus("已连接", 0xFF4CAF50.toInt())
                    hideLoading()
                }
                ConnectionState.RECONNECTING -> {
                    updateStatus("重连中...", 0xFFFF9800.toInt())
                }
            }

            // 连接后立即断开 = 认证失败
            if (state == ConnectionState.DISCONNECTED && previousConnectionState == ConnectionState.CONNECTED) {
                handleAuthFailed()
            }
            if (state == ConnectionState.DISCONNECTED) scannedDevices.clear()
            previousConnectionState = state
        }
    }

    override fun onAuthResult(success: Boolean, error: BlueError?) {
        // 已由 onConnectionStateChanged 处理 UI
    }

    override fun onTimeSyncRequested() {
        log("⏰ 时间同步（已自动处理）")
    }

    override fun onAlarmUpdated(alarm: AlarmInfo) {
        log("⏰ 闹钟${alarm.index} ${"%02d:%02d".format(alarm.hour, alarm.minute)}")
    }

    override fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) {
        log("🔔 闹钟${alarmIndex}响铃")
    }

    override fun onAlarmTimeout(alarmIndex: Int, alarmInfo: AlarmInfo) {
        log("⚠️ 闹钟${alarmIndex}超时")
    }

    override fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {
        log("💊 闹钟${alarmIndex} ${status}")
        // 保存到数据库
        MedicationDatabase.getInstance(this).insert(
            timestamp = System.currentTimeMillis(),
            alarmIndex = alarmIndex,
            status = status.protocolValue
        )
    }

    override fun onMedicationRecordReported(record: MedicationRecord) {
        MedicationDatabase.getInstance(this).insert(
            timestamp = record.timestamp,
            alarmIndex = record.alarmIndex,
            status = record.status.protocolValue
        )
        log("📋 用药记录已保存")
    }

    override fun onSoundTypeChanged(type: SoundType) {
        log("🔊 铃声变更")
    }

    override fun onTimeFormatChanged(format: TimeFormat) {
        log("🕐 时制变更")
    }

    // MARK: - 辅助

    private fun handleAuthFailed() {
        hideLoading()
        scanButton.isEnabled = true
        scannedDevices.clear()
        updateStatus("认证失败", 0xFFF44336.toInt())
        previousConnectionState = ConnectionState.DISCONNECTED
        log("🔐 认证失败")
        AlertDialog.Builder(this)
            .setTitle("认证失败")
            .setMessage("密钥不一致，请对设备长按按键恢复出厂设置后重试。")
            .setPositiveButton("确定", null)
            .show()
    }

    private fun updateStatus(text: String, color: Int) {
        runOnUiThread {
            statusLabel.text = text
            updateStatusDot(color)
        }
    }

    private fun updateStatusDot(color: Int) {
        (statusDot.background as? GradientDrawable)?.setColor(color)
    }

    private fun confirm(title: String, msg: String, action: () -> Unit) {
        AlertDialog.Builder(this)
            .setTitle(title)
            .setMessage(msg)
            .setNegativeButton("取消", null)
            .setPositiveButton("确定") { _, _ -> action() }
            .show()
    }

    private fun <T> logResult(action: String, result: Result<T>) {
        result.fold(
            onSuccess = { log("✅ $action") },
            onFailure = { log("❌ $action: ${(it as BlueError).message}") }
        )
    }

    private fun log(message: String) {
        val time = timeFormat.format(Date())
        runOnUiThread {
            logTextView.append("[$time] $message\n")
            logScrollView.post { logScrollView.fullScroll(ScrollView.FOCUS_DOWN) }
        }
    }
}
