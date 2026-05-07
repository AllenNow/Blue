package com.blue.sdk.enums

/** BLE 连接状态枚举（ARCH-07：所有状态变更通过 ConnectionManager 统一管理）*/
enum class ConnectionState {
    /** 已断开（初始状态）*/
    DISCONNECTED,
    /** 连接中 */
    CONNECTING,
    /** 已连接（未认证）*/
    CONNECTED,
    /** 已认证（可执行业务指令）*/
    AUTHENTICATED,
    /** 重连中（断线后自动重连）*/
    RECONNECTING
}
