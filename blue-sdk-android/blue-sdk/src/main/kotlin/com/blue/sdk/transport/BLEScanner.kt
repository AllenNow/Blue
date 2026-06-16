// BLEScanner.kt
// BlueSDK - BLE 设备扫描器（FR01）

package com.blue.sdk.transport

import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.os.Handler
import android.os.Looper
import com.blue.sdk.error.BlueError
import com.blue.sdk.internal.BlueLogger
import com.blue.sdk.internal.CallbackDispatcher
import com.blue.sdk.model.ScannedDevice

internal class BLEScanner {

    companion object {
        private const val DEVICE_NAME_PREFIX = "LX-PD02"
        private const val SCAN_DELAY_AFTER_DISCONNECT_MS = 500L
    }

    @Volatile internal var isScanning = false
    private var onDeviceFound: ((ScannedDevice) -> Unit)? = null
    private var onError: ((BlueError) -> Unit)? = null
    private val handler = Handler(Looper.getMainLooper())
    private var pendingScanRunnable: Runnable? = null

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val name = result.device.name ?: return
            if (!name.startsWith(DEVICE_NAME_PREFIX)) return
            val device = ScannedDevice(
                deviceId = result.device.address,
                deviceName = name,
                rssi = result.rssi
            )
            BlueLogger.debug("发现设备：$name，RSSI：${result.rssi}")
            CallbackDispatcher.dispatch { onDeviceFound?.invoke(device) }
        }

        override fun onScanFailed(errorCode: Int) {
            BlueLogger.error("BLE 扫描失败，错误码：$errorCode")
            CallbackDispatcher.dispatch { onError?.invoke(BlueError.BleError(Exception("Scan failed: $errorCode"))) }
        }
    }

    fun startScan(
        adapter: BluetoothAdapter,
        onDeviceFound: (ScannedDevice) -> Unit,
        onError: (BlueError) -> Unit
    ) {
        pendingScanRunnable?.let { handler.removeCallbacks(it) }
        pendingScanRunnable = null

        if (isScanning) {
            adapter.bluetoothLeScanner?.stopScan(scanCallback)
            isScanning = false
        }

        this.onDeviceFound = onDeviceFound
        this.onError = onError

        val runnable = Runnable {
            isScanning = true
            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()
            adapter.bluetoothLeScanner?.startScan(null, settings, scanCallback)
            BlueLogger.info("BLE 扫描已启动，过滤前缀：$DEVICE_NAME_PREFIX")
        }
        pendingScanRunnable = runnable
        handler.postDelayed(runnable, SCAN_DELAY_AFTER_DISCONNECT_MS)
    }

    fun stopScan(adapter: BluetoothAdapter) {
        pendingScanRunnable?.let { handler.removeCallbacks(it) }
        pendingScanRunnable = null

        if (!isScanning) return
        adapter.bluetoothLeScanner?.stopScan(scanCallback)
        isScanning = false
        onDeviceFound = null
        onError = null
        BlueLogger.info("BLE 扫描已停止")
    }
}
