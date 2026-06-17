package com.blue.demo

import java.util.Locale

/**
 * Demo App 多语言字符串管理
 * 跟随系统语言（与 SDK 默认行为一致）
 */
object S {
    val isZh: Boolean get() = Locale.getDefault().language.startsWith("zh")

    // 主页
    val scan get() = z("扫描", "Scan")
    val stopScan get() = z("停止扫描", "Stop Scan")
    val disconnect get() = z("断开", "Disconnect")
    val notConnected get() = z("未连接", "Not Connected")
    val connecting get() = z("连接中...", "Connecting...")
    val authenticating get() = z("认证中...", "Authenticating...")
    val connected get() = z("已连接", "Connected")
    val reconnecting get() = z("重连中...", "Reconnecting...")
    val scanning get() = z("扫描中...", "Scanning...")
    val scanFailed get() = z("扫描失败", "Scan Failed")
    val connectingAuth get() = z("连接认证中...", "Authenticating...")
    val scanConnecting get() = z("扫描连接中...", "Scanning...")

    val deviceInfo get() = z("设备信息", "Device Info")
    val syncTime get() = z("同步时间", "Sync Time")
    val alarmManager get() = z("闹钟管理", "Alarms")
    val medicationRecords get() = z("用药记录", "Records")
    val protocolTest get() = z("指令验证", "Protocol")
    val faq get() = z("常见问题", "FAQ")
    val clearAlarms get() = z("清空闹钟", "Clear Alarms")
    val restoreFactory get() = z("恢复出厂", "Factory Reset")
    val clearBinding get() = z("清除绑定", "Clear Binding")

    // 铃声/音量/时制
    val soundType get() = z("铃声", "Sound")
    val volume get() = z("音量", "Volume")
    val timeFormat get() = z("时制", "Format")
    val silence get() = z("静音", "Mute")
    val duration get() = z("持续", "Duration")
    val minutes get() = z("分", "min")
    val set get() = z("设置", "Set")
    val low get() = z("低", "Low")
    val medium get() = z("中", "Med")
    val high get() = z("高", "High")

    // 日志
    val log get() = z("日志", "Log")
    val clear get() = z("清空", "Clear")

    // 对话框
    val cancel get() = z("取消", "Cancel")
    val confirm get() = z("确定", "OK")
    val clearAlarmsTitle get() = z("清空闹钟", "Clear Alarms")
    val clearAlarmsMsg get() = z("确定清空所有闹钟？", "Clear all alarms?")
    val restoreFactoryTitle get() = z("恢复出厂", "Factory Reset")
    val restoreFactoryMsg get() = z("确定恢复出厂设置？", "Confirm factory reset?")
    val clearBindingTitle get() = z("清除绑定", "Clear Binding")
    val clearBindingMsg get() = z("清除本地密钥，设备也需恢复出厂。", "Clear local key. Device also needs factory reset.")
    val authFailedTitle get() = z("认证失败", "Auth Failed")
    val authFailedMsg get() = z("密钥不一致，请对设备长按按键恢复出厂设置后重试。", "Key mismatch. Long-press device button to factory reset, then retry.")

    // 连接状态
    val userCancelled get() = z("用户取消连接", "Connection cancelled")
    val disconnected get() = z("已断开", "Disconnected")
    val connectFirst get() = z("请先连接设备", "Connect device first")
    val scanningAuto get() = z("扫描中...（自动密钥）", "Scanning... (auto key)")

    // 操作日志
    val queryingDevice get() = z("查询设备信息...", "Querying device info...")
    val syncingTime get() = z("同步时间...", "Syncing time...")
    val timeSynced get() = z("时间已同步", "Time synced")
    val alarmsCleared get() = z("所有闹钟已清空", "All alarms cleared")
    val restoringFactory get() = z("恢复出厂中...", "Restoring factory...")
    val factoryRestored get() = z("已恢复出厂", "Factory restored")
    val bindingCleared get() = z("本地绑定已清除", "Local binding cleared")
    val sdkStarted get() = z("SDK 已启动", "SDK started")
    val permDenied get() = z("权限未授予", "Permission denied")
    val scanStopped get() = z("扫描已停止", "Scan stopped")
    val found get() = z("发现", "Found")

    private fun z(zh: String, en: String) = if (isZh) zh else en
}
