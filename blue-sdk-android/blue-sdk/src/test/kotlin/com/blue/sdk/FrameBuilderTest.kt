package com.blue.sdk

import com.blue.sdk.transport.CRC8Calculator
import com.blue.sdk.transport.FrameBuilder
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FrameBuilderTest {

    @Test fun testQueryDeviceInfoFrame() {
        val frame = FrameBuilder.build(0x01)
        assertArrayEquals(byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0x01, 0x00, 0x00, 0x00), frame)
    }

    @Test fun testTimeSyncRequestFrame() {
        val frame = FrameBuilder.build(0xE1.toByte(), byteArrayOf(0x00))
        assertArrayEquals(byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0xE1.toByte(), 0x00, 0x01, 0x00, 0xE1.toByte()), frame)
    }

    @Test fun testAuthKeyFrame() {
        val frame = FrameBuilder.build(0x00, byteArrayOf(0x07, 0x74))
        assertArrayEquals(byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0x00, 0x00, 0x02, 0x07, 0x74, 0x7C.toByte()), frame)
    }

    @Test fun testSetAlarm1Frame() {
        val data = byteArrayOf(0x66.toByte(), 0x00, 0x00, 0x07, 0x01, 0x0C, 0x00, 0x7F.toByte(), 0x00, 0x00, 0x00)
        val frame = FrameBuilder.build(0x06, data)
        val expected = byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0x06, 0x00, 0x0B,
            0x66.toByte(), 0x00, 0x00, 0x07, 0x01, 0x0C, 0x00, 0x7F.toByte(), 0x00, 0x00, 0x00, 0x09)
        assertArrayEquals(expected, frame)
    }

    @Test fun testLargeDataLenHighByte() {
        val data = ByteArray(256)
        val frame = FrameBuilder.build(0x06, data)
        assertEquals(0x01.toByte(), frame[4]) // lenHigh
        assertEquals(0x00.toByte(), frame[5]) // lenLow
        assertEquals(256 + 7, frame.size)
    }

    @Test fun testFrameCRC8IsCorrect() {
        val frame = FrameBuilder.build(0x01)
        assertTrue(CRC8Calculator.verify(frame))
    }
}
