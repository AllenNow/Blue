// BlueError.kt
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 统一错误类型定义（支持中英双语）

package com.blue.sdk.error

import com.blue.sdk.internal.SDKLocale

/**
 * SDK 统一错误类型
 * 继承 Exception 以支持 Result.failure()，所有异步操作通过回调返回，不向上层抛出（ARCH-08）
 * 根据 SDKLocale 设置自动切换中英文错误描述
 */
sealed class BlueError(message: String) : Exception(message) {
    /** SDK 未初始化 */
    object NotInitialized : BlueError(L.notInitializedMsg)
    /** 设备未完成认证 */
    object NotAuthenticated : BlueError(L.notAuthenticatedMsg)
    /** 认证失败，密钥不匹配 */
    object AuthFailed : BlueError(L.authFailedMsg)
    /** 指令超时（5秒内未收到设备应答）*/
    object Timeout : BlueError(L.timeoutMsg)
    /** 蓝牙权限未授权 */
    object PermissionDenied : BlueError(L.permissionDeniedMsg)
    /** 参数无效 */
    object InvalidParameter : BlueError(L.invalidParameterMsg)
    /** 协议错误 */
    object ProtocolError : BlueError(L.protocolErrorMsg)
    /** 设备已断开连接 */
    object Disconnected : BlueError(L.disconnectedMsg)
    /** 系统 BLE 错误 */
    data class BleError(val rootCause: Throwable) : BlueError(
        SDKLocale.s("蓝牙系统错误：${rootCause.message}", "BLE system error: ${rootCause.message}", "BLE-Systemfehler: ${rootCause.message}")
    )

    /** 错误恢复建议（中英双语）*/
    val recoverySuggestion: String get() = when (this) {
        is NotInitialized -> L.notInitializedSuggestion
        is NotAuthenticated -> L.notAuthenticatedSuggestion
        is AuthFailed -> L.authFailedSuggestion
        is Timeout -> L.timeoutSuggestion
        is PermissionDenied -> L.permissionDeniedSuggestion
        is InvalidParameter -> L.invalidParameterSuggestion
        is ProtocolError -> L.protocolErrorSuggestion
        is Disconnected -> L.disconnectedSuggestion
        is BleError -> L.bleErrorSuggestion
    }

    /** 跨平台错误码（与 iOS 端对齐）*/
    val code: Int get() = when (this) {
        is NotInitialized -> 1
        is NotAuthenticated -> 2
        is AuthFailed -> 3
        is Timeout -> 4
        is PermissionDenied -> 5
        is InvalidParameter -> 6
        is ProtocolError -> 7
        is BleError -> 8
        is Disconnected -> 9
    }

    /**
     * Whether this error is transient and the operation can be retried
     * 是否为瞬态错误，可以安全重试
     */
    val isRetryable: Boolean get() = when (this) {
        is Timeout -> true
        is ProtocolError -> true
        is BleError -> true
        is Disconnected -> true
        is NotInitialized -> false
        is NotAuthenticated -> false
        is AuthFailed -> false
        is PermissionDenied -> false
        is InvalidParameter -> false
    }

    /** 内部多语言文本 */
    private object L {
        val notInitializedMsg get() = SDKLocale.s("SDK 未初始化，请先调用 initialize()", "SDK not initialized, call initialize() first", "SDK nicht initialisiert, bitte initialize() aufrufen")
        val notAuthenticatedMsg get() = SDKLocale.s("设备未认证，请先完成身份验证", "Device not authenticated", "Gerät nicht authentifiziert")
        val authFailedMsg get() = SDKLocale.s("认证失败，密钥不匹配", "Authentication failed, key mismatch", "Authentifizierung fehlgeschlagen, Schlüssel stimmt nicht")
        val timeoutMsg get() = SDKLocale.s("指令超时，设备未在规定时间内响应", "Command timeout, device did not respond", "Befehl-Timeout, Gerät hat nicht geantwortet")
        val permissionDeniedMsg get() = SDKLocale.s("蓝牙权限未授权", "Bluetooth permission denied", "Bluetooth-Berechtigung verweigert")
        val invalidParameterMsg get() = SDKLocale.s("参数无效", "Invalid parameter", "Ungültiger Parameter")
        val protocolErrorMsg get() = SDKLocale.s("协议错误", "Protocol error", "Protokollfehler")
        val disconnectedMsg get() = SDKLocale.s("设备已断开连接", "Device disconnected", "Gerät getrennt")

