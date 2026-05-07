package com.blue.sdk

import com.blue.sdk.manager.AuthManager
import org.junit.Assert.assertArrayEquals
import org.junit.Test

class AuthManagerTest {

    /**
     * 验证密钥计算：手机 MAC C7 50 B2 AA C3 F3 + 设备 MAC A6 C0 82 00 A1 C2
     * 期望密钥：07 74（逐字节累加取低字节）
     */
    @Test fun testCalculateKey() {
        val phoneMac = byteArrayOf(0xC7.toByte(), 0x50, 0xB2.toByte(), 0xAA.toByte(), 0xC3.toByte(), 0xF3.toByte())
        val deviceMac = byteArrayOf(0xA6.toByte(), 0xC0.toByte(), 0x82.toByte(), 0x00, 0xA1.toByte(), 0xC2.toByte())
        val key = AuthManager.calculateKey(phoneMac, deviceMac)
        assertArrayEquals(byteArrayOf(0x6D.toByte(), 0x10, 0x34, 0xAA.toByte(), 0x64, 0xB5.toByte()), key)
    }
}
