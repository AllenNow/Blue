package com.blue.sdk

import com.blue.sdk.enums.ConnectionState
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * ConnectionState 枚举值验证
 * ConnectionManager 的完整状态机测试需要 Android 环境（BluetoothAdapter），
 * 此处仅验证枚举定义和状态值的正确性
 */
class ConnectionManagerStateTest {

    @Test fun testConnectionStateValues() {
        assertEquals(5, ConnectionState.values().size)
        assertEquals(ConnectionState.DISCONNECTED, ConnectionState.values()[0])
        assertEquals(ConnectionState.CONNECTING, ConnectionState.values()[1])
        assertEquals(ConnectionState.CONNECTED, ConnectionState.values()[2])
        assertEquals(ConnectionState.AUTHENTICATED, ConnectionState.values()[3])
        assertEquals(ConnectionState.RECONNECTING, ConnectionState.values()[4])
    }

    @Test fun testConnectionStateNames() {
        assertEquals("DISCONNECTED", ConnectionState.DISCONNECTED.name)
        assertEquals("AUTHENTICATED", ConnectionState.AUTHENTICATED.name)
        assertEquals("RECONNECTING", ConnectionState.RECONNECTING.name)
    }
}
