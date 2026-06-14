package com.blue.sdk

import com.blue.sdk.transport.FrameBuilder
import com.blue.sdk.transport.FrameParser
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class FrameParserTest {

    @Test fun testParseQueryDeviceInfoFrame() {
        val frame = byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0x01, 0x00, 0x00, 0x00)
        val result = FrameParser.parse(frame)
        assertNotNull(result)
        assertEquals(0x01.toByte(), result!!.cmd)
        assertEquals(0, result.data.size)
    }

    @Test fun testParseTimeSyncFrame() {
        val frame = byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0xE1.toByte(), 0x00, 0x01, 0x00, 0xE1.toByte())
        val result = FrameParser.parse(frame)
        assertNotNull(result)
        assertEquals(0xE1.toByte(), result!!.cmd)
        assertArrayEquals(byteArrayOf(0x00), result.data)
    }

    @Test fun testRoundTrip() {
        val originalData = byteArrayOf(0x66.toByte(), 0x08, 0x00, 0x7F.toByte(), 0x00)
        val frame = FrameBuilder.build(0x06, originalData)
        val result = FrameParser.parse(frame)
        assertNotNull(result)
        assertEquals(0x06.toByte(), result!!.cmd)
        assertArrayEquals(originalData, result.data)
    }

    @Test fun testInvalidHeader() {
        assertNull(FrameParser.parse(byteArrayOf(0x11, 0x22, 0x00, 0x01, 0x00, 0x00, 0x00)))
    }

    @Test fun testInvalidCRC() {
        assertNull(FrameParser.parse(byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0x01, 0x00, 0x00, 0xFF.toByte())))
    }

    @Test fun testTooShortFrame() {
        assertNull(FrameParser.parse(byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00)))
    }

    @Test fun testEmptyFrame() {
        assertNull(FrameParser.parse(ByteArray(0)))
    }

    @Test fun testLengthMismatch() {
        assertNull(FrameParser.parse(byteArrayOf(0x55.toByte(), 0xAA.toByte(), 0x00, 0x01, 0x00, 0x02, 0x00, 0x00)))
    }
}
