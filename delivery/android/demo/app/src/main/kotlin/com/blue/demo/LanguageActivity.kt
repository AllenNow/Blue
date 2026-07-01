package com.blue.demo

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.blue.sdk.BlueSDKManager
import com.blue.sdk.BlueSDKLanguage

/**
 * Language selection page
 * Shown on first launch, saves selection to SharedPreferences
 * Can also be accessed from main page to switch language
 */
class LanguageActivity : AppCompatActivity() {

    companion object {
        private const val PREFS_NAME = "blue_demo_prefs"
        private const val KEY_LANGUAGE = "selected_language"
        private const val KEY_LANGUAGE_SET = "language_has_been_set"

        /** Check if language selection page needs to be shown (first launch) */
        fun needsLanguageSelection(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return !prefs.getBoolean(KEY_LANGUAGE_SET, false)
        }

        /** Load saved language setting and apply to S and SDK */
        fun applySavedLanguage(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val lang = prefs.getString(KEY_LANGUAGE, null)
            S.setUserLanguage(lang, context)
            // Sync SDK language
            val sdkLang = when {
                lang == null -> BlueSDKLanguage.SYSTEM
                lang.startsWith("zh") -> BlueSDKLanguage.ZH
                lang.startsWith("de") -> BlueSDKLanguage.DE
                else -> BlueSDKLanguage.EN
            }
            try { BlueSDKManager.getInstance(context).setLanguage(sdkLang) } catch (_: Exception) {}
        }

        /** Save language selection */
        fun saveLanguage(context: Context, langCode: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(KEY_LANGUAGE, langCode)
                .putBoolean(KEY_LANGUAGE_SET, true)
                .apply()
            S.setUserLanguage(langCode, context)
            // Sync SDK language
            val sdkLang = when {
                langCode.startsWith("zh") -> BlueSDKLanguage.ZH
                langCode.startsWith("de") -> BlueSDKLanguage.DE
                else -> BlueSDKLanguage.EN
            }
            try { BlueSDKManager.getInstance(context).setLanguage(sdkLang) } catch (_: Exception) {}
        }
    }

    /** Whether entered from settings page (vs first launch) */
    private val isFromSettings: Boolean get() = intent.getBooleanExtra("from_settings", false)

    private val bgDark = Color.parseColor("#1C1C1E")
    private val bgCard = Color.parseColor("#2C2C2E")
    private val accentBlue = Color.parseColor("#007AFF")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = bgDark
        window.navigationBarColor = bgDark
        supportActionBar?.hide()
        setContentView(buildUI())
    }

    private fun buildUI(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(bgDark)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT)
            setPadding(dp(32), dp(80), dp(32), dp(40))
        }

        // Title
        root.addView(TextView(this).apply {
            text = "🌐"
            textSize = 48f
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { bottomMargin = dp(16) }
        })
        root.addView(TextView(this).apply {
            text = "Select Language\n选择语言\nSprache wählen"
            textSize = 20f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { bottomMargin = dp(40) }
        })

        // Language options
        root.addView(languageButton("中文", "简体中文", "zh"))
        root.addView(gap(12))
        root.addView(languageButton("English", "English", "en"))
        root.addView(gap(12))
        root.addView(languageButton("Deutsch", "Deutsch", "de"))

        return root
    }

    private fun languageButton(title: String, subtitle: String, langCode: String): View {
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(12).toFloat()
                setColor(bgCard)
            }
            setPadding(dp(20), dp(16), dp(20), dp(16))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
            isClickable = true
            isFocusable = true

            addView(TextView(this@LanguageActivity).apply {
                text = title
                textSize = 18f
                setTextColor(Color.WHITE)
                typeface = Typeface.DEFAULT_BOLD
                layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
            })

            addView(TextView(this@LanguageActivity).apply {
                text = "→"
                textSize = 20f
                setTextColor(accentBlue)
            })

            setOnClickListener {
                saveLanguage(this@LanguageActivity, langCode)
                if (isFromSettings) {
                    // Entered from settings, return and recreate Activity
                    setResult(RESULT_OK)
                    finish()
                } else {
                    // First launch, navigate to main entry
                    startActivity(Intent(this@LanguageActivity, DeviceListActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                    })
                    finish()
                }
            }
        }
    }

    private fun gap(dpVal: Int): View {
        return View(this).apply {
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(dpVal))
        }
    }

    private fun dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
    ).toInt()
}
