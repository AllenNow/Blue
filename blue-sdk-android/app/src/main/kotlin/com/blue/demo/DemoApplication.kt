package com.blue.demo

import android.app.Application
import androidx.appcompat.app.AppCompatDelegate
import com.blue.sdk.BlueSDKManager
import com.blue.sdk.enums.LogLevel

class DemoApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Force dark mode to ensure AlertDialog and system popups match hand-written dark UI
        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
        // Initialize multi-language strings (loaded from assets/locales/*.json)
        S.init(this)
        // Load user language setting
        LanguageActivity.applySavedLanguage(this)
        // Initialize SDK (call once in Application)
        BlueSDKManager.getInstance(this).initialize()
        // Enable DEBUG logs during development
        BlueSDKManager.getInstance(this).setLogLevel(LogLevel.DEBUG)
    }

    override fun onTerminate() {
        super.onTerminate()
        BlueSDKManager.getInstance(this).destroy()
    }
}
