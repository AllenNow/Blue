// ScanEvent.kt
// BlueSDK - 扫描事件

package com.blue.sdk.model

import com.blue.sdk.error.BlueError

sealed class ScanEvent {
    data class DeviceFound(val device: ScannedDevice) : ScanEvent()
    data class Error(val error: BlueError) : ScanEvent()
    object Stopped : ScanEvent()
}