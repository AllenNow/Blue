// PermissionManager.kt
// BlueSDK - 蓝牙权限状态检查（FR07）
// 与 iOS PermissionManager 对称

package com.blue.sdk.manager

import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.blue.sdk.enums.PermissionStatus

/**
 * 权限管理器
 * 查询蓝牙权限状态，不触发系统权限弹窗
 */
internal object PermissionManager {

    /**
     * 查询当前蓝牙权限状态（同步，不触发系统弹窗）
     * @param context 应用上下文
     * @return 权限状态枚举
     */
    fun checkPermission(context: Context): PermissionStatus {
        val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = btManager?.adapter ?: return PermissionStatus.DENIED

        if (!adapter.isEnabled) return PermissionStatus.DENIED

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val scanPerm = context.checkSelfPermission(android.Manifest.permission.BLUETOOTH_SCAN)
            val connectPerm = context.checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT)
            if (scanPerm == PackageManager.PERMISSION_GRANTED &&
                connectPerm == PackageManager.PERMISSION_GRANTED)
                PermissionStatus.GRANTED else PermissionStatus.DENIED
        } else {
            val locPerm = context.checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION)
            if (locPerm == PackageManager.PERMISSION_GRANTED)
                PermissionStatus.GRANTED else PermissionStatus.DENIED
        }
    }
}
