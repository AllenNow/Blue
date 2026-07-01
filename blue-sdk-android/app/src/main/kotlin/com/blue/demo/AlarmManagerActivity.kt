package com.blue.demo

import android.graphics.Color
import android.graphics.Typeface
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
import com.blue.sdk.BlueSDKManager
import com.blue.sdk.enums.TimeFormat
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

    /** Format time display based on 12/24 hour format */
    fun formatTime(is24Hour: Boolean): String {
        if (!isSet) return "--:--"
        return if (is24Hour) {
            String.format("%02d:%02d", hour, minute)
        } else {
            val displayHour = when {
                hour == 0 -> 12
                hour > 12 -> hour - 12
                else -> hour
            }
            val amPm = if (hour < 12) S.am else S.pm
            String.format("%d:%02d %s", displayHour, minute, amPm)
        }
    }

    val weekDescription: String get() {
        if (!isSet) return ""
        if (weekMask == 0x7F) return S.weekdayDaily
        if (weekMask == 0x3E) return S.weekdayWeekdays   // bit1~bit5 = Mon~Fri
        if (weekMask == 0x41) return S.weekdayWeekend    // bit0+bit6 = Sun+Sat
        val days = S.weekdays
        return (0..6).filter { (weekMask and (1 shl it)) != 0 }.map { days[it] }.joinToString(" ")
    }
}

class AlarmManagerActivity : AppCompatActivity() {

    private val sdk get() = BlueSDKManager.getInstance(this)
    private lateinit var recyclerView: RecyclerView
    private lateinit var adapter: AlarmSlotAdapter

    private lateinit var alarms: MutableList<AlarmSlot>

    /** Whether currently in 24-hour format */
    private val is24Hour: Boolean get() = sdk.currentTimeFormat == TimeFormat.HOUR_24

