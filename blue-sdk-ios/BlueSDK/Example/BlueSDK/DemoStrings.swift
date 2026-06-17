// DemoStrings.swift
// BlueSDK Example - Demo App 多语言字符串
// 跟随 SDKLocale 设置

import Foundation
import BlueSDK

/// Demo App 多语言字符串
enum S {
    static var isZh: Bool { SDKLocale.isZh }

    // 主页按钮
    static var scan: String { z("扫描", "Scan") }
    static var stopScan: String { z("停止扫描", "Stop") }
    static var disconnect: String { z("断开", "Disconnect") }
    static var deviceInfo: String { z("设备信息", "Device") }
    static var syncTime: String { z("同步时间", "Sync Time") }
    static var alarmManager: String { z("闹钟管理", "Alarms") }
    static var medicationRecords: String { z("用药记录", "Records") }
    static var protocolTest: String { z("指令验证", "Protocol") }
    static var faq: String { z("常见问题", "FAQ") }
    static var clearAlarms: String { z("清空闹钟", "Clear Alarms") }
    static var restoreFactory: String { z("恢复出厂", "Reset") }
    static var clearBinding: String { z("清除绑定", "Unbind") }
    static var debug: String { z("调试", "Debug") }

    // 音频设置标签
    static var soundType: String { z("铃声", "Sound") }
    static var volume: String { z("音量", "Vol") }
    static var timeFormat: String { z("时制", "Format") }
    static var silence: String { z("静音", "Mute") }
    static var duration: String { z("持续", "Dur") }
    static var minutes: String { z("分", "min") }
    static var setBtn: String { z("设置", "Set") }

    // 日志区
    static var log: String { z("日志", "Log") }
    static var clear: String { z("清空", "Clear") }

    // 状态
    static var notConnected: String { z("未连接", "Not Connected") }
    static var connecting: String { z("连接中...", "Connecting...") }
    static var authenticating: String { z("认证中...", "Authenticating...") }
    static var connected: String { z("已连接", "Connected") }
    static var reconnecting: String { z("重连中...", "Reconnecting...") }
    static var scanning: String { z("扫描中...", "Scanning...") }
    static var scanFailed: String { z("扫描失败", "Scan Failed") }
    static var scanConnecting: String { z("扫描连接中...", "Scanning...") }
    static var connectingAuth: String { z("连接认证中...", "Authenticating...") }
    static var userCancelled: String { z("用户取消连接", "Cancelled") }
    static var sdkStarted: String { z("SDK 已启动", "SDK started") }

    // 对话框
    static var cancel: String { z("取消", "Cancel") }
    static var confirm: String { z("确定", "OK") }
    static var clearAlarmsTitle: String { z("清空闹钟", "Clear Alarms") }
    static var clearAlarmsMsg: String { z("确定清空所有闹钟？", "Clear all alarms?") }
    static var restoreFactoryTitle: String { z("恢复出厂", "Factory Reset") }
    static var restoreFactoryMsg: String { z("确定恢复出厂设置？", "Confirm factory reset?") }
    static var clearBindingTitle: String { z("清除绑定", "Clear Binding") }
    static var clearBindingMsg: String { z("清除本地密钥，设备也需恢复出厂。", "Clear local key. Device also needs factory reset.") }

    // 日志消息
    static var alarmsCleared: String { z("所有闹钟已清空", "All alarms cleared") }
    static var factoryRestored: String { z("已恢复出厂", "Factory restored") }
    static var bindingCleared: String { z("本地绑定已清除", "Binding cleared") }

    private static func z(_ zh: String, _ en: String) -> String { isZh ? zh : en }
}
