package com.blue.sdk

import com.blue.sdk.transport.CRC8Calculator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CRC8CalculatorTest {

    @Test fun testQueryDeviceInfoFrame() {
        val payload = byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0x01, 0x00, 0x00)
        assertEquals(0x00.toByte(), CRC8Calculator.calculate(payload))
    }

    @Test fun testAuthKeyFrame() {
        val payload = byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0x00, 0x00, 0x02, 0x07, 0x74)
        assertEquals(0x7C.toByte(), CRC8Calculator.calculate(payload))
    }

    @Test fun testTimeSyncRequestFrame() {
        val payload = byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0xE1.toByte(), 0x00, 0x01, 0x00)
        assertEquals(0xE1.toByte(), CRC8Calculator.calculate(payload))
    }

    @Test fun testSetAlarm1Frame() {
        val payload = byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0x06, 0x00, 0x0B,
            0x66.toByte(), 0x00, 0x00, 0x07, 0x01, 0x0C, 0x00, 0x7F.toByte(), 0x00, 0x00, 0x00)
        assertEquals(0x09.toByte(), CRC8Calculator.calculate(payload))
    }

    @Test fun testSetAlarm2Frame() {
        val payload = byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0x06, 0x00, 0x0B,
            0x67.toByte(), 0x00, 0x00, 0x07, 0x01, 0x0F, 0x1E, 0x7F.toByte(), 0x00, 0x00, 0x00)
        assertEquals(0x2B.toByte(), CRC8Calculator.calculate(payload))
    }

    @Test fun testDeleteAlarm7Frame() {
        val payload = byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0x06, 0x00, 0x0B,
            0x6C.toByte(), 0x00, 0x00, 0x07,
            0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(),
            0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte())
        assertEquals(0x7C.toByte(), CRC8Calculator.calculate(payload))
    }

    @Test fun testVerifyValidFrame() {
        val frame = byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0x01, 0x00, 0x00, 0x00)
        assertTrue(CRC8Calculator.verify(frame))
    }

    @Test fun testVerifyInvalidFrame() {
        val frame = byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0x01, 0x00, 0x00, 0xFF.toByte())
        assertFalse(CRC8Calculator.verify(frame))
    }

    @Test fun testEmptyArray() {
        assertEquals(0x00.toByte(), CRC8Calculator.calculate(ByteArray(0)))
    }

    @Test fun testOverflow() {
        assertEquals(0xFE.toByte(), CRC8Calculator.calculate(byteArrayOf(0xFF.toByte(), 0xFF.toByte())))
    }
}
