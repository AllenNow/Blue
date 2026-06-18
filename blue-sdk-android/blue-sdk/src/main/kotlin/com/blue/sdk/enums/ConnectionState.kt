// ConnectionState.kt
// BlueSDK - BLE 连接状态枚举
// BlueSDK - BLE connection state enum

package com.blue.sdk.enums

/**
 * BLE 连接状态枚举（ARCH-07：所有状态变更通过 ConnectionManager 统一管理）
 * BLE connection state enum (ARCH-07: all state changes managed via ConnectionManager)
 */
enum class ConnectionState {
    /** 已断开（初始状态）/ Disconnected (initial state) */
    DISCONNECTED,
    /** 连接中 / Connecting */
    CONNECTING,
    /** 已连接（未认证）/ Connected (not authenticated) */
    CONNECTED,
    /** 已认证（可执行业务指令）/ Authenticated (ready for commands) */
    AUTHENTICATED,
    /** 重连中（断线后自动重连）/ Reconnecting (auto-reconnect after disconnect) */
    RECONNECTING
}
