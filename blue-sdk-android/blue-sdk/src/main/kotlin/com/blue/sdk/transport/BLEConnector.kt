// BLEConnector.kt
// BlueSDK - BLE 连接器：管理 GATT 连接和数据收发

package com.blue.sdk.transport

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Build
import com.blue.sdk.internal.BlueLogger
import java.util.UUID

internal interface BLEConnectorDelegate {
    fun onConnected()
    fun onDisconnected(error: Exception?)
    fun onDataReceived(data: ByteArray)
}

internal class BLEConnector {

    companion object {
        // LX-PD02 GATT 服务/特征 UUID
        private val SERVICE_UUID    = UUID.fromString("0000D459-0000-1000-8000-00805F9B34FB")
        private val WRITE_CHAR_UUID = UUID.fromString("00000013-0000-1000-8000-00805F9B34FB")
        private val NOTIFY_CHAR_UUID = UUID.fromString("00000014-0000-1000-8000-00805F9B34FB")
        private val CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")
    }

    private var gatt: BluetoothGatt? = null
    private var writeCharacteristic: BluetoothGattCharacteristic? = null
    var delegate: BLEConnectorDelegate? = null

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    BlueLogger.info("GATT 已连接，开始发现服务")
                    gatt.discoverServices()
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    writeCharacteristic = null
                    val error = if (status != BluetoothGatt.GATT_SUCCESS)
                        Exception("GATT 断开，状态码：$status") else null
                    BlueLogger.info("GATT 已断开：${error?.message ?: "正常断开"}")
                    delegate?.onDisconnected(error)
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                BlueLogger.error("服务发现失败，状态码：$status")
                delegate?.onDisconnected(Exception("服务发现失败"))
                return
            }
            val service = gatt.getService(SERVICE_UUID)
            if (service == null) {
                BlueLogger.error("未找到目标服务：$SERVICE_UUID")
                delegate?.onDisconnected(Exception("未找到目标服务"))
                return
            }
            writeCharacteristic = service.getCharacteristic(WRITE_CHAR_UUID)
            val notifyChar = service.getCharacteristic(NOTIFY_CHAR_UUID)
            if (notifyChar != null) {
                gatt.setCharacteristicNotification(notifyChar, true)
                val descriptor = notifyChar.getDescriptor(CCCD_UUID)
                if (descriptor != null) {
                    writeDescriptorCompat(gatt, descriptor, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                }
            }
            if (writeCharacteristic != null) {
                BlueLogger.info("GATT 特征就绪，连接完成")
                delegate?.onConnected()
            }
        }

        @Suppress("DEPRECATION")
        @Deprecated("Use onCharacteristicChanged(gatt, characteristic, value) for API 33+")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            // API 33+ 上系统会同时触发新旧两个回调，旧回调的 characteristic.value 可能是过期数据
            // 仅在 API 32 及以下使用此回调
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) return
            val data = characteristic.value ?: return
            BlueLogger.debug("收到数据：${data.joinToString(" ") { "%02X".format(it) }}")
            delegate?.onDataReceived(data)
        }

        // API 33+ 的新回调
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            BlueLogger.debug("收到数据：${value.joinToString(" ") { "%02X".format(it) }}")
            delegate?.onDataReceived(value)
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                BlueLogger.error("写入失败，状态码：$status")
            }
        }
    }

    fun connect(context: Context, device: BluetoothDevice) {
        BlueLogger.info("正在连接设备：${device.address}")
        gatt = device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
    }

    fun disconnect() {
        gatt?.disconnect()
        gatt?.close()
        gatt = null
        writeCharacteristic = null
        BlueLogger.info("主动断开连接")
    }

    fun write(bytes: ByteArray) {
        val char = writeCharacteristic
        val g = gatt
        if (char == null || g == null) {
            BlueLogger.error("写特征未就绪，无法发送数据")
            return
        }
        writeCharacteristicCompat(g, char, bytes)
        BlueLogger.debug("发送帧：${bytes.joinToString(" ") { "%02X".format(it) }}")
    }

    // MARK: - API 版本兼容方法

    @Suppress("DEPRECATION")
    private fun writeCharacteristicCompat(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ (API 33) 新版 API
            gatt.writeCharacteristic(characteristic, value, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT)
        } else {
            // Android 12 及以下旧版 API
            characteristic.value = value
            characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            gatt.writeCharacteristic(characteristic)
        }
    }

    @Suppress("DEPRECATION")
    private fun writeDescriptorCompat(
        gatt: BluetoothGatt,
        descriptor: BluetoothGattDescriptor,
        value: ByteArray
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ (API 33) 新版 API
            gatt.writeDescriptor(descriptor, value)
        } else {
            // Android 12 及以下旧版 API
            descriptor.value = value
            gatt.writeDescriptor(descriptor)
        }
    }
}
