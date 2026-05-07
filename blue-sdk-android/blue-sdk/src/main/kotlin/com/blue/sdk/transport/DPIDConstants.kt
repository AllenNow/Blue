// DPIDConstants.kt
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// DPID 功能字节常量定义

package com.blue.sdk.transport

/**
 * DPID 功能字节常量（Data Point ID）
 * 位于数据段第一字节，标识该帧携带的数据类型
 */
internal object DPIDConstants {
    /** 闹钟记录（可下发可上报）含时间戳和用药状态 */
    const val ALARM_RECORD: Byte = 0x65.toByte()
    /** 闹钟1（可下发可上报）byte0-小时 byte1-分钟 byte2-周期使能 byte3-提前状态 */
    const val ALARM_1: Byte = 0x66.toByte()
    /** 闹钟2 */
    const val ALARM_2: Byte = 0x67.toByte()
    /** 闹钟3 */
    const val ALARM_3: Byte = 0x68.toByte()
    /** 闹钟4 */
    const val ALARM_4: Byte = 0x69.toByte()
    /** 闹钟5 */
    const val ALARM_5: Byte = 0x6A.toByte()
    /** 闹钟6 */
    const val ALARM_6: Byte = 0x6B.toByte()
    /** 闹钟7 */
    const val ALARM_7: Byte = 0x6C.toByte()
    /** 声音类型（可下发可上报）1-静音 2-声音A 3-声音B */
    const val TYPE_OF_SOUND: Byte = 0x6D.toByte()
    /** 音量设置（可下发可上报）1-低 2-中 3-高
     * ⚠️ 协议文档注释为"提醒持续时间"，但示例帧 6E 04 00 01 01 实为音量设置，以示例帧为准 */
    const val VOLUME_LEVEL: Byte = 0x6E.toByte()
    /** 铃声类型设置（可下发可上报）1-类型A 2-类型B 3-类型C
     * ⚠️ 协议文档注释为"用药结果通知"，但示例帧 6F 04 00 01 01 实为铃声类型，以示例帧为准 */
    const val SOUND_TYPE_SETTING: Byte = 0x6F.toByte()
    /** 提醒持续时间（可下发可上报）
     * ⚠️ 协议文档注释为"清空所有闹钟"，但示例帧 70 02 00 04 ... 实为持续时间，以示例帧为准 */
    const val ALERT_DURATION_SETTING: Byte = 0x70.toByte()
    /** 设备恢复出厂配置（只下发）*/
    const val RESTORE_FACTORY: Byte = 0x71.toByte()
    /** 时制（可下发可上报）0-12小时制 1-24小时制 */
    const val TIME_FORMAT: Byte = 0x73.toByte()
    /** 当前闹钟静音（可下发可上报）0-静音关 1-静音开 */
    const val SILENCE: Byte = 0x74.toByte()
    /** 设备低电（只上报）1-设备低电 */
    const val LOW_BAT: Byte = 0x75.toByte()

    /**
     * 根据闹钟槽位索引（1~7）获取对应的 DPID
     * @param index 闹钟槽位，范围 1~7
     * @return 对应的 DPID 值，索引无效时返回 null
     */
    fun alarmDPID(index: Int): Byte? {
        if (index < 1 || index > 7) return null
        return (ALARM_1.toInt() and 0xFF + index - 1).toByte()
    }

    /**
     * 根据 DPID 获取闹钟槽位索引（1~7）
     * @param dpid DPID 值
     * @return 闹钟槽位索引，非闹钟 DPID 时返回 null
     */
    fun alarmIndex(dpid: Byte): Int? {
        val d = dpid.toInt() and 0xFF
        val a1 = ALARM_1.toInt() and 0xFF
        val a7 = ALARM_7.toInt() and 0xFF
        if (d < a1 || d > a7) return null
        return d - a1 + 1
    }
}
