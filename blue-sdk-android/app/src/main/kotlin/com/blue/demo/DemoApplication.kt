package com.blue.demo

import android.app.Application
import com.blue.sdk.BlueSDK
import com.blue.sdk.enums.LogLevel

class DemoApplication : Application() {
    override fun onCreate() {
        super.onCreate()
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
