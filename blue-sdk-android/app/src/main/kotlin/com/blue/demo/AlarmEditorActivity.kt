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
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.blue.sdk.BlueSDK
import com.blue.sdk.error.BlueError

class AlarmEditorActivity : AppCompatActivity() {

    private val sdk get() = BlueSDK.getInstance(this)

    private lateinit var weekButtons: MutableList<Button>

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
        isEnabled = intent.getBooleanExtra("isEnabled", true)
        isSet = intent.getBooleanExtra("isSet", false)
        supportActionBar?.title = "闹钟 $index"
        updateWeekButtons()
    }

    private fun buildRoot(): View {
        val root = androidx.constraintlayout.widget.ConstraintLayout(this).apply {
            setBackgroundColor(Color.parseColor("#1C1C1E"))
            layoutParams = ViewGroup.LayoutParams(MATCH_PARENT, MATCH_PARENT)
        }

        val timePicker = android.widget.TimePicker(this).apply {
            setIs24HourView(true)
            hour = this@AlarmEditorActivity.hour
            minute = this@AlarmEditorActivity.minute
            setOnTimeChangedListener { _, h, m ->
                this@AlarmEditorActivity.hour = h
                this@AlarmEditorActivity.minute = m
            }
            layoutParams = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams(MATCH_PARENT, dp(200)).apply {
                topToTop = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                leftToLeft = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                rightToRight = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                topMargin = dp(16)
            }
            setBackgroundColor(Color.parseColor("#2C2C2E"))
        }
        root.addView(timePicker)

        val repeatLabel = TextView(this).apply {
            text = "重复"
            textSize = 15f
            setTextColor(Color.WHITE)
            layoutParams = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply {
                topToBottom = timePicker.id
                leftToLeft = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                topMargin = dp(24)
                marginStart = dp(20)
            }
        }
        root.addView(repeatLabel)

        val weekRow = androidx.constraintlayout.widget.ConstraintLayout(this).apply {
            layoutParams = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams(MATCH_PARENT, dp(36)).apply {
                topToBottom = repeatLabel.id
                leftToLeft = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                rightToRight = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                topMargin = dp(12)
                marginStart = dp(20)
                marginEnd = dp(20)
            }
        }

        val days = listOf("一", "二", "三", "四", "五", "六", "日")
        weekButtons = mutableListOf()

        days.forEachIndexed { i, day ->
            val btn = Button(this).apply {
                id = View.generateViewId()
                text = day
                textSize = 14f
                isAllCaps = false
                layoutParams = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams(0, dp(36)).apply {
                    topToTop = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                    bottomToBottom = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                    if (i == 0) {
                        leftToLeft = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                    } else {
                        leftToRight = weekButtons[i - 1].id
                        marginStart = dp(6)
                    }
                    if (i == days.size - 1) {
                        rightToRight = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                    }
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
        root.addView(weekRow)

        val saveBtn = Button(this).apply {
            text = "保存闹钟"
            setTextColor(Color.WHITE)
            isAllCaps = false
            textSize = 17f
            layoutParams = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams(MATCH_PARENT, dp(50)).apply {
                topToBottom = weekRow.id
                leftToLeft = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                rightToRight = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                topMargin = dp(40)
                marginStart = dp(20)
                marginEnd = dp(20)
            }
            background = android.graphics.drawable.GradientDrawable().apply {
                shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                cornerRadius = 12f
                setColor(Color.parseColor("#007AFF"))
            }
            setOnClickListener { saveAlarm() }
        }
        root.addView(saveBtn)

        val deleteBtn = Button(this).apply {
            text = "删除闹钟"
            setTextColor(Color.parseColor("#FF3B30"))
            isAllCaps = false
            textSize = 15f
            layoutParams = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply {
                topToBottom = saveBtn.id
                leftToLeft = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                rightToRight = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                topMargin = dp(16)
                gravity = Gravity.CENTER
            }
            visibility = if (isSet) View.VISIBLE else View.GONE
            setOnClickListener { deleteAlarm() }
        }
        root.addView(deleteBtn)

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
        sdk.setAlarm(index, hour, minute, weekMask) { result ->
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
                        .setTitle("设置失败")
                        .setMessage((it as BlueError).message)
                        .setPositiveButton("确定", null)
                        .show()
                }
            )
        }
    }

    private fun deleteAlarm() {
        sdk.deleteAlarm(index) { result ->
            result.fold(
                onSuccess = {
                    val intent = android.content.Intent().apply {
                        putExtra("index", index)
                        putExtra("isEnabled", false)
                        putExtra("isSet", false)
                    }
                    setResult(RESULT_OK, intent)
                    finish()
                },
                onFailure = {
                    AlertDialog.Builder(this)
                        .setTitle("删除失败")
                        .setMessage((it as BlueError).message)
                        .setPositiveButton("确定", null)
                        .show()
                }
            )
        }
    }

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()
}