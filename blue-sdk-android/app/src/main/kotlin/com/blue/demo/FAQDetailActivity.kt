package com.blue.demo

import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.*
import androidx.appcompat.app.AppCompatActivity

/**
 * FAQ detail page — shows question and answer
 */
class FAQDetailActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        supportActionBar?.title = S.faqTitle
        supportActionBar?.setDisplayHomeAsUpEnabled(true)

        val question = intent.getStringExtra("question") ?: ""
        val answer = intent.getStringExtra("answer") ?: ""
        val category = intent.getStringExtra("category") ?: ""

        setContentView(buildUI(question, answer, category))
    }

    override fun onSupportNavigateUp(): Boolean { finish(); return true }

    private fun buildUI(question: String, answer: String, category: String): View {
        val scroll = ScrollView(this).apply { setBackgroundColor(Color.BLACK) }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(20), dp(20), dp(40))
        }

        // Question title
        content.addView(TextView(this).apply {
            text = question
            setTextColor(Color.WHITE)
            textSize = 18f
            typeface = Typeface.DEFAULT_BOLD
        })

        // Category label
        content.addView(TextView(this).apply {
            text = category
            setTextColor(Color.GRAY)
            textSize = 13f
            setPadding(0, dp(8), 0, dp(16))
        })

        // Divider
        content.addView(View(this).apply {
            setBackgroundColor(Color.parseColor("#3A3A3C"))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(1)).apply { bottomMargin = dp(16) }
        })

        // Answer content
        content.addView(TextView(this).apply {
            text = answer
            setTextColor(Color.parseColor("#E5E5E7"))
            textSize = 15f
            setLineSpacing(dp(4).toFloat(), 1f)
        })

        scroll.addView(content)
        return scroll
    }

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()
}
