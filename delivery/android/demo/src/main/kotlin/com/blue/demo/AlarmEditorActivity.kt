package com.blue.demo

import android.graphics.Color
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.blue.sdk.BlueSDK
import com.blue.sdk.enums.TimeFormat
import com.blue.sdk.error.BlueError

class AlarmEditorActivity : AppCompatActivity() {

    private val sdk get() = BlueSDK.getInstance(this)

    private lateinit var weekButtons: MutableList<Button>
    private lateinit var timePicker: android.widget.TimePicker

    private var index = 1
    private var hour = 8
    private var minute = 0
    private var weekMask = 0x7F
    private var isEnabled = true
    private var isSet = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.setDisplayShowHomeEnabled(true)
        setContentView(buildRoot())
        loadExtras()
    }

    override fun onOptionsItemSelected(item: android.view.MenuItem): Boolean {
        if (item.itemId == android.R.id.home) {
            finish()
            return true
        }
        return super.onOptionsItemSelected(item)
    }

    private fun loadExtras() {
        index = intent.getIntExtra("index", 1)
        hour = intent.getIntExtra("hour", 8)
        minute = intent.getIntExtra("minute", 0)
        weekMask = intent.getIntExtra("weekMask", 0x7F)
        // 未设置的槽位 weekMask 可能为 0，默认改为每天
        if (weekMask == 0) weekMask = 0x7F
        isEnabled = intent.getBooleanExtra("isEnabled", true)
        isSet = intent.getBooleanExtra("isSet", false)
        supportActionBar?.title = String.format(S.alarmSlotLabel, index)
        // 设置 TimePicker 初始值时临时移除 listener，避免触发 onChange 覆盖值
        timePicker.setOnTimeChangedListener(null)
        timePicker.hour = hour
        timePicker.minute = minute
        timePicker.setOnTimeChangedListener { _, h, m ->
            this@AlarmEditorActivity.hour = h
            this@AlarmEditorActivity.minute = m
        }
        updateWeekButtons()
    }

    private fun buildRoot(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#1C1C1E"))
            layoutParams = ViewGroup.LayoutParams(MATCH_PARENT, MATCH_PARENT)
        }

        val scrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f)
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(16), dp(20), dp(32))
        }

        timePicker = android.widget.TimePicker(this).apply {
            setIs24HourView(true)  // 协议使用 24H（hour 0~23），编辑器统一 24H 避免混淆
            // 初始值在 loadExtras() 中设置，这里不设 listener 避免初始化时误触发
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(400))
            setBackgroundColor(Color.parseColor("#2C2C2E"))
        }
        content.addView(timePicker)

        content.addView(gap(24))

        val repeatLabel = TextView(this).apply {
            text = S.repeatLabel
            textSize = 15f
            setTextColor(Color.WHITE)
            layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT)
        }
        content.addView(repeatLabel)

        content.addView(gap(12))

        val weekRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(36))
        }

        val days = S.weekdays
        weekButtons = mutableListOf()

        days.forEachIndexed { i, day ->
            val btn = Button(this).apply {
                text = day
                textSize = 14f
                isAllCaps = false
                layoutParams = LinearLayout.LayoutParams(0, dp(36), 1f).apply {
                    if (i > 0) marginStart = dp(6)
                }
                background = android.graphics.drawable.GradientDrawable().apply {
                    shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                    cornerRadius = dp(18).toFloat()
                }
                setOnClickListener { toggleWeek(i) }
            }
            weekButtons.add(btn)
            weekRow.addView(btn)
        }
        content.addView(weekRow)

        content.addView(gap(40))

        val saveBtn = Button(this).apply {
            text = S.saveAlarm
            setTextColor(Color.WHITE)
            isAllCaps = false
            textSize = 17f
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(50))
            background = android.graphics.drawable.GradientDrawable().apply {
                shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                cornerRadius = 12f
                setColor(Color.parseColor("#007AFF"))
            }
            setOnClickListener { saveAlarm() }
        }
        content.addView(saveBtn)

        content.addView(gap(16))

        val deleteBtn = Button(this).apply {
            text = S.deleteAlarm
            setTextColor(Color.parseColor("#FF3B30"))
            isAllCaps = false
            textSize = 15f
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply {
                gravity = Gravity.CENTER
            }
            visibility = if (isSet) View.VISIBLE else View.GONE
            setOnClickListener { deleteAlarm() }
        }
        content.addView(deleteBtn)

        scrollView.addView(content)
        root.addView(scrollView)

        return root
    }

    private fun toggleWeek(dayIndex: Int) {
        weekMask = weekMask xor (1 shl dayIndex)
        if (weekMask == 0) weekMask = 1 shl dayIndex
        updateWeekButtons()
    }

    private fun updateWeekButtons() {
        weekButtons.forEachIndexed { i, btn ->
            val selected = (weekMask and (1 shl i)) != 0
            val bgColor = if (selected) Color.parseColor("#007AFF") else Color.parseColor("#3A3A3C")
            val textColor = if (selected) Color.WHITE else Color.WHITE
            btn.setTextColor(textColor)
            (btn.background as android.graphics.drawable.GradientDrawable).setColor(bgColor)
        }
    }

    private fun saveAlarm() {
        // 防御性检查：weekMask 不能为 0（至少选一天）
        if (weekMask == 0) weekMask = 0x7F
        sdk.setAlarm(index, hour, minute, weekMask) { result ->
            runOnUiThread {
                result.fold(
                    onSuccess = {
                        val intent = android.content.Intent().apply {
                            putExtra("index", index)
                            putExtra("hour", hour)
                            putExtra("minute", minute)
                            putExtra("weekMask", weekMask)
                            putExtra("isEnabled", true)
                            putExtra("isSet", true)
                        }
                        setResult(RESULT_OK, intent)
                        finish()
                    },
                    onFailure = {
                        AlertDialog.Builder(this)
                            .setTitle(S.setAlarmFailed)
                            .setMessage((it as BlueError).message)
                            .setPositiveButton(S.confirm, null)
                            .show()
                    }
                )
            }
        }
    }

    private fun deleteAlarm() {
        sdk.deleteAlarm(index) { result ->
            runOnUiThread {
                result.fold(
                    onSuccess = {
                        val intent = android.content.Intent().apply {
                            putExtra("index", index)
                            putExtra("hour", 0)
                            putExtra("minute", 0)
                            putExtra("weekMask", 0x7F)
                            putExtra("isEnabled", false)
                            putExtra("isSet", false)
                        }
                        setResult(RESULT_OK, intent)
                        finish()
                    },
                    onFailure = {
                        AlertDialog.Builder(this)
                            .setTitle(S.deleteAlarmFailed)
                            .setMessage((it as BlueError).message)
                            .setPositiveButton(S.confirm, null)
                            .show()
                    }
                )
            }
        }
    }

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    private fun gap(dpVal: Int) = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(dpVal))
    }
}
