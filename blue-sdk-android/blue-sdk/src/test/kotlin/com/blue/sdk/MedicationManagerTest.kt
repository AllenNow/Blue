package com.blue.sdk

import com.blue.sdk.enums.MedicationStatus
import com.blue.sdk.manager.MedicationManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class MedicationManagerTest {

    /** 验证：解析用药事件（响铃，byte10=0x01=TAKEN）*/
    @Test fun testParseMedicationEvent_taken() {
        val data = byteArrayOf(0x68.toByte(), 0x00, 0x00, 0x07, 0x01, 0x00, 0x12, 0x7F.toByte(), 0x01, 0x00, 0x01)
        val result = MedicationManager.parseMedicationEvent(data)
        assertNotNull(result)
        assertEquals(3, result!!.first) // alarm3
        assertEquals(MedicationStatus.TAKEN, result.second)
    }

    /** 验证：超时取药（byte10=0x02=TIMEOUT）*/
    @Test fun testParseMedicationEvent_timeout() {
        val data = byteArrayOf(0x68.toByte(), 0x00, 0x00, 0x07, 0x01, 0x00, 0x12, 0x7F.toByte(), 0x01, 0x01, 0x02)
        val result = MedicationManager.parseMedicationEvent(data)
        assertEquals(MedicationStatus.TIMEOUT, result?.second)
    }

    /** 验证：漏服（byte10=0x03=MISSED）*/
    @Test fun testParseMedicationEvent_missed() {
        val data = byteArrayOf(0x68.toByte(), 0x00, 0x00, 0x07, 0x01, 0x00, 0x12, 0x7F.toByte(), 0x01, 0x01, 0x03)
        val result = MedicationManager.parseMedicationEvent(data)
        assertEquals(MedicationStatus.MISSED, result?.second)
    }

    /** 验证：提前取药（byte10=0x04=EARLY）*/
    @Test fun testParseMedicationEvent_early() {
        val data = byteArrayOf(0x68.toByte(), 0x00, 0x00, 0x07, 0x01, 0x00, 0x12, 0x7F.toByte(), 0x01, 0x01, 0x04)
        val result = MedicationManager.parseMedicationEvent(data)
        assertEquals(MedicationStatus.EARLY, result?.second)
    }

    /** 验证：数据不足时返回 null */
    @Test fun testParseMedicationEvent_insufficientData() {
        assertNull(MedicationManager.parseMedicationEvent(byteArrayOf(0x68.toByte(), 0x00)))
    }

    /** 验证：解析用药记录（DPID=0x65）
     * 数据格式（15字节）：
     *   [0]=DPID(0x65) [1-3]=type/len(00 00 0B)
     *   [4]=闹钟DP点 [5-6]=年(高低) [7]=月 [8]=日
     *   [9]=闹钟小时 [10]=闹钟分钟 [11]=响铃小时 [12]=响铃分钟
     *   [13]=状态(01取药/02超时/03漏服/04提前) [14]=提前标志
     */
    @Test fun testParseMedicationRecord() {
        // data[4]=0x68(alarm3), data[5-6]=0x07E9(2025年), data[7]=0x0B(11月), data[8]=0x01(1日)
        // data[9]=0x08(闹钟8时), data[10]=0x00(闹钟0分), data[11]=0x08(响铃8时), data[12]=0x05(响铃5分)
        // data[13]=0x01(TAKEN), data[14]=0x00(未提前)
        val data = byteArrayOf(0x65.toByte(), 0x00, 0x00, 0x0B, 0x68.toByte(),
            0x07, 0xE9.toByte(), 0x0B, 0x01, 0x08, 0x00, 0x08, 0x05, 0x01, 0x00)
        val record = MedicationManager.parseMedicationRecord(data)
        assertNotNull(record)
        assertEquals(3, record!!.alarmIndex)
        assertEquals(8, record.alarmHour)
        assertEquals(0, record.alarmMinute)
        assertEquals(MedicationStatus.TAKEN, record.status)
        assert(record.timestamp > 0)
    }

    /** 验证：MedicationStatus 枚举值 */
    @Test fun testMedicationStatusFromByte() {
        assertEquals(MedicationStatus.TAKEN,   MedicationStatus.fromByte(0x01))
        assertEquals(MedicationStatus.TIMEOUT, MedicationStatus.fromByte(0x02))
        assertEquals(MedicationStatus.MISSED,  MedicationStatus.fromByte(0x03))
        assertEquals(MedicationStatus.EARLY,   MedicationStatus.fromByte(0x04))
        assertNull(MedicationStatus.fromByte(0x00))
        assertNull(MedicationStatus.fromByte(0x05))
    }
}
