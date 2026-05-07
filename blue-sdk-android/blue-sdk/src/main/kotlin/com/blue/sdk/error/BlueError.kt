// BlueError.kt
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK

package com.blue.sdk.error

/**
 * SDK 统一错误类型
 * 所有异步操作通过回调返回，不抛出异常（ARCH-08）
 */
sealed class BlueError(val message: String) {
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
    data class BleError(val cause: Throwable) : BlueError("蓝牙系统错误：${cause.message}")
}
