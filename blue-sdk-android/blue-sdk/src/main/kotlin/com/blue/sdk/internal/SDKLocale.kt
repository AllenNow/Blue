// SDKLocale.kt
// BlueSDK - SDK 内部语言工具
// 默认跟随系统，可通过 BlueSDKConfig.language 覆盖

package com.blue.sdk.internal

import com.blue.sdk.BlueSDKLanguage
import java.util.Locale

/**
 * SDK 语言判断工具
 * - 默认跟随系统 Locale
 * - 可通过 setLanguage() 强制指定
 */
internal object SDKLocale {

    @Volatile
    private var forced: BlueSDKLanguage = BlueSDKLanguage.SYSTEM

    /** 由 BlueSDK.initialize() 调用 */
    fun setLanguage(language: BlueSDKLanguage) {
        forced = language
    }

    /** 当前是否使用中文 */
    val isZh: Boolean get() = when (forced) {
        BlueSDKLanguage.ZH -> true
        BlueSDKLanguage.EN -> false
        BlueSDKLanguage.SYSTEM -> Locale.getDefault().language.startsWith("zh")
    }

    /** 便利方法：根据当前语言选择文本 */
    fun s(zh: String, en: String): String = if (isZh) zh else en
}