    private val alarmObserver = object : com.blue.sdk.BlueSDKListener {
        override fun onAlarmUpdated(alarm: com.blue.sdk.model.AlarmInfo) {
            runOnUiThread {
                val isSet = !alarm.isDeleted
                updateAlarm(alarm.index, alarm.hour, alarm.minute, alarm.weekMask, isSet, isSet)
            }
        }

        override fun onTimeFormatChanged(format: com.blue.sdk.enums.TimeFormat) {
            runOnUiThread {
                // Refresh entire list and next alarm display when time format changes
                adapter.notifyDataSetChanged()
                updateNextAlarm()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        alarms = AlarmStorage.loadAll(this).toMutableList()
        // Register as SDK event observer to receive real-time alarm changes from device
        sdk.addObserver(alarmObserver)
        supportActionBar?.title = S.alarmManager
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.setDisplayShowHomeEnabled(true)
        supportActionBar?.setHomeAsUpIndicator(android.R.drawable.ic_menu_close_clear_cancel)
        supportActionBar?.setDisplayShowTitleEnabled(true)
        supportActionBar?.setCustomView(android.widget.TextView(this).apply {
            text = S.clearAll
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

    override fun onResume() {
        super.onResume()
        // Refresh list on each resume (time format may have changed) and recalculate next alarm
        if (::nextAlarmTimeLabel.isInitialized) {
            adapter.notifyDataSetChanged()
            updateNextAlarm()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        sdk.removeObserver(alarmObserver)
    }

    private lateinit var nextAlarmTimeLabel: TextView
    private lateinit var nextAlarmDescLabel: TextView

    private fun buildRoot(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#1C1C1E"))
            layoutParams = ViewGroup.LayoutParams(MATCH_PARENT, MATCH_PARENT)
        }

        // Top: next alarm card
        val nextCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#2C2C2E"))
            setPadding(dp(20), dp(16), dp(20), dp(16))
        }

        nextCard.addView(TextView(this).apply {
            text = S.nextAlarmTitle
            setTextColor(Color.parseColor("#8E8E93"))
            textSize = 13f
            gravity = Gravity.CENTER
        })

        nextAlarmTimeLabel = TextView(this).apply {
            text = "--:--"
            setTextColor(Color.WHITE)
            textSize = 36f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, dp(4), 0, dp(4))
        }
        nextCard.addView(nextAlarmTimeLabel)

        nextAlarmDescLabel = TextView(this).apply {
            text = S.noActiveAlarms
            setTextColor(Color.parseColor("#8E8E93"))
            textSize = 14f
            gravity = Gravity.CENTER
        }
        nextCard.addView(nextAlarmDescLabel)

        root.addView(nextCard)

        recyclerView = RecyclerView(this).apply {
            layoutManager = LinearLayoutManager(this@AlarmManagerActivity)
            adapter = AlarmSlotAdapter(alarms, { is24Hour }) { slot ->
                showEditor(slot)
            }.also { this@AlarmManagerActivity.adapter = it }
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f)
        }
        root.addView(recyclerView)

        updateNextAlarm()

        return root
    }

    /** Calculate the next alarm to trigger based on current time and enabled alarms */
    private fun updateNextAlarm() {
        val now = java.util.Calendar.getInstance()
        val nowHour = now.get(java.util.Calendar.HOUR_OF_DAY)
        val nowMinute = now.get(java.util.Calendar.MINUTE)
        // Calendar.DAY_OF_WEEK: 1=Sun, 2=Mon ... 7=Sat
        // weekMask bit definition: bit0=Sun, bit1=Mon ... bit6=Sat
        val calDow = now.get(java.util.Calendar.DAY_OF_WEEK) // 1=Sun...7=Sat
        val todayBit = calDow - 1 // 0=Sun, 1=Mon ... 6=Sat

        val activeAlarms = alarms.filter { it.isSet && it.isEnabled }
        if (activeAlarms.isEmpty()) {
            nextAlarmTimeLabel.text = "--:--"
            nextAlarmDescLabel.text = S.noActiveAlarms
            return
        }

        data class Candidate(val slot: AlarmSlot, val minutesAway: Int)
        val candidates = mutableListOf<Candidate>()

        val nowTotalMinutes = nowHour * 60 + nowMinute

        for (alarm in activeAlarms) {
            val alarmTotalMinutes = alarm.hour * 60 + alarm.minute
            var bestMinutesAway = Int.MAX_VALUE

            for (dayOffset in 0..6) {
                val checkDay = (todayBit + dayOffset) % 7
                // Check if this day is in the weekMask
                if (alarm.weekMask and (1 shl checkDay) == 0) continue

                val minutesAway: Int = if (dayOffset == 0) {
                    // Today: only count if alarm time is after current time
                    val diff = alarmTotalMinutes - nowTotalMinutes
                    if (diff <= 0) continue  // Already passed today, check later days
                    diff
                } else {
                    // Future day: full days + alarm time offset
                    dayOffset * 24 * 60 + alarmTotalMinutes - nowTotalMinutes
                }

                bestMinutesAway = minutesAway
                break // Found the nearest occurrence for this alarm
            }

            if (bestMinutesAway != Int.MAX_VALUE) {
                candidates.add(Candidate(alarm, bestMinutesAway))
            }
        }

        val next = candidates.minByOrNull { it.minutesAway }
        if (next == null) {
            nextAlarmTimeLabel.text = "--:--"
            nextAlarmDescLabel.text = S.noActiveAlarms
            return
        }

        nextAlarmTimeLabel.text = if (is24Hour) {
            String.format("%02d:%02d", next.slot.hour, next.slot.minute)
        } else {
            val displayHour = when {
                next.slot.hour == 0 -> 12
                next.slot.hour > 12 -> next.slot.hour - 12
                else -> next.slot.hour
            }
            val amPm = if (next.slot.hour < 12) S.am else S.pm
            String.format("%d:%02d %s", displayHour, next.slot.minute, amPm)
        }

        val hours = next.minutesAway / 60
        val mins = next.minutesAway % 60
        nextAlarmDescLabel.text = if (hours > 0) {
            String.format(S.nextAlarmHoursMins, next.slot.index, hours, mins)
        } else {
            String.format(S.nextAlarmMins, next.slot.index, mins)
        }
    }

    private fun setupSwipeToDelete() {
        val itemTouchHelper = ItemTouchHelper(object : ItemTouchHelper.SimpleCallback(0, ItemTouchHelper.LEFT) {
            override fun onMove(recyclerView: RecyclerView, viewHolder: RecyclerView.ViewHolder, target: RecyclerView.ViewHolder): Boolean {
                return false
            }

            override fun onSwiped(viewHolder: RecyclerView.ViewHolder, direction: Int) {
                val position = viewHolder.bindingAdapterPosition
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
        updateNextAlarm()
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
                        updateNextAlarm()
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
                                // Modify list in place (keep adapter reference consistent)
                                for (i in alarms.indices) {
                                    alarms[i] = AlarmSlot(i + 1, false, 0, 0, 0x7F, false)
                                }
                                AlarmStorage.clearAll(this)
                                adapter.notifyDataSetChanged()
                                updateNextAlarm()
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
        private val is24HourProvider: () -> Boolean,
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
            holder.bind(items[position], is24HourProvider(), onItemClick)
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

            fun bind(slot: AlarmSlot, is24Hour: Boolean, onClick: (AlarmSlot) -> Unit) {
                indexLabel.text = String.format(S.alarmSlotLabel, slot.index)
                timeLabel.text = slot.formatTime(is24Hour)
                weekLabel.text = slot.weekDescription

                if (slot.isSet) {
                    timeLabel.setTextColor(Color.WHITE)
                    statusBadge.text = if (slot.isEnabled) " ${S.alarmStatusOn} " else " ${S.alarmStatusOff} "
                    val badgeColor = if (slot.isEnabled) Color.parseColor("#34C759") else Color.parseColor("#8E8E93")
                    statusBadge.setTextColor(badgeColor)
                    (statusBadge.background as android.graphics.drawable.GradientDrawable).setColor(
                        adjustAlpha(badgeColor, 0.1f)
                    )
                } else {
                    timeLabel.setTextColor(Color.parseColor("#636366"))
                    statusBadge.text = " ${S.alarmStatusUnset} "
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
