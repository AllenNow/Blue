package com.blue.demo

import android.app.Application
import androidx.appcompat.app.AppCompatDelegate
import com.blue.sdk.BlueSDK
import com.blue.sdk.enums.LogLevel

class DemoApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // 强制深色模式，保证 AlertDialog 等系统弹窗与手写深色 UI 一致
        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
        // 加载用户语言设置（必须在 SDK 初始化之前）
        LanguageActivity.applySavedLanguage(this)
        // 初始化 SDK（在 Application 中调用一次）
        BlueSDK.getInstance(this).initialize()
        // 开发阶段开启 DEBUG 日志
        BlueSDK.getInstance(this).setLogLevel(LogLevel.DEBUG)
    }

    override fun onTerminate() {
        super.onTerminate()
        BlueSDK.getInstance(this).destroy()
    }
}
