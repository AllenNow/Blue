package com.blue.demo

import android.graphics.Color
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.ItemTouchHelper
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.blue.sdk.BlueSDK
import com.blue.sdk.error.BlueError

data class AlarmSlot(
    val index: Int,
    var isEnabled: Boolean,
    var hour: Int,
    var minute: Int,
    var weekMask: Int,
    var isSet: Boolean
) {
    val timeString: String get() = if (isSet) String.format("%02d:%02d", hour, minute) else "--:--"
    val weekDescription: String get() {
        if (!isSet) return ""
        if (weekMask == 0x7F) return "每天"
        if (weekMask == 0x1F) return "工作日"
        if (weekMask == 0x60) return "周末"
        val days = listOf("一", "二", "三", "四", "五", "六", "日")
        return (0..6).filter { (weekMask and (1 shl it)) != 0 }.map { days[it] }.joinToString(" ")
    }
}

class AlarmManagerActivity : AppCompatActivity() {

    private val sdk get() = BlueSDK.getInstance(this)
    private lateinit var recyclerView: RecyclerView
    private lateinit var adapter: AlarmSlotAdapter

    private var alarms = (1..7).map { AlarmSlot(it, false, 0, 0, 0x7F, false) }.toMutableList()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        supportActionBar?.title = "闹钟管理"
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.setDisplayShowHomeEnabled(true)
        supportActionBar?.setHomeAsUpIndicator(android.R.drawable.ic_menu_close_clear_cancel)
        supportActionBar?.setDisplayShowTitleEnabled(true)
        supportActionBar?.setCustomView(android.widget.TextView(this).apply {
            text = "清空全部"
            setTextColor(Color.parseColor("#FF3B30"))
            textSize = 17f
            gravity = Gravity.CENTER
            setPadding(dp(16), 0, dp(16), 0)
            setOnClickListener { clearAllAlarms() }
        })
        supportActionBar?.setDisplayShowCustomEnabled(true)
        setContentView(buildRoot())
        setupSwipeToDelete()
    }

    override fun onOptionsItemSelected(item: android.view.MenuItem): Boolean {
        if (item.itemId == android.R.id.home) {
            finish()
            return true
        }
        return super.onOptionsItemSelected(item)
    }

    private fun buildRoot(): View {
        val root = androidx.constraintlayout.widget.ConstraintLayout(this).apply {
            setBackgroundColor(Color.parseColor("#1C1C1E"))
            layoutParams = ViewGroup.LayoutParams(MATCH_PARENT, MATCH_PARENT)
        }

        recyclerView = RecyclerView(this).apply {
            layoutManager = LinearLayoutManager(this@AlarmManagerActivity)
            adapter = AlarmSlotAdapter(alarms) { slot ->
                showEditor(slot)
            }.also { this@AlarmManagerActivity.adapter = it }
            layoutParams = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams(MATCH_PARENT, 0).apply {
                topToTop = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                bottomToBottom = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                leftToLeft = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                rightToRight = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
            }
        }
        root.addView(recyclerView)

        return root
    }

    private fun setupSwipeToDelete() {
        val itemTouchHelper = ItemTouchHelper(object : ItemTouchHelper.SimpleCallback(0, ItemTouchHelper.LEFT) {
            override fun onMove(recyclerView: RecyclerView, viewHolder: RecyclerView.ViewHolder, target: RecyclerView.ViewHolder): Boolean {
                return false
            }

            override fun onSwiped(viewHolder: RecyclerView.ViewHolder, direction: Int) {
                val position = viewHolder.adapterPosition
                val slot = alarms[position]
                if (slot.isSet) {
                    deleteAlarmAt(position)
                } else {
                    adapter.notifyItemChanged(position)
                }
            }

            override fun getSwipeThreshold(viewHolder: RecyclerView.ViewHolder): Float {
                return 0.3f
            }
        })
        itemTouchHelper.attachToRecyclerView(recyclerView)
    }

    private fun showEditor(slot: AlarmSlot) {
        val intent = android.content.Intent(this, AlarmEditorActivity::class.java).apply {
            putExtra("index", slot.index)
            putExtra("hour", slot.hour)
            putExtra("minute", slot.minute)
            putExtra("weekMask", slot.weekMask)
            putExtra("isEnabled", slot.isEnabled)
            putExtra("isSet", slot.isSet)
        }
        startActivityForResult(intent, 100)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 100 && resultCode == RESULT_OK && data != null) {
            val index = data.getIntExtra("index", 0)
            val hour = data.getIntExtra("hour", 0)
            val minute = data.getIntExtra("minute", 0)
            val weekMask = data.getIntExtra("weekMask", 0x7F)
            val isEnabled = data.getBooleanExtra("isEnabled", true)
            val isSet = data.getBooleanExtra("isSet", false)
            updateAlarm(index, hour, minute, weekMask, isEnabled, isSet)
        }
    }

    fun updateAlarm(index: Int, hour: Int, minute: Int, weekMask: Int, isEnabled: Boolean, isSet: Boolean) {
        if (index < 1 || index > 7) return
        alarms[index - 1] = AlarmSlot(index, isEnabled, hour, minute, weekMask, isSet)
        adapter.notifyItemChanged(index - 1)
    }

    private fun deleteAlarmAt(position: Int) {
        val slot = alarms[position]
        sdk.deleteAlarm(slot.index) { result ->
            result.fold(
                onSuccess = {
                    alarms[position] = AlarmSlot(slot.index, false, 0, 0, 0x7F, false)
                    adapter.notifyItemChanged(position)
                },
                onFailure = {
                    adapter.notifyItemChanged(position)
                    android.widget.Toast.makeText(this, (it as BlueError).message, android.widget.Toast.LENGTH_SHORT).show()
                }
            )
        }
    }

    fun clearAllAlarms() {
        AlertDialog.Builder(this)
            .setTitle("清空闹钟")
            .setMessage("确定清空所有闹钟设置？")
            .setNegativeButton("取消", null)
            .setPositiveButton("清空") { _, _ ->
                sdk.clearAllAlarms { result ->
                    result.fold(
                        onSuccess = {
                            alarms = (1..7).map { AlarmSlot(it, false, 0, 0, 0x7F, false) }.toMutableList()
                            adapter.notifyDataSetChanged()
                        },
                        onFailure = { android.widget.Toast.makeText(this, (it as BlueError).message, android.widget.Toast.LENGTH_SHORT).show() }
                    )
                }
            }
            .show()
    }

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    class AlarmSlotAdapter(
        private var items: MutableList<AlarmSlot>,
        private val onItemClick: (AlarmSlot) -> Unit
    ) : RecyclerView.Adapter<AlarmSlotAdapter.ViewHolder>() {

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val ctx = parent.context
            val dp80 = dp(80, ctx)
            val dp16 = dp(16, ctx)
            val dp8 = dp(8, ctx)
            val dp12 = dp(12, ctx)
            return ViewHolder(androidx.constraintlayout.widget.ConstraintLayout(ctx).apply {
                layoutParams = RecyclerView.LayoutParams(MATCH_PARENT, dp80).apply {
                    setMargins(dp16, dp8, dp16, dp8)
                }
                background = android.graphics.drawable.GradientDrawable().apply {
                    shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                    cornerRadius = dp12.toFloat()
                    setColor(Color.parseColor("#2C2C2E"))
                }
            })
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(items[position], onItemClick)
        }

        override fun getItemCount() = items.size

        class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
            private val indexLabel = TextView(itemView.context).apply {
                textSize = 13f
                setTextColor(Color.parseColor("#8E8E93"))
                layoutParams = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply {
                    startToStart = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                    topToTop = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                    marginStart = dp(16, itemView.context)
                    topMargin = dp(12, itemView.context)
                }
            }
            private val timeLabel = TextView(itemView.context).apply {
                textSize = 32f
                typeface = android.graphics.Typeface.MONOSPACE
                layoutParams = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply {
                    startToStart = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                    topToBottom = indexLabel.id
                    marginStart = dp(16, itemView.context)
                    topMargin = dp(4, itemView.context)
                }
            }
            private val weekLabel = TextView(itemView.context).apply {
                textSize = 13f
                setTextColor(Color.parseColor("#8E8E93"))
                layoutParams = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply {
                    startToEnd = timeLabel.id
                    topToBottom = indexLabel.id
                    marginStart = dp(12, itemView.context)
                    topMargin = dp(10, itemView.context)
                }
            }
            private val statusBadge = TextView(itemView.context).apply {
                textSize = 12f
                gravity = Gravity.CENTER
                layoutParams = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams(WRAP_CONTENT, dp(22, itemView.context)).apply {
                    endToStart = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                    topToBottom = indexLabel.id
                    marginEnd = dp(40, itemView.context)
                    topMargin = dp(6, itemView.context)
                }
                background = android.graphics.drawable.GradientDrawable().apply {
                    shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                    cornerRadius = 4f
                }
            }
            private val arrow = android.widget.ImageView(itemView.context).apply {
                setImageDrawable(itemView.context.getDrawable(android.R.drawable.arrow_right))
                layoutParams = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams(dp(24, itemView.context), dp(24, itemView.context)).apply {
                    endToEnd = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                    topToBottom = indexLabel.id
                    marginEnd = dp(16, itemView.context)
                    topMargin = dp(2, itemView.context)
                }
            }

            init {
                val container = itemView as androidx.constraintlayout.widget.ConstraintLayout
                indexLabel.id = View.generateViewId()
                container.addView(indexLabel)
                container.addView(timeLabel)
                container.addView(weekLabel)
                container.addView(statusBadge)
                container.addView(arrow)
            }

            fun bind(slot: AlarmSlot, onClick: (AlarmSlot) -> Unit) {
                indexLabel.text = "闹钟 ${slot.index}"
                timeLabel.text = slot.timeString
                weekLabel.text = slot.weekDescription

                if (slot.isSet) {
                    timeLabel.setTextColor(Color.WHITE)
                    statusBadge.text = if (slot.isEnabled) " 已开启 " else " 已关闭 "
                    val badgeColor = if (slot.isEnabled) Color.parseColor("#34C759") else Color.parseColor("#8E8E93")
                    statusBadge.setTextColor(badgeColor)
                    (statusBadge.background as android.graphics.drawable.GradientDrawable).setColor(
                        adjustAlpha(badgeColor, 0.1f)
                    )
                } else {
                    timeLabel.setTextColor(Color.parseColor("#636366"))
                    statusBadge.text = " 未设置 "
                    statusBadge.setTextColor(Color.parseColor("#636366"))
                    (statusBadge.background as android.graphics.drawable.GradientDrawable).setColor(
                        adjustAlpha(Color.parseColor("#8E8E93"), 0.05f)
                    )
                }

                itemView.setOnClickListener { onClick(slot) }
            }

            private fun adjustAlpha(color: Int, factor: Float): Int {
                val alpha = (Color.alpha(color) * factor).toInt()
                return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
            }

            private fun dp(v: Int, ctx: android.content.Context) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), ctx.resources.displayMetrics).toInt()
        }
    }
}