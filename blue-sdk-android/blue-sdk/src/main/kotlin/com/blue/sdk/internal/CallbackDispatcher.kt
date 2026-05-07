// CallbackDispatcher.kt
// BlueSDK - 回调派发器：确保所有公开回调在主线程执行（ARCH-06）

package com.blue.sdk.internal

import android.os.Handler
import android.os.Looper

internal object CallbackDispatcher {

    private val mainHandler = Handler(Looper.getMainLooper())

    /** 在主线程派发回调 */
    fun dispatch(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
        } else {
            mainHandler.post(block)
        }
    }
}
