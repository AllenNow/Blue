package com.blue.sdk.transport

internal object DPIDConstants {
    // 用药记录
    const val ALARM_RECORD: Byte = 0x65.toByte()
    
    // 闹钟槽位 1~7
    const val ALARM_1: Byte = 0x66.toByte()
    const val ALARM_2: Byte = 0x67.toByte()
    const val ALARM_3: Byte = 0x68.toByte()
    const val ALARM_4: Byte = 0x69.toByte()
    const val ALARM_5: Byte = 0x6A.toByte()
    const val ALARM_6: Byte = 0x6B.toByte()
    const val ALARM_7: Byte = 0x6C.toByte()
    
    // 声音类型上报（设备→APP）DPID_TYPEOFSOUND
    // 设备上报值：1=静音, 2=声音A, 3=声音B
    const val TYPE_OF_SOUND: Byte = 0x6D.toByte()
    
    // 音量设置（APP→设备）
    // 帧格式：6E 04 00 01 XX（01低/02中/03高）
    const val ALERT_DURATION: Byte = 0x6E.toByte()
    
    // 铃声类型设置（APP→设备）/ 用药结果通知
    // APP下发铃声：6F 04 00 01 XX（01=A/02=B/03=C）
    const val NOTIFICATION_OF_RESULTS: Byte = 0x6F.toByte()
    
    // 提醒持续时间设置 / 清空所有闹钟
    // 帧示例：70 02 00 04 00 00 00 XX（分钟数）
    const val EMPTY_ALL_ALARMS: Byte = 0x70.toByte()
    
    // 恢复出厂（只下发）
    // DPID = 0x71
    const val RESTORE_FACTORY: Byte = 0x71.toByte()
    
    // 时制（0=12H, 1=24H）
    const val TIME_FORMAT: Byte = 0x73.toByte()
    
    // 当前闹钟静音（0=关, 1=开）
    const val SILENCE: Byte = 0x74.toByte()
    
    // 设备低电（只上报）
    const val LOW_BAT: Byte = 0x75.toByte()
    
    fun alarmDPID(index: Int): Byte? {
        if (index < 1 || index > 7) return null
        return (ALARM_1.toInt() + index - 1).toByte()
    }
    
    fun alarmIndex(dpid: Byte): Int? {
        val idx = (dpid.toInt() and 0xFF) - (ALARM_1.toInt() and 0xFF) + 1
        return if (idx in 1..7) idx else null
    }
}