        val notInitializedSuggestion get() = SDKLocale.s(
            "请在调用任何 SDK 方法前先执行 BlueSDK.getInstance(context).initialize()",
            "Call BlueSDK.getInstance(context).initialize() before using any SDK method",
            "Rufen Sie BlueSDK.getInstance(context).initialize() auf, bevor Sie SDK-Methoden verwenden")
        val notAuthenticatedSuggestion get() = SDKLocale.s(
            "请等待连接成功后 SDK 自动认证完成，或检查 fixedAuthKey 配置是否正确",
            "Wait for SDK auto-authentication after connection, or check fixedAuthKey configuration",
            "Warten Sie auf die automatische Authentifizierung oder prüfen Sie die fixedAuthKey-Konfiguration")
        val authFailedSuggestion get() = SDKLocale.s(
            "请检查 fixedAuthKey 是否与设备端匹配。如设备已被其他手机绑定，需先对设备执行恢复出厂设置",
            "Check if fixedAuthKey matches the device. If bound to another phone, factory reset the device first",
            "Prüfen Sie den fixedAuthKey. Falls das Gerät an ein anderes Handy gebunden ist, führen Sie einen Werksreset durch")
        val timeoutSuggestion get() = SDKLocale.s(
            "请确认设备在蓝牙有效范围内（≤3米）且电量充足。可尝试重新连接",
            "Ensure device is within 3m range and has sufficient battery. Try reconnecting",
            "Gerät in ≤3m Reichweite mit genug Akku? Versuchen Sie erneut zu verbinden")
        val permissionDeniedSuggestion get() = SDKLocale.s(
            "请在系统设置中授予应用蓝牙和位置权限，Android 12+ 需要 BLUETOOTH_SCAN 和 BLUETOOTH_CONNECT",
            "Grant Bluetooth and location permissions in system settings. Android 12+ requires BLUETOOTH_SCAN and BLUETOOTH_CONNECT",
            "Erteilen Sie Bluetooth- und Standortberechtigungen. Android 12+ benötigt BLUETOOTH_SCAN und BLUETOOTH_CONNECT")
        val invalidParameterSuggestion get() = SDKLocale.s(
            "请检查参数范围：闹钟索引 1~7，小时 0~23，分钟 0~59",
            "Check parameter ranges: alarm index 1~7, hour 0~23, minute 0~59",
            "Parameterbereich prüfen: Alarm-Index 1~7, Stunde 0~23, Minute 0~59")
        val protocolErrorSuggestion get() = SDKLocale.s(
            "通信帧校验失败，可能是蓝牙干扰导致。建议断开重连后重试",
            "Frame CRC check failed, possibly due to interference. Disconnect and retry",
            "Frame-Prüfsumme fehlgeschlagen. Trennen und erneut versuchen")
        val disconnectedSuggestion get() = SDKLocale.s(
            "设备连接已断开。SDK 会自动尝试重连，也可手动调用 connect() 重新连接",
            "Device disconnected. SDK will auto-reconnect, or call connect() manually",
            "Gerät getrennt. SDK versucht automatisch neu zu verbinden, oder connect() manuell aufrufen")
        val bleErrorSuggestion get() = SDKLocale.s(
            "系统蓝牙异常，请确认蓝牙已开启。如问题持续，尝试重启手机蓝牙",
            "BLE system error. Ensure Bluetooth is enabled. If persistent, try toggling Bluetooth",
            "BLE-Systemfehler. Bluetooth aktiviert? Bei anhaltendem Problem Bluetooth neu starten")
    }
}
