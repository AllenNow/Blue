package com.blue.sdk.model

import com.blue.sdk.model.ScannedDevice

/**
 * 设备基础信息
 * @param firmwareVersion 固件版本号（如 "1.0.0"）
 * @param deviceId 设备 MAC 地址
 */
data class DeviceInfo(
    val firmwareVersion: String,
    val deviceId: String
)

/**
 * 扫描到的设备信息
 * @param deviceId 设备唯一标识（MAC 地址）
 * @param deviceName 设备广播名称（如 LX-PD02-A1B2）
 * @param rssi 信号强度（RSSI，单位 dBm）
 */
data class ScannedDevice(
    val deviceId: String,
    val deviceName: String,
    val rssi: Int
)
