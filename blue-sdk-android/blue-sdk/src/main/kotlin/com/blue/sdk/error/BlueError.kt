// BlueError.kt
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK

package com.blue.sdk.error

/**
 * SDK 统一错误类型
 * 继承 Exception 以支持 Result.failure()，所有异步操作通过回调返回，不向上层抛出（ARCH-08）
 */
sealed class BlueError(message: String) : Exception(message) {
    /** SDK 未初始化，需先调用 initialize() */
    object NotInitialized : BlueError("SDK 未初始化，请先调用 initialize()")
    /** 设备未完成认证，需先完成 authenticate() */
    object NotAuthenticated : BlueError("设备未认证，请先完成身份验证")
    /** 认证失败，密钥不匹配 */
    object AuthFailed : BlueError("认证失败，密钥不匹配")
    /** 指令超时（5秒内未收到设备应答）*/
    object Timeout : BlueError("指令超时，设备未在规定时间内响应")
    /** 蓝牙权限未授权 */
    object PermissionDenied : BlueError("蓝牙权限未授权")
    /** 参数无效（如闹钟索引超出 1~7 范围）*/
    object InvalidParameter : BlueError("参数无效")
    /** 协议错误（帧格式异常或 CRC 校验失败）*/
    object ProtocolError : BlueError("协议错误")
    /** 设备已断开连接 */
    object Disconnected : BlueError("设备已断开连接")
    /** 系统 BLE 错误 */
    data class BleError(val rootCause: Throwable) : BlueError("蓝牙系统错误：${rootCause.message}")

    /**
     * 错误恢复建议
     * 向集成方提供明确的下一步操作指引，减少支持工单
     */
    val recoverySuggestion: String get() = when (this) {
        is NotInitialized -> "请在调用任何 SDK 方法前先执行 BlueSDK.getInstance(context).initialize()"
        is NotAuthenticated -> "请等待连接成功后 SDK 自动认证完成，或检查 fixedAuthKey 配置是否正确"
        is AuthFailed -> "请检查 fixedAuthKey 是否与设备端匹配。如设备已被其他手机绑定，需先对设备执行恢复出厂设置"
        is Timeout -> "请确认设备在蓝牙有效范围内（≤3米）且电量充足。可尝试重新连接"
        is PermissionDenied -> "请在系统设置中授予应用蓝牙和位置权限，Android 12+ 需要 BLUETOOTH_SCAN 和 BLUETOOTH_CONNECT"
        is InvalidParameter -> "请检查参数范围：闹钟索引 1~7，小时 0~23，分钟 0~59"
        is ProtocolError -> "通信帧校验失败，可能是蓝牙干扰导致。建议断开重连后重试"
        is Disconnected -> "设备连接已断开。SDK 会自动尝试重连，也可手动调用 connect() 重新连接"
        is BleError -> "系统蓝牙异常，请确认蓝牙已开启。如问题持续，尝试重启手机蓝牙"
    }

    /**
     * 跨平台错误码（与 iOS 端对齐）
     */
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
}
