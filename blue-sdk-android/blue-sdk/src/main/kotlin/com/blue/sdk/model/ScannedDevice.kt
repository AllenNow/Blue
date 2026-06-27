// ScannedDevice.kt
// BlueSDK - 扫描到的设备信息

package com.blue.sdk.model

import android.bluetooth.BluetoothDevice

data class ScannedDevice(
    val deviceId: String,
    val deviceName: String,
    val rssi: Int,
    val bluetoothDevice: BluetoothDevice
)