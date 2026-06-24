package com.blue.demo

import android.graphics.Color
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.LinearLayout
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

    private lateinit var alarms: MutableList<AlarmSlot>

    private val alarmObserver = object : com.blue.sdk.BlueSDKListener {
        override fun onAlarmUpdated(alarm: com.blue.sdk.model.AlarmInfo) {
            runOnUiThread {
                val isSet = !alarm.isDeleted
                updateAlarm(alarm.index, alarm.hour, alarm.minute, alarm.weekMask, isSet, isSet)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        alarms = AlarmStorage.loadAll(this).toMutableList()
        // 注册为 SDK 事件观察者，实时接收设备上报的闹钟变更
        sdk.addObserver(alarmObserver)
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

    override fun onDestroy() {
        super.onDestroy()
        sdk.removeObserver(alarmObserver)
    }

    private fun buildRoot(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#1C1C1E"))
            layoutParams = ViewGroup.LayoutParams(MATCH_PARENT, MATCH_PARENT)
        }

        recyclerView = RecyclerView(this).apply {
            layoutManager = LinearLayoutManager(this@AlarmManagerActivity)
            adapter = AlarmSlotAdapter(alarms) { slot ->
                showEditor(slot)
            }.also { this@AlarmManagerActivity.adapter = it }
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f)
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
        val slot = AlarmSlot(index, isEnabled, hour, minute, weekMask, isSet)
        alarms[index - 1] = slot
        AlarmStorage.save(this, slot)
        adapter.notifyItemChanged(index - 1)
    }

    private fun deleteAlarmAt(position: Int) {
        val slot = alarms[position]
        sdk.deleteAlarm(slot.index) { result ->
            runOnUiThread {
                result.fold(
                    onSuccess = {
                        alarms[position] = AlarmSlot(slot.index, false, 0, 0, 0x7F, false)
                        AlarmStorage.clear(this, slot.index)
                        adapter.notifyItemChanged(position)
                    },
                    onFailure = {
                        adapter.notifyItemChanged(position)
                        android.widget.Toast.makeText(this, (it as BlueError).message, android.widget.Toast.LENGTH_SHORT).show()
                    }
                )
            }
        }
    }

    fun clearAllAlarms() {
        AlertDialog.Builder(this)
            .setTitle(S.clearAlarmsTitle)
            .setMessage(S.clearAlarmsMsg)
            .setNegativeButton(S.cancel, null)
            .setPositiveButton(S.confirm) { _, _ ->
                sdk.clearAllAlarms { result ->
                    runOnUiThread {
                        result.fold(
                            onSuccess = {
                                // 原地修改列表（保持 adapter 引用一致）
                                for (i in alarms.indices) {
                                    alarms[i] = AlarmSlot(i + 1, false, 0, 0, 0x7F, false)
                                }
                                AlarmStorage.clearAll(this)
                                adapter.notifyDataSetChanged()
                            },
                            onFailure = { android.widget.Toast.makeText(this, (it as BlueError).message, android.widget.Toast.LENGTH_SHORT).show() }
                        )
                    }
                }
            }
            .show()
    }

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    class AlarmSlotAdapter(
        private var items: MutableList<AlarmSlot>,
        private val onItemClick: (AlarmSlot) -> Unit
    ) : RecyclerView.Adapter<AlarmSlotAdapter.ViewHolder>() {

        private fun dp(v: Int, ctx: android.content.Context) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), ctx.resources.displayMetrics).toInt()

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val ctx = parent.context
            val dp80 = dp(80, ctx)
            val dp16 = dp(16, ctx)
            val dp8 = dp(8, ctx)
            val dp12 = dp(12, ctx)
            return ViewHolder(LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                layoutParams = RecyclerView.LayoutParams(MATCH_PARENT, dp80).apply {
                    setMargins(dp16, dp8, dp16, dp8)
                }
                background = android.graphics.drawable.GradientDrawable().apply {
                    shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                    cornerRadius = dp12.toFloat()
                    setColor(Color.parseColor("#2C2C2E"))
                }
                setPadding(dp16, dp12, dp16, dp12)
            })
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(items[position], onItemClick)
        }

        override fun getItemCount() = items.size

        class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
            private val leftColumn = LinearLayout(itemView.context).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f).apply {
                    gravity = Gravity.CENTER_VERTICAL
                }
            }
            private val rightColumn = LinearLayout(itemView.context).apply {
                orientation = LinearLayout.HORIZONTAL
                layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply {
                    gravity = Gravity.CENTER_VERTICAL
                }
            }
            private val indexLabel = TextView(itemView.context).apply {
                textSize = 13f
                setTextColor(Color.parseColor("#8E8E93"))
                layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT)
            }
            private val timeLabel = TextView(itemView.context).apply {
                textSize = 32f
                typeface = android.graphics.Typeface.MONOSPACE
                layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply {
                    topMargin = dp(4, itemView.context)
                }
            }
            private val weekLabel = TextView(itemView.context).apply {
                textSize = 13f
                setTextColor(Color.parseColor("#8E8E93"))
                layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply {
                    topMargin = dp(4, itemView.context)
                }
            }
            private val statusBadge = TextView(itemView.context).apply {
                textSize = 12f
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, dp(22, itemView.context)).apply {
                    marginEnd = dp(12, itemView.context)
                }
                background = android.graphics.drawable.GradientDrawable().apply {
                    shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                    cornerRadius = 4f
                }
            }
            private val arrow = android.widget.ImageView(itemView.context).apply {
                setImageDrawable(itemView.context.getDrawable(android.R.drawable.ic_media_next))
                layoutParams = LinearLayout.LayoutParams(dp(24, itemView.context), dp(24, itemView.context))
            }

            init {
                leftColumn.addView(indexLabel)
                leftColumn.addView(timeLabel)
                leftColumn.addView(weekLabel)
                rightColumn.addView(statusBadge)
                rightColumn.addView(arrow)
                (itemView as LinearLayout).addView(leftColumn)
                (itemView as LinearLayout).addView(rightColumn)
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
