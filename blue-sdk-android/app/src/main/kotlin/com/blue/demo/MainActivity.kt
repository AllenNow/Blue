// MainActivity.kt
// BlueSDK Android Demo - 完整集成演示
//
// 演示完整集成流程：
// 1. 权限检查与申请
// 2. 扫描设备
// 3. 连接设备
// 4. 密钥认证
// 5. 设置闹钟
// 6. 接收用药事件

package com.blue.demo

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.blue.sdk.BlueSDK
import com.blue.sdk.BlueSDKListener
import com.blue.sdk.enums.ConnectionState
import com.blue.sdk.enums.MedicationStatus
import com.blue.sdk.enums.SoundType
import com.blue.sdk.enums.TimeFormat
import com.blue.sdk.enums.VolumeLevel
import com.blue.sdk.error.BlueError
import com.blue.sdk.model.AlarmInfo
import com.blue.sdk.model.DeviceInfo
import com.blue.sdk.model.MedicationRecord
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : AppCompatActivity(), BlueSDKListener {

    private lateinit var statusText: TextView
    private lateinit var logText: TextView
    private lateinit var scrollView: ScrollView

    // 演示用 MAC 地址
    private val phoneMac = byteArrayOf(0xC7.toByte(), 0x50, 0xB2.toByte(), 0xAA.toByte(), 0xC3.toByte(), 0xF3.toByte())
    private val deviceMac = byteArrayOf(0xA6.toByte(), 0xC0.toByte(), 0x82.toByte(), 0x00, 0xA1.toByte(), 0xC2.toByte())

    private val sdk get() = BlueSDK.getInstance(this)
    private val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.getDefault())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = "BlueSDK Demo"
        setupUI()
        sdk.listener = this
        log("BlueSDK Demo 已启动")
    }

    override fun onDestroy() {
        super.onDestroy()
        sdk.listener = null
    }

    private fun setupUI() {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
        }

        statusText = TextView(this).apply {
            text = "状态：未连接"
            textSize = 14f
        }
        root.addView(statusText)

        fun addSection(title: String) {
            root.addView(TextView(this).apply {
                text = title
                textSize = 13f
                setTextColor(0xFF888888.toInt())
                setPadding(0, 24, 0, 4)
            })
        }

        fun addButton(label: String, action: () -> Unit) {
            root.addView(Button(this).apply {
                text = label
                setOnClickListener { action() }
            })
        }

        addSection("连接管理")
        addButton("检查蓝牙权限") { checkPermissions() }
        addButton("申请权限") { requestPermissions() }
        addButton("断开连接") { sdk.disconnect(); log("已主动断开") }

        addSection("认证")
        addButton("发送密钥认证") { authenticate() }

        addSection("设备信息")
        addButton("查询设备信息") { queryDeviceInfo() }
        addButton("同步当前时间") { syncTime() }

        addSection("闹钟管理")
        addButton("设置闹钟1（08:00 每天）") { setAlarm1() }
        addButton("设置闹钟2（12:30 工作日）") { setAlarm2() }
        addButton("删除闹钟1") { deleteAlarm1() }
        addButton("清空所有闹钟") { clearAllAlarms() }

        addSection("音频与系统设置")
        addButton("设置音量：中") { sdk.setVolume(VolumeLevel.MEDIUM) { logResult("设置音量", it) } }
        addButton("设置铃声：类型A") { sdk.setSoundType(SoundType.TYPE_A) { logResult("设置铃声", it) } }
        addButton("设置时间格式：24小时制") { sdk.setTimeFormat(TimeFormat.HOUR_24) { logResult("设置时间格式", it) } }
        addButton("静音开") { sdk.setSilence(true) { logResult("设置静音", it) } }

        addSection("日志")
        addButton("清空日志") { logText.text = "" }

        logText = TextView(this).apply {
            textSize = 11f
            setTextColor(0xFF333333.toInt())
            setBackgroundColor(0xFFF5F5F5.toInt())
            setPadding(16, 16, 16, 16)
        }

        scrollView = ScrollView(this).apply {
            addView(logText)
        }
        root.addView(scrollView, LinearLayout.LayoutParams(-1, 400))

        setContentView(ScrollView(this).apply { addView(root) })
    }

    // MARK: - 按钮动作

    private fun checkPermissions() {
        val status = sdk.checkPermissions()
        log("蓝牙权限：$status")
    }

    private fun requestPermissions() {
        val perms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        ActivityCompat.requestPermissions(this, perms, 100)
    }

    private fun authenticate() {
        log("发送密钥认证...")
        sdk.authenticate(phoneMac, deviceMac) { result ->
            result.fold(
                onSuccess = { log("✅ 认证成功") },
                onFailure = { log("❌ 认证失败：${(it as BlueError).message}") }
            )
        }
    }

    private fun queryDeviceInfo() {
        sdk.queryDeviceInfo { result ->
            result.fold(
                onSuccess = { log("✅ 固件版本：${it.firmwareVersion}") },
                onFailure = { log("❌ 查询失败：${(it as BlueError).message}") }
            )
        }
    }

    private fun syncTime() {
        sdk.syncTime { result ->
            result.fold(
                onSuccess = { log("✅ 时间同步成功") },
                onFailure = { log("❌ 时间同步失败：${(it as BlueError).message}") }
            )
        }
    }

    private fun setAlarm1() {
        sdk.setAlarm(1, 8, 0, 0x7F) { result ->
            result.fold(
                onSuccess = { log("✅ 闹钟${it.index}已设置：${"%02d:%02d".format(it.hour, it.minute)} 每天") },
                onFailure = { log("❌ 设置失败：${(it as BlueError).message}") }
            )
        }
    }

    private fun setAlarm2() {
        sdk.setAlarm(2, 12, 30, 0x3E) { result ->
            result.fold(
                onSuccess = { log("✅ 闹钟${it.index}已设置：${"%02d:%02d".format(it.hour, it.minute)} 工作日") },
                onFailure = { log("❌ 设置失败：${(it as BlueError).message}") }
            )
        }
    }

    private fun deleteAlarm1() {
        sdk.deleteAlarm(1) { result ->
            result.fold(
                onSuccess = { log("✅ 闹钟1已删除") },
                onFailure = { log("❌ 删除失败：${(it as BlueError).message}") }
            )
        }
    }

    private fun clearAllAlarms() {
        sdk.clearAllAlarms { result ->
            result.fold(
                onSuccess = { log("✅ 所有闹钟已清空") },
                onFailure = { log("❌ 清空失败：${(it as BlueError).message}") }
            )
        }
    }

    private fun <T> logResult(action: String, result: Result<T>) {
        result.fold(
            onSuccess = { log("✅ $action 成功") },
            onFailure = { log("❌ $action 失败：${(it as BlueError).message}") }
        )
    }

    // MARK: - BlueSDKListener

    override fun onConnectionStateChanged(state: ConnectionState) {
        val text = when (state) {
            ConnectionState.DISCONNECTED  -> "已断开"
            ConnectionState.CONNECTING    -> "连接中..."
            ConnectionState.CONNECTED     -> "已连接（未认证）"
            ConnectionState.AUTHENTICATED -> "已认证 ✅"
            ConnectionState.RECONNECTING  -> "重连中..."
        }
        log("🔗 连接状态：$text")
        runOnUiThread { statusText.text = "状态：$text" }
    }

    override fun onAuthResult(success: Boolean, error: BlueError?) {
        log(if (success) "🔐 认证成功" else "🔐 认证失败：${error?.message}")
    }

    override fun onTimeSyncRequested() {
        log("⏰ 设备请求时间同步，自动下发...")
        sdk.syncTime { result ->
            result.fold(
                onSuccess = { log("⏰ 时间同步完成") },
                onFailure = { log("⏰ 时间同步失败") }
            )
        }
    }

    override fun onAlarmUpdated(alarm: AlarmInfo) {
        log("⏰ 设备端闹钟${alarm.index}变更：${"%02d:%02d".format(alarm.hour, alarm.minute)}")
    }

    override fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) {
        log("🔔 闹钟${alarmIndex}开始响铃！${"%02d:%02d".format(alarmInfo.hour, alarmInfo.minute)}")
    }

    override fun onAlarmTimeout(alarmIndex: Int, alarmInfo: AlarmInfo) {
        log("⚠️ 闹钟${alarmIndex}超时未取药！")
    }

    override fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {
        val text = when (status) {
            MedicationStatus.TAKEN   -> "✅ 按时取药"
            MedicationStatus.TIMEOUT -> "⏰ 超时取药"
            MedicationStatus.MISSED  -> "❌ 漏服"
            MedicationStatus.EARLY   -> "⏩ 提前取药"
        }
        log("💊 闹钟${alarmIndex}用药结果：$text")
    }

    override fun onMedicationRecordReported(record: MedicationRecord) {
        val date = Date(record.timestamp)
        log("📋 用药记录：闹钟${record.alarmIndex}，${timeFormat.format(date)}，${record.status}")
    }

    override fun onSoundTypeChanged(type: SoundType) {
        log("🔊 铃声类型变更：$type")
    }

    override fun onTimeFormatChanged(format: TimeFormat) {
        log("🕐 时间格式变更：${if (format == TimeFormat.HOUR_24) "24小时制" else "12小时制"}")
    }

    // MARK: - 辅助

    private fun log(message: String) {
        val time = timeFormat.format(Date())
        runOnUiThread {
            logText.append("[$time] $message\n")
            scrollView.post { scrollView.fullScroll(ScrollView.FOCUS_DOWN) }
        }
    }
}
