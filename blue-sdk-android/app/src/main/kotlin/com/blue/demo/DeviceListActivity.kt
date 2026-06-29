// DeviceListActivity.kt
// BlueSDK Demo - 设备列表主页
// 展示已绑定设备，进入时自动扫描更新在线状态

package com.blue.demo

import android.Manifest
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
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
import androidx.core.content.ContextCompat
import com.blue.sdk.BlueSDKManager
import com.blue.sdk.BlueSDKListener
import com.blue.sdk.enums.ConnectionState
import com.blue.sdk.error.BlueError
import com.blue.sdk.model.ScannedDevice

/**
 * 设备列表页 — Demo 主入口
 * 展示已绑定设备列表，进入时自动扫描 5 秒更新在线状态
 */
class DeviceListActivity : AppCompatActivity() {

    // 主题色
    private val bgDark = Color.parseColor("#1C1C1E")
    private val bgCard = Color.parseColor("#2C2C2E")
    private val textWhite = Color.WHITE
    private val textGray = Color.parseColor("#8E8E93")
    private val accentBlue = Color.parseColor("#007AFF")
    private val accentGreen = Color.parseColor("#30D158")
    private val accentRed = Color.parseColor("#FF3B30")

    private lateinit var deviceListContainer: LinearLayout
    private lateinit var emptyView: LinearLayout
    private lateinit var scanIndicator: TextView
    private val handler = Handler(Looper.getMainLooper())

    private val sdk get() = BlueSDKManager.getInstance(this)

    // 运行时在线状态
    private val onlineDevices = mutableSetOf<String>()
    private val rssiMap = mutableMapOf<String, Int>()
    private var isScanning = false
    /** 当前已连接的设备 ID（跟踪连接状态用） */
    private var connectedDeviceId: String? = null
    /** 用户是否主动断开（主动断开不触发自动重连） */
    private var isUserDisconnect = false

    // SDK 监听器 — 监听连接状态变化
    private val sdkListener = object : BlueSDKListener {
        override fun onConnectionStateChanged(state: ConnectionState) {
            if (state == ConnectionState.AUTHENTICATED) {
                // 连接认证成功，跳转控制页（防止重复跳转）
                val device = pendingConnectDevice ?: return
                pendingConnectDevice = null
                connectedDeviceId = device.deviceId
                DeviceStorage.updateLastConnected(this@DeviceListActivity, device.deviceId)
                handler.post {
                    hideLoading()
                    val intent = Intent(this@DeviceListActivity, MainActivity::class.java)
                    intent.putExtra("device_id", device.deviceId)
                    intent.putExtra("device_name", device.deviceName)
                    intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    startActivity(intent)
                }
            } else if (state == ConnectionState.DISCONNECTED) {
                connectedDeviceId = null
                handler.post {
                    // 主动断开或认证失败不自动重连
                    if (isUserDisconnect) {
                        isUserDisconnect = false
                        pendingConnectDevice = null
                        hideLoading()
                        refreshList()
                    } else {
                        val pending = pendingConnectDevice
                        if (pending != null) {
                            handler.postDelayed({ performConnect(pending) }, 500)
                        } else {
                            hideLoading()
                            refreshList()
                        }
                    }
                }
            }
        }

        override fun onAuthResult(success: Boolean, error: BlueError?) {
            if (!success) {
                handler.post {
                    hideLoading()
                    pendingConnectDevice = null
                    Toast.makeText(
                        this@DeviceListActivity,
                        "${S.authFailedStatus}：${error?.message ?: ""}",
                        Toast.LENGTH_SHORT
                    ).show()
                    refreshList()
                }
            }
        }
    }

    private var pendingConnectDevice: BoundDevice? = null
    private var loadingOverlay: FrameLayout? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 首次启动时跳转语言选择页
        if (LanguageActivity.needsLanguageSelection(this)) {
            startActivity(Intent(this, LanguageActivity::class.java))
            finish()
            return
        }

