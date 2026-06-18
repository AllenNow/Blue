// ScanEvent.kt
// BlueSDK - 扫描事件模型
// BlueSDK - Scan event model

package com.blue.sdk.model

import com.blue.sdk.error.BlueError

/**
 * 扫描事件
 * Scan event
 *
 * 统一的扫描回调类型，替代原有双回调（onDeviceFound + onError）模式
 * Unified scan callback type, replaces legacy dual-callback (onDeviceFound + onError) pattern
 */
sealed class ScanEvent {
    /**
     * 发现设备
     * Device found
     */
    data class DeviceFound(val device: ScannedDevice) : ScanEvent()

    /**
     * 扫描错误
     * Scan error
     */
    data class Error(val error: BlueError) : ScanEvent()

    /**
     * 扫描已停止（超时或手动停止）
     * Scan stopped (timeout or manual)
     */
    object Stopped : ScanEvent()
}
