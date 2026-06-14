package com.blue.sdk.model

/**
 * 设备基础信息
 * @param firmwareVersion 固件版本号（如 "1.0.0"）
 * @param macAddress 设备 MAC 地址
 */
data class DeviceInfo(
    val firmwareVersion: String,
    val macAddress: String
) {
    companion object {
        /** 版本号正则（从固件信息字符串中提取版本号）*/
        private val VERSION_REGEX = Regex("""(\d+\.\d+\.\d+)""")
        
        /**
         * 从原始固件版本字符串中解析标准版本号
         * @param raw 原始版本字符串（如 "LX-PD02_V1.0.3_20240101"）
         * @return 标准版本号（如 "1.0.3"），解析失败返回原始字符串
         */
        fun parseFirmwareVersion(raw: String): String {
            return VERSION_REGEX.find(raw)?.groupValues?.getOrNull(1) ?: raw
        }
    }
}

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