        window.statusBarColor = bgDark
        window.navigationBarColor = bgDark
        supportActionBar?.hide()
        setContentView(buildUI())
        sdk.addObserver(sdkListener)
    }

    override fun onResume() {
        super.onResume()
        // 同步当前连接状态（从控制页返回时可能仍已连接或已断开）
        if (sdk.connectionState != ConnectionState.AUTHENTICATED) {
            connectedDeviceId = null
        }
        refreshList()
        requestPermsAndScan()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 200 && resultCode == RESULT_OK) {
            // 语言已切换，重建 Activity 使 UI 刷新
            recreate()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        sdk.removeObserver(sdkListener)
        sdk.stopScan()
    }

    private fun buildUI(): View {
        val root = FrameLayout(this).apply {
            setBackgroundColor(bgDark)
            layoutParams = ViewGroup.LayoutParams(MATCH_PARENT, MATCH_PARENT)
        }

        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = ViewGroup.LayoutParams(MATCH_PARENT, MATCH_PARENT)
        }

        // 顶部标题栏
        val titleBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), dp(12), dp(16), dp(12))
        }

        titleBar.addView(TextView(this).apply {
            text = "Blue SDK Demo"
            setTextColor(textWhite)
            textSize = 20f
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
        })

        scanIndicator = TextView(this).apply {
            text = S.scanning
            setTextColor(accentBlue)
            textSize = 13f
            visibility = View.GONE
            layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply { marginEnd = dp(12) }
        }
        titleBar.addView(scanIndicator)

        // 语言切换按钮
        val langBtn = TextView(this).apply {
            text = "🌐"
            textSize = 20f
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(dp(36), dp(36)).apply { marginEnd = dp(8) }
            setOnClickListener {
                startActivityForResult(
                    Intent(this@DeviceListActivity, LanguageActivity::class.java).apply {
                        putExtra("from_settings", true)
                    },
                    200
                )
            }
        }
        titleBar.addView(langBtn)

        // 添加按钮
        val addBtn = TextView(this).apply {
            text = "＋"
            setTextColor(accentBlue)
            textSize = 24f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(dp(40), dp(40))
            setOnClickListener {
                startActivity(Intent(this@DeviceListActivity, ScanActivity::class.java))
            }
        }
        titleBar.addView(addBtn)
        mainLayout.addView(titleBar)

        // 分割线
        mainLayout.addView(View(this).apply {
            setBackgroundColor(Color.parseColor("#3A3A3C"))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(1))
        })

        // 设备列表滚动区
        val scrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f)
        }

        deviceListContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(12), dp(16), dp(12))
        }
        scrollView.addView(deviceListContainer)

        // 空态视图
        emptyView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(80), dp(32), dp(32))
            visibility = View.GONE
        }
        emptyView.addView(TextView(this).apply {
            text = "📱"
            textSize = 48f
            gravity = Gravity.CENTER
        })
        emptyView.addView(TextView(this).apply {
            text = S.noBoundDevices
            setTextColor(textGray)
            textSize = 16f
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply { topMargin = dp(12) }
        })
        emptyView.addView(TextView(this).apply {
            text = S.noBoundDevicesHint
            setTextColor(textGray)
            textSize = 13f
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply { topMargin = dp(4) }
        })
        deviceListContainer.addView(emptyView)

        mainLayout.addView(scrollView)

        // 底部版本号
        mainLayout.addView(TextView(this).apply {
            text = try { "v${packageManager.getPackageInfo(packageName, 0).versionName}" } catch (e: Exception) { "" }
            setTextColor(Color.parseColor("#3A3A3C"))
            textSize = 12f
            gravity = Gravity.CENTER
            setPadding(0, dp(8), 0, dp(8))
        })

        root.addView(mainLayout)

        // Loading 遮罩
        loadingOverlay = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#66000000"))
            visibility = View.GONE
            layoutParams = FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT)
            setOnClickListener { /* 拦截点击 */ }

            val card = LinearLayout(this@DeviceListActivity).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                background = roundDrawable(bgCard, dp(12))
                setPadding(dp(24), dp(20), dp(24), dp(20))
                layoutParams = FrameLayout.LayoutParams(dp(200), WRAP_CONTENT).apply {
                    gravity = Gravity.CENTER
                }
            }
            card.addView(ProgressBar(this@DeviceListActivity).apply {
                layoutParams = LinearLayout.LayoutParams(dp(36), dp(36)).apply { bottomMargin = dp(12) }
            })
            card.addView(TextView(this@DeviceListActivity).apply {
                text = S.connectingAuth
                setTextColor(textWhite)
                textSize = 15f
                gravity = Gravity.CENTER
                tag = "loading_label"
            })
            card.addView(Button(this@DeviceListActivity).apply {
                text = S.cancel
                setTextColor(accentRed)
                isAllCaps = false
                textSize = 14f
                background = null
                layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply { topMargin = dp(8) }
                setOnClickListener { cancelConnect() }
            })
            addView(card)
        }
        root.addView(loadingOverlay)

        return root
    }

    private fun refreshList() {
        val devices = DeviceStorage.loadAll(this)
        deviceListContainer.removeAllViews()

        if (devices.isEmpty()) {
            emptyView.visibility = View.VISIBLE
            deviceListContainer.addView(emptyView)
            return
        }

        emptyView.visibility = View.GONE

        for (device in devices) {
            val isConnected = sdk.connectionState == ConnectionState.AUTHENTICATED &&
                    connectedDeviceId == device.deviceId
            // 已连接的设备视为在线
            val isOnline = isConnected || onlineDevices.contains(device.deviceId)
            deviceListContainer.addView(buildDeviceCard(device, isOnline, isConnected))
            // 间距
            deviceListContainer.addView(View(this).apply {
                layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(8))
            })
        }
    }

    private fun buildDeviceCard(device: BoundDevice, isOnline: Boolean, isConnected: Boolean): View {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = if (isConnected) {
                roundDrawable(bgCard, dp(12)).apply {
                    setStroke(dp(2), accentBlue)
                }
            } else {
                roundDrawable(bgCard, dp(12))
            }
            setPadding(dp(16), dp(14), dp(16), dp(14))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
        }

        // 第一行：设备名称 + 状态标签
        val row1 = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        row1.addView(TextView(this).apply {
            text = device.deviceName
            setTextColor(textWhite)
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
        })

        // 状态标签
        val statusText: String
        val statusColor: Int
        when {
            isConnected -> {
                statusText = S.connected
                statusColor = accentBlue
            }
            isOnline -> {
                statusText = S.deviceOnline
                statusColor = accentGreen
            }
            else -> {
                statusText = S.deviceOffline
                statusColor = textGray
            }
        }

        row1.addView(TextView(this).apply {
            text = statusText
            setTextColor(statusColor)
            textSize = 12f
            background = roundDrawable(Color.parseColor("#1A${Integer.toHexString(statusColor).takeLast(6)}"), dp(4))
            setPadding(dp(8), dp(2), dp(8), dp(2))
        })

        card.addView(row1)

        // 第二行：MAC 地址 + RSSI
        val row2 = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = dp(6) }
        }

        row2.addView(TextView(this).apply {
            text = device.deviceId
            setTextColor(textGray)
            textSize = 12f
            layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
        })

        if (isOnline) {
            val rssi = rssiMap[device.deviceId] ?: -100
            val signalIcon = when {
                rssi > -50 -> "📶"
                rssi > -70 -> "📶"
                else -> "📶"
            }
            row2.addView(TextView(this).apply {
                text = "$signalIcon ${rssi}dBm"
                setTextColor(textGray)
                textSize = 11f
            })
        }

        card.addView(row2)

        // 点击事件 — 所有设备都允许尝试连接（Android 可通过 MAC 直接连）
        card.setOnClickListener {
            connectDevice(device)
        }

        // 长按删除
        card.setOnLongClickListener {
            showDeleteDialog(device)
            true
        }

        return card
    }

    private fun connectDevice(device: BoundDevice) {
        // 如果已经连接到该设备，直接跳转
        if (sdk.connectionState == ConnectionState.AUTHENTICATED && connectedDeviceId == device.deviceId) {
            val intent = Intent(this, MainActivity::class.java)
            intent.putExtra("device_id", device.deviceId)
            intent.putExtra("device_name", device.deviceName)
            intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            startActivity(intent)
            return
        }

        pendingConnectDevice = device
        showLoading()

        // 如果当前有连接，先断开，等断开回调后再连新设备
        if (sdk.connectionState != ConnectionState.DISCONNECTED) {
            sdk.disconnect()
            // sdkListener 中 DISCONNECTED 会检测 pendingConnectDevice 并自动调用 performConnect
            return
        }

        performConnect(device)
    }

    /** 实际执行连接逻辑 */
    private fun performConnect(device: BoundDevice) {
        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = btManager?.adapter
        if (adapter == null) {
            hideLoading()
            pendingConnectDevice = null
            Toast.makeText(this,
                S.bluetoothUnavailable,
                Toast.LENGTH_SHORT
            ).show()
            return
        }

        try {
            val btDevice = adapter.getRemoteDevice(device.deviceId)
            val scannedDevice = ScannedDevice(
                deviceId = device.deviceId,
                deviceName = device.deviceName,
                rssi = rssiMap[device.deviceId] ?: -100,
                bluetoothDevice = btDevice
            )
            sdk.connect(scannedDevice)
        } catch (e: Exception) {
            hideLoading()
            pendingConnectDevice = null
            Toast.makeText(this,
                "${S.connectFailed}：${e.message}",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    private fun cancelConnect() {
        isUserDisconnect = true
        sdk.disconnect()
        pendingConnectDevice = null
        hideLoading()
    }

    private fun showDeleteDialog(device: BoundDevice) {
        AlertDialog.Builder(this)
            .setTitle(S.removeDeviceTitle)
            .setMessage(S.removeDeviceMsg.replace("%@", device.deviceName))
            .setNegativeButton(S.cancel, null)
            .setPositiveButton(S.confirm) { _, _ ->
                // 如果正在连接该设备，先断开
                if (pendingConnectDevice?.deviceId == device.deviceId) {
                    sdk.disconnect()
                    pendingConnectDevice = null
                }
                DeviceStorage.remove(this, device.deviceId)
                refreshList()
            }
            .show()
    }

    private fun showLoading() {
        loadingOverlay?.visibility = View.VISIBLE
    }

    private fun hideLoading() {
        loadingOverlay?.visibility = View.GONE
    }

    // MARK: - 扫描逻辑

    private fun requestPermsAndScan() {
        val perms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)

        val allGranted = perms.all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
        if (allGranted) {
            startOnlineScan()
        } else {
            ActivityCompat.requestPermissions(this, perms, 101)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 101 && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            startOnlineScan()
        }
    }

    private fun startOnlineScan() {
        if (isScanning) return
        val devices = DeviceStorage.loadAll(this)
        if (devices.isEmpty()) return

        isScanning = true
        onlineDevices.clear()
        rssiMap.clear()
        scanIndicator.visibility = View.VISIBLE

        sdk.startScan(timeoutMs = 5000L) { event ->
            when (event) {
                is com.blue.sdk.model.ScanEvent.DeviceFound -> {
                    val found = event.device
                    if (DeviceStorage.isBound(this, found.deviceId)) {
                        onlineDevices.add(found.deviceId)
                        rssiMap[found.deviceId] = found.rssi
                        handler.post { refreshList() }
                    }
                }
                is com.blue.sdk.model.ScanEvent.Stopped -> {
                    isScanning = false
                    handler.post {
                        scanIndicator.visibility = View.GONE
                        refreshList()
                    }
                }
                is com.blue.sdk.model.ScanEvent.Error -> {
                    isScanning = false
                    handler.post { scanIndicator.visibility = View.GONE }
                }
            }
        }
    }

    // MARK: - 工具方法

    private fun dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
    ).toInt()

    private fun roundDrawable(color: Int, radius: Int): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radius.toFloat()
            setColor(color)
        }
    }
}
