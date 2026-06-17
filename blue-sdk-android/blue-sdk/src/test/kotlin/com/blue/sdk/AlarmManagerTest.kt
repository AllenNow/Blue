package com.blue.sdk

import com.blue.sdk.manager.AlarmManager
import com.blue.sdk.transport.DPIDConstants
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class AlarmManagerTest {

    /** 验证：解析设备上报闹钟1为07:00 */
    @Test fun testParseAlarmInfo_alarm1_07_00() {
        val data = byteArrayOf(0x66.toByte(), 0x00, 0x00, 0x07, 0x01, 0x07, 0x00, 0x7F.toByte(), 0x00, 0x00, 0x00)
        val alarm = AlarmManager.parseAlarmInfo(data, 1)
        assertNotNull(alarm)
        assertEquals(1, alarm!!.index)
        assertEquals(7, alarm.hour)
        assertEquals(0, alarm.minute)
        assertEquals(0x7F, alarm.weekMask)
    }

    /** 验证：解析设备上报闹钟2为09:00 */
    @Test fun testParseAlarmInfo_alarm2_09_00() {
        val data = byteArrayOf(0x67.toByte(), 0x00, 0x00, 0x07, 0x01, 0x09, 0x00, 0x7F.toByte(), 0x00, 0x00, 0x00)
        val alarm = AlarmManager.parseAlarmInfo(data, 2)
        assertNotNull(alarm)
        assertEquals(9, alarm!!.hour)
        assertEquals(0, alarm.minute)
    }

    /** 验证：数据不足时返回 null */
    @Test fun testParseAlarmInfo_insufficientData() {
        assertNull(AlarmManager.parseAlarmInfo(byteArrayOf(0x66.toByte(), 0x00, 0x00), 1))
    }

    /** 验证：DPID 辅助方法 - 闹钟槽位1~7 */
    @Test fun testAlarmDPID_validRange() {
        assertEquals(0x66.toByte(), DPIDConstants.alarmDPID(1))
        assertEquals(0x67.toByte(), DPIDConstants.alarmDPID(2))
        assertEquals(0x6C.toByte(), DPIDConstants.alarmDPID(7))
    }

    /** 验证：超出范围返回 null */
    @Test fun testAlarmDPID_outOfRange() {
        assertNull(DPIDConstants.alarmDPID(0))
        assertNull(DPIDConstants.alarmDPID(8))
    }

    /** 验证：DPID 反查闹钟槽位 */
    @Test fun testAlarmIndex_validDPID() {
        assertEquals(1, DPIDConstants.alarmIndex(0x66.toByte()))
        assertEquals(7, DPIDConstants.alarmIndex(0x6C.toByte()))
    }

    /** 验证：非闹钟 DPID 返回 null */
    @Test fun testAlarmIndex_invalidDPID() {
        assertNull(DPIDConstants.alarmIndex(0x65.toByte())) // alarmRecord
        assertNull(DPIDConstants.alarmIndex(0x6D.toByte())) // typeOfSound
    }
}
