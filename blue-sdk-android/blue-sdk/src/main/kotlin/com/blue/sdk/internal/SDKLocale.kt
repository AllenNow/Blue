// SDKLocale.kt
// BlueSDK - SDK 内部语言工具
// BlueSDK - SDK internal locale utility
// 默认跟随系统，可通过 BlueSDKConfig.language 覆盖
// Defaults to system language, can be overridden via BlueSDKConfig.language

package com.blue.sdk.internal

import com.blue.sdk.BlueSDKLanguage
import java.util.Locale

/**
 * SDK 语言判断工具
 * SDK locale utility
 * - 默认跟随系统 Locale / Defaults to system Locale
 * - 可通过 setLanguage() 强制指定 / Can be forced via setLanguage()
 */
internal object SDKLocale {

    enum class Lang { ZH, EN, DE }

    @Volatile
    private var forced: BlueSDKLanguage = BlueSDKLanguage.SYSTEM

    /** 由 BlueSDK.initialize() 调用 / Called by BlueSDK.initialize() */
    fun setLanguage(language: BlueSDKLanguage) {
        forced = language
    }

    /** 当前语言 / Current language */
    val current: Lang get() = when (forced) {
        BlueSDKLanguage.ZH -> Lang.ZH
        BlueSDKLanguage.EN -> Lang.EN
        BlueSDKLanguage.DE -> Lang.DE
        BlueSDKLanguage.SYSTEM -> {
            val sysLang = Locale.getDefault().language
            when {
                sysLang.startsWith("zh") -> Lang.ZH
                sysLang.startsWith("de") -> Lang.DE
                else -> Lang.EN
            }
        }
    }

    /** 当前是否使用中文 / Whether currently using Chinese */
    val isZh: Boolean get() = current == Lang.ZH

    /** 当前是否使用德语 / Whether currently using German */
    val isDe: Boolean get() = current == Lang.DE

    /** 双语便利方法（中/英）/ Bilingual convenience (zh/en) */
    fun s(zh: String, en: String): String = if (isZh) zh else en

    /** 三语便利方法（中/英/德）/ Trilingual convenience (zh/en/de) */
    fun s(zh: String, en: String, de: String): String = when (current) {
        Lang.ZH -> zh
        Lang.EN -> en
        Lang.DE -> de
    }
}
