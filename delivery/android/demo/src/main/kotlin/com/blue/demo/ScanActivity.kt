// ScanActivity.kt
// BlueSDK Demo - 扫描添加设备页
// 扫描附近 LX-PD02 设备，用户选择绑定

package com.blue.demo

import android.Manifest
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
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.blue.sdk.BlueSDK
import com.blue.sdk.BlueSDKListener
import com.blue.sdk.enums.ConnectionState
import com.blue.sdk.error.BlueError
import com.blue.sdk.model.ScannedDevice

/**
 * 扫描添加设备页
 * 扫描附近 LX-PD02 设备，排除已绑定设备，用户点击绑定
 */
class ScanActivity : AppCompatActivity() {

    private val bgDark = Color.parseColor("#1C1C1E")
    private val bgCard = Color.parseColor("#2C2C2E")
    private val textWhite = Color.WHITE
    private val textGray = Color.parseColor("#8E8E93")
    private val accentBlue = Color.parseColor("#007AFF")
    private val accentRed = Color.parseColor("#FF3B30")

    private lateinit var deviceListContainer: LinearLayout
    private lateinit var statusText: TextView
    private lateinit var scanButton: Button
    private var loadingOverlay: FrameLayout? = null
    private val handler = Handler(Looper.getMainLooper())

    private val sdk get() = BlueSDK.getInstance(this)
    private val discoveredDevices = mutableListOf<ScannedDevice>()
    private var isScanning = false
    private var pendingBindDevice: ScannedDevice? = null

    // SDK 监听器 — 监听绑定后自动连接结果
    private val sdkListener = object : BlueSDKListener {
        override fun onConnectionStateChanged(state: ConnectionState) {
            if (state == ConnectionState.AUTHENTICATED) {
                val device = pendingBindDevice ?: return
                DeviceStorage.updateLastConnected(this@ScanActivity, device.deviceId)
                handler.post {
                    hideLoading()
                    // 跳转控制页
                    val intent = Intent(this@ScanActivity, MainActivity::class.java)
                    intent.putExtra("device_id", device.deviceId)
                    intent.putExtra("device_name", device.deviceName)
                    intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    startActivity(intent)
                    finish()
                }
            } else if (state == ConnectionState.DISCONNECTED && pendingBindDevice != null) {
                handler.post {
                    hideLoading()
                    pendingBindDevice = null
                }
            }
        }

        override fun onAuthResult(success: Boolean, error: BlueError?) {
            if (!success) {
                handler.post {
                    hideLoading()
                    pendingBindDevice = null
                    Toast.makeText(
                        this@ScanActivity,
                        "${S.authFailedStatus}：${error?.message ?: ""}",
                        Toast.LENGTH_SHORT
                    ).show()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = bgDark
        window.navigationBarColor = bgDark
        supportActionBar?.hide()
        setContentView(buildUI())
        sdk.addObserver(sdkListener)
        requestPermsAndScan()
    }

    override fun onDestroy() {
        super.onDestroy()
        sdk.removeObserver(sdkListener)
        if (isScanning) sdk.stopScan()
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

        // 返回按钮
        titleBar.addView(TextView(this).apply {
            text = "←"
            setTextColor(accentBlue)
            textSize = 20f
            layoutParams = LinearLayout.LayoutParams(dp(40), WRAP_CONTENT)
            setOnClickListener { finish() }
        })

        titleBar.addView(TextView(this).apply {
            text = S.scanDevicesTitle
            setTextColor(textWhite)
            textSize = 18f
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
        })

        mainLayout.addView(titleBar)

        // 分割线
        mainLayout.addView(View(this).apply {
            setBackgroundColor(Color.parseColor("#3A3A3C"))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(1))
        })

        // 状态提示
        statusText = TextView(this).apply {
            text = S.searchingNearby
            setTextColor(textGray)
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(16), dp(16), dp(8))
        }
        mainLayout.addView(statusText)

        // 设备列表
        val scrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f)
        }

        deviceListContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(4), dp(16), dp(16))
        }
        scrollView.addView(deviceListContainer)
        mainLayout.addView(scrollView)

        // 底部操作栏
        val bottomBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(12), dp(16), dp(16))
        }

        scanButton = Button(this).apply {
            text = S.rescan
            setTextColor(textWhite)
            isAllCaps = false
            textSize = 15f
            background = roundDrawable(accentBlue, dp(8))
            setPadding(dp(24), dp(10), dp(24), dp(10))
            visibility = View.GONE
            setOnClickListener { startDeviceScan() }
        }
        bottomBar.addView(scanButton)

        mainLayout.addView(bottomBar)
        root.addView(mainLayout)

        // Loading 遮罩
        loadingOverlay = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#66000000"))
            visibility = View.GONE
            layoutParams = FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT)
            setOnClickListener { /* 拦截 */ }

            val card = LinearLayout(this@ScanActivity).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                background = roundDrawable(bgCard, dp(12))
                setPadding(dp(24), dp(20), dp(24), dp(20))
                layoutParams = FrameLayout.LayoutParams(dp(200), WRAP_CONTENT).apply {
                    gravity = Gravity.CENTER
                }
            }
            card.addView(ProgressBar(this@ScanActivity).apply {
                layoutParams = LinearLayout.LayoutParams(dp(36), dp(36)).apply { bottomMargin = dp(12) }
            })
            card.addView(TextView(this@ScanActivity).apply {
                text = S.connectingAuth
                setTextColor(textWhite)
                textSize = 15f
                gravity = Gravity.CENTER
            })
            card.addView(Button(this@ScanActivity).apply {
                text = S.cancel
                setTextColor(accentRed)
                isAllCaps = false
                textSize = 14f
                background = null
                layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply { topMargin = dp(8) }
                setOnClickListener {
                    sdk.disconnect()
                    pendingBindDevice = null
                    hideLoading()
                }
            })
            addView(card)
        }
        root.addView(loadingOverlay)

        return root
    }

    private fun requestPermsAndScan() {
        val perms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)

        val allGranted = perms.all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
        if (allGranted) {
            startDeviceScan()
        } else {
            ActivityCompat.requestPermissions(this, perms, 102)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 102 && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            startDeviceScan()
        } else {
            statusText.text = S.bluetoothPermissionRequired
            scanButton.visibility = View.VISIBLE
        }
    }

    private fun startDeviceScan() {
        if (isScanning) return
        isScanning = true
        discoveredDevices.clear()
        deviceListContainer.removeAllViews()
        statusText.text = S.searchingNearby
        scanButton.visibility = View.GONE

        sdk.startScan(timeoutMs = 15000L) { event ->
            when (event) {
                is com.blue.sdk.model.ScanEvent.DeviceFound -> {
                    val device = event.device
                    // 排除已绑定设备
                    if (DeviceStorage.isBound(this, device.deviceId)) return@startScan
                    // 排除已列出的（去重）
                    if (discoveredDevices.any { it.deviceId == device.deviceId }) {
                        // 更新 RSSI
                        val idx = discoveredDevices.indexOfFirst { it.deviceId == device.deviceId }
                        if (idx >= 0) discoveredDevices[idx] = device
                        handler.post { refreshDeviceList() }
                        return@startScan
                    }
                    discoveredDevices.add(device)
                    handler.post { refreshDeviceList() }
                }
                is com.blue.sdk.model.ScanEvent.Stopped -> {
                    isScanning = false
                    handler.post {
                        if (discoveredDevices.isEmpty()) {
                            statusText.text = S.noNewDevices
                        } else {
                            statusText.text = S.devicesFoundCount.replace("%d", discoveredDevices.size.toString())
                        }
                        scanButton.visibility = View.VISIBLE
                        scanButton.text = S.rescan
                    }
                }
                is com.blue.sdk.model.ScanEvent.Error -> {
                    isScanning = false
                    handler.post {
                        statusText.text = S.scanError
                        scanButton.visibility = View.VISIBLE
                    }
                }
            }
        }
    }

    private fun refreshDeviceList() {
        deviceListContainer.removeAllViews()
        for (device in discoveredDevices) {
            deviceListContainer.addView(buildDeviceRow(device))
            deviceListContainer.addView(View(this).apply {
                layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(8))
            })
        }
        statusText.text = if (isScanning) {
            S.scanningFoundCount.replace("%d", discoveredDevices.size.toString())
        } else {
            S.devicesFoundCount.replace("%d", discoveredDevices.size.toString())
        }
    }

    private fun buildDeviceRow(device: ScannedDevice): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = roundDrawable(bgCard, dp(10))
            setPadding(dp(14), dp(12), dp(14), dp(12))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
        }

        val info = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
        }

        info.addView(TextView(this).apply {
            text = device.deviceName
            setTextColor(textWhite)
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
        })

        info.addView(TextView(this).apply {
            text = "${device.deviceId}  ${device.rssi}dBm"
            setTextColor(textGray)
            textSize = 12f
            layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply { topMargin = dp(2) }
        })

        row.addView(info)

        // 绑定按钮
        val bindBtn = Button(this).apply {
            text = S.bind
            setTextColor(textWhite)
            isAllCaps = false
            textSize = 13f
            background = roundDrawable(accentBlue, dp(6))
            setPadding(dp(16), dp(6), dp(16), dp(6))
            layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT)
            setOnClickListener { bindDevice(device) }
        }
        row.addView(bindBtn)

        return row
    }

    private fun bindDevice(device: ScannedDevice) {
        // 停止扫描
        if (isScanning) {
            sdk.stopScan()
            isScanning = false
        }

        // 保存到本地绑定列表
        val bound = BoundDevice(
            deviceId = device.deviceId,
            deviceName = device.deviceName,
            bindTime = System.currentTimeMillis(),
            lastConnectedTime = System.currentTimeMillis()
        )
        DeviceStorage.add(this, bound)

        // 自动连接
        pendingBindDevice = device
        showLoading()
        sdk.connect(device)
    }

    private fun showLoading() {
        loadingOverlay?.visibility = View.VISIBLE
    }

    private fun hideLoading() {
        loadingOverlay?.visibility = View.GONE
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
