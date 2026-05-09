package com.blue.sdk

import com.blue.sdk.manager.AuthManager
import com.blue.sdk.transport.CRC8Calculator
import com.blue.sdk.transport.CommandCode
import com.blue.sdk.transport.FrameBuilder
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AuthManagerTest {

    /**
     * 验证协议文档示例：
     * 手机 MAC: C7 50 B2 AA C3 F3
     * 设备 MAC: A6 C0 82 00 A1 C2
     * 期望密钥: 6D 10 34 AA 64 B5
     */
    @Test fun testCalculateKey_protocolExample() {
        val phoneMac = byteArrayOf(0xC7.toByte(), 0x50, 0xB2.toByte(), 0xAA.toByte(), 0xC3.toByte(), 0xF3.toByte())
        val deviceMac = byteArrayOf(0xA6.toByte(), 0xC0.toByte(), 0x82.toByte(), 0x00, 0xA1.toByte(), 0xC2.toByte())
        val key = AuthManager.calculateKey(phoneMac, deviceMac)
        assertArrayEquals(byteArrayOf(0x6D.toByte(), 0x10, 0x34, 0xAA.toByte(), 0x64, 0xB5.toByte()), key)
    }

    /** 验证溢出截断：0xFF + 0xFF = 0x1FE → 取低字节 0xFE */
    @Test fun testCalculateKey_overflow() {
        val phoneMac = byteArrayOf(0xFF.toByte(), 0x00, 0x00, 0x00, 0x00, 0x00)
        val deviceMac = byteArrayOf(0xFF.toByte(), 0x00, 0x00, 0x00, 0x00, 0x00)
        val key = AuthManager.calculateKey(phoneMac, deviceMac)
        assertEquals(0xFE.toByte(), key[0])
        assertEquals(0x00.toByte(), key[1])
    }

    /** 验证全零 MAC */
    @Test fun testCalculateKey_allZero() {
        val phoneMac = ByteArray(6)
        val deviceMac = ByteArray(6)
        val key = AuthManager.calculateKey(phoneMac, deviceMac)
        assertArrayEquals(ByteArray(6), key)
    }

    /** 验证密钥帧格式正确 */
    @Test fun testAuthKeyFrameFormat() {
        val phoneMac = byteArrayOf(0xC7.toByte(), 0x50, 0xB2.toByte(), 0xAA.toByte(), 0xC3.toByte(), 0xF3.toByte())
        val deviceMac = byteArrayOf(0xA6.toByte(), 0xC0.toByte(), 0x82.toByte(), 0x00, 0xA1.toByte(), 0xC2.toByte())
        val key = AuthManager.calculateKey(phoneMac, deviceMac)
        val frame = FrameBuilder.build(CommandCode.AUTH_KEY, key)
        assertEquals(0x55.toByte(), frame[0])
        assertEquals(0xAA.toByte(), frame[1])
        assertEquals(0x00.toByte(), frame[3]) // AUTH_KEY CMD
        assertEquals(0x06.toByte(), frame[5]) // lenLow = 6字节密钥
        assertArrayEquals(byteArrayOf(0x6D.toByte(), 0x10, 0x34, 0xAA.toByte(), 0x64, 0xB5.toByte()),
            frame.copyOfRange(6, 12))
        assertTrue(CRC8Calculator.verify(frame))
    }
}
