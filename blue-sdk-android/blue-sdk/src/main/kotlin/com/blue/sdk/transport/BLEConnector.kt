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
            // 忽略非当前 GATT 实例的回调（防止旧连接残留回调导致重复处理）
            if (gatt != this@BLEConnector.gatt) return
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    BlueLogger.info("GATT connected, discovering services")
                    gatt.discoverServices()
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    writeCharacteristic = null
                    val error = if (status != BluetoothGatt.GATT_SUCCESS)
                        Exception("GATT 断开，状态码：$status") else null
                    BlueLogger.info("GATT disconnected: ${error?.message ?: "normal"}")
                    delegate?.onDisconnected(error)
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (gatt != this@BLEConnector.gatt) return
            if (status != BluetoothGatt.GATT_SUCCESS) {
                BlueLogger.error("Service discovery failed, status: $status")
                delegate?.onDisconnected(Exception("服务发现失败"))
                return
            }
            val service = gatt.getService(SERVICE_UUID)
            if (service == null) {
                BlueLogger.error("Target service not found: $SERVICE_UUID")
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
                BlueLogger.info("GATT characteristics ready, connected")
                delegate?.onConnected()
            }
        }

        @Suppress("DEPRECATION")
        @Deprecated("Use onCharacteristicChanged(gatt, characteristic, value) for API 33+")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            if (gatt != this@BLEConnector.gatt) return
            // API 33+ 上系统会同时触发新旧两个回调，旧回调的 characteristic.value 可能是过期数据
            // 仅在 API 32 及以下使用此回调
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) return
            val data = characteristic.value ?: return
            if (BlueLogger.rawFrameLogEnabled) {
                BlueLogger.debug("RX: ${data.joinToString(" ") { "%02X".format(it) }}")
            }
            delegate?.onDataReceived(data)
        }

        // API 33+ 的新回调
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            if (gatt != this@BLEConnector.gatt) return
            if (BlueLogger.rawFrameLogEnabled) {
                BlueLogger.debug("RX: ${value.joinToString(" ") { "%02X".format(it) }}")
            }
            delegate?.onDataReceived(value)
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                BlueLogger.error("Write failed, status: $status")
            }
        }
    }

    fun connect(context: Context, device: BluetoothDevice) {
        // 关闭旧的 GATT 连接（避免重复注册 notify 导致数据重复回调）
        gatt?.let {
            it.disconnect()
            it.close()
        }
        gatt = null
        writeCharacteristic = null
        BlueLogger.info("Connecting to: ${device.address}")
        gatt = device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
    }

    fun disconnect() {
        gatt?.disconnect()
        gatt?.close()
        gatt = null
        writeCharacteristic = null
        BlueLogger.info("Disconnected manually")
    }

    fun write(bytes: ByteArray) {
        val char = writeCharacteristic
        val g = gatt
        if (char == null || g == null) {
            BlueLogger.error("Write characteristic not ready")
            return
        }
        writeCharacteristicCompat(g, char, bytes)
        if (BlueLogger.rawFrameLogEnabled) {
            BlueLogger.debug("TX: ${bytes.joinToString(" ") { "%02X".format(it) }}")
        }
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
