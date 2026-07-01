package com.blue.demo

import android.app.DatePickerDialog
import android.graphics.Color
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.*
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import java.text.SimpleDateFormat
import java.util.*

class MedicationRecordsActivity : AppCompatActivity() {

    private lateinit var segmentControl: ToggleButtonGroup
    private lateinit var datePickerBtn: Button
    private lateinit var summaryLabel: TextView
    private lateinit var recyclerView: RecyclerView
    private lateinit var emptyLabel: TextView
    private lateinit var adapter: MedicationRecordAdapter

    private var records = emptyList<MedicationEntry>()
    private val db by lazy { MedicationDatabase.getInstance(this) }
    private val dateFormatter: SimpleDateFormat get() {
        val pattern = if (sdk.currentTimeFormat == com.blue.sdk.enums.TimeFormat.HOUR_12) "h:mm a" else "HH:mm"
        return SimpleDateFormat(pattern, Locale.getDefault())
    }
    private val fullDateFormat: SimpleDateFormat get() = when {
        S.isZh -> SimpleDateFormat("yyyy年M月d日", Locale.CHINESE)
        S.isDe -> SimpleDateFormat("d. MMMM yyyy", Locale.GERMAN)
        else -> SimpleDateFormat("MMM d, yyyy", Locale.ENGLISH)
    }
    private val shortDateFormat: SimpleDateFormat get() {
        val pattern = if (sdk.currentTimeFormat == com.blue.sdk.enums.TimeFormat.HOUR_12) "M/d h:mm a" else "M/d HH:mm"
        return SimpleDateFormat(pattern, Locale.getDefault())
    }

    private var selectedDate = System.currentTimeMillis()
    private var showAllRecords = false

    private val sdk get() = com.blue.sdk.BlueSDKManager.getInstance(this)

    private val medicationObserver = object : com.blue.sdk.BlueSDKListener {
        override fun onMedicationRecordReported(record: com.blue.sdk.model.MedicationRecord) {
            runOnUiThread { loadRecords() }
        }
        override fun onMedicationResult(alarmIndex: Int, status: com.blue.sdk.enums.MedicationStatus) {
            runOnUiThread { loadRecords() }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        supportActionBar?.title = S.medicationRecords
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.setHomeButtonEnabled(true)
        setContentView(buildRoot())
        loadRecords()
        sdk.addObserver(medicationObserver)
    }

    override fun onDestroy() {
        super.onDestroy()
        sdk.removeObserver(medicationObserver)
    }

    override fun onOptionsItemSelected(item: android.view.MenuItem): Boolean {
        if (item.itemId == android.R.id.home) {
            finish()
            return true
        }
        return super.onOptionsItemSelected(item)
    }

    private fun buildRoot(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#1C1C1E"))
        }

        segmentControl = ToggleButtonGroup(this).apply {
            addView(createSegmentBtn(S.byDate, true))
            addView(createSegmentBtn(S.allRecords, false))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply {
                setMargins(dp(16), dp(8), dp(16), 0)
            }
        }
        root.addView(segmentControl)

        // Status legend
        val legendLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(6), dp(12), dp(6))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
        }
        val legends = listOf(S.legendTaken, S.legendLate, S.legendMissed, S.legendEarly)
        for (text in legends) {
            legendLayout.addView(TextView(this).apply {
                this.text = text
                textSize = 11f
                setTextColor(Color.parseColor("#8E8E93"))
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
            })
        }
        root.addView(legendLayout)

        datePickerBtn = Button(this).apply {
            text = fullDateFormat.format(Date(selectedDate))
            setTextColor(Color.WHITE)
            isAllCaps = false
            textSize = 16f
            setBackgroundColor(Color.parseColor("#2C2C2E"))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(48)).apply {
                setMargins(dp(8), dp(8), dp(8), 0)
            }
            setOnClickListener { showDatePicker() }
        }
        root.addView(datePickerBtn)

        summaryLabel = TextView(this).apply {
            textSize = 14f
            setTextColor(Color.parseColor("#8E8E93"))
            gravity = Gravity.CENTER
            setPadding(0, dp(4), 0, dp(4))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
        }
        root.addView(summaryLabel)

        // Title description
        root.addView(TextView(this).apply {
            text = S.scheduledVsActual
            textSize = 12f
            setTextColor(Color.parseColor("#636366"))
            gravity = Gravity.CENTER
            setPadding(0, dp(4), 0, dp(4))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
        })

        recyclerView = RecyclerView(this).apply {
            layoutManager = LinearLayoutManager(this@MedicationRecordsActivity)
            adapter = MedicationRecordAdapter().also { this@MedicationRecordsActivity.adapter = it }
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f)
        }
        root.addView(recyclerView)

        emptyLabel = TextView(this).apply {
            text = S.noRecordsForDate
            textSize = 15f
            setTextColor(Color.parseColor("#636366"))
            gravity = Gravity.CENTER
            visibility = View.GONE
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply {
                height = dp(200)
            }
        }
        root.addView(emptyLabel)

        val deleteBtn = Button(this).apply {
            text = S.clearRecords
            setTextColor(Color.parseColor("#FF3B30"))
            isAllCaps = false
            textSize = 14f
            setBackgroundColor(Color.TRANSPARENT)
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(48))
            setOnClickListener { showDeleteConfirm() }
        }
        root.addView(deleteBtn)

        return root
    }

    private fun createSegmentBtn(text: String, selected: Boolean): Button {
        return Button(this).apply {
            this.text = text
            setTextColor(if (selected) Color.WHITE else Color.parseColor("#8E8E93"))
            isAllCaps = false
            textSize = 14f
            setBackgroundColor(if (selected) Color.parseColor("#007AFF") else Color.parseColor("#3A3A3C"))
            layoutParams = LinearLayout.LayoutParams(0, dp(36), 1f)
            isSelected = selected
            setOnClickListener {
                segmentControl.children.forEach { (it as Button).apply {
                    isSelected = false
                    setBackgroundColor(Color.parseColor("#3A3A3C"))
                    setTextColor(Color.parseColor("#8E8E93"))
                } }
                isSelected = true
                setBackgroundColor(Color.parseColor("#007AFF"))
                setTextColor(Color.WHITE)
                showAllRecords = text == S.allRecords
                datePickerBtn.visibility = if (showAllRecords) View.GONE else View.VISIBLE
                loadRecords()
            }
        }
    }

    private fun showDatePicker() {
        val c = Calendar.getInstance().apply { timeInMillis = selectedDate }
        DatePickerDialog(this, { _, year, month, day ->
            val cal = Calendar.getInstance().apply {
                set(year, month, day)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            selectedDate = cal.timeInMillis
            datePickerBtn.text = fullDateFormat.format(cal.time)
            loadRecords()
        }, c.get(Calendar.YEAR), c.get(Calendar.MONTH), c.get(Calendar.DAY_OF_MONTH)).show()
    }

    private fun loadRecords() {
        records = if (showAllRecords) {
            db.queryAll()
        } else {
            db.query(selectedDate)
        }
        updateUI()
    }

    private fun updateUI() {
        adapter.submitList(records)
        emptyLabel.visibility = if (records.isEmpty()) View.VISIBLE else View.GONE

        if (showAllRecords) {
            summaryLabel.text = S.totalRecordsCount.replace("%d", records.size.toString())
        } else {
            summaryLabel.text = S.dateRecordsCount.replace("%@", fullDateFormat.format(Date(selectedDate))).replace("%d", records.size.toString())
        }
    }

    private fun showDeleteConfirm() {
        AlertDialog.Builder(this)
            .setTitle(S.clearRecords)
            .setMessage(S.clearRecordsConfirmMsg)
            .setNegativeButton(S.cancel, null)
            .setPositiveButton(S.delete) { _, _ ->
                db.deleteAll()
                records = emptyList()
                updateUI()
            }
            .show()
    }

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    class MedicationRecordAdapter : RecyclerView.Adapter<MedicationRecordAdapter.ViewHolder>() {

        private var items = emptyList<MedicationEntry>()

        fun submitList(newItems: List<MedicationEntry>) {
            items = newItems
            notifyDataSetChanged()
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            return ViewHolder(LinearLayout(parent.context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(16, parent.context), dp(12, parent.context), dp(16, parent.context), dp(12, parent.context))
                layoutParams = RecyclerView.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
            })
        }

        private fun dp(v: Int, ctx: android.content.Context) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), ctx.resources.displayMetrics).toInt()

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(items[position])
        }

        override fun getItemCount() = items.size

        class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
            private val emojiLabel = TextView(itemView.context).apply {
                textSize = 24f
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(dp(40, itemView.context), dp(40, itemView.context)).apply {
                    marginEnd = dp(12, itemView.context)
                }
            }
            private val textColumn = LinearLayout(itemView.context).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
            }
            private val titleLabel = TextView(itemView.context).apply {
                textSize = 14f
                setTextColor(Color.WHITE)
                layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
            }
            private val detailLabel = TextView(itemView.context).apply {
                textSize = 12f
                setTextColor(Color.parseColor("#8E8E93"))
                layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply {
                    topMargin = dp(2, itemView.context)
                }
            }

            init {
                val linearLayout = itemView as LinearLayout
                textColumn.addView(titleLabel)
                textColumn.addView(detailLabel)
                linearLayout.addView(emojiLabel)
                linearLayout.addView(textColumn)
            }

            fun bind(entry: MedicationEntry) {
                emojiLabel.text = entry.statusEmoji
                titleLabel.text = String.format(S.alarmIndexStatus, entry.alarmIndex, entry.statusText)
                val eventDate = Date(entry.timestamp)
                val timeFmt = SimpleDateFormat("HH:mm", Locale.getDefault())
                val dateFmt = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val eventTime = timeFmt.format(eventDate)
                val eventDateStr = dateFmt.format(eventDate)
                if (entry.alarmHour > 0 || entry.alarmMinute > 0) {
                    detailLabel.text = "$eventDateStr  ${entry.alarmTimeString} → $eventTime"
                } else {
                    detailLabel.text = "$eventDateStr  $eventTime"
                }
            }

            private fun dp(v: Int, ctx: android.content.Context) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), ctx.resources.displayMetrics).toInt()
        }
    }

    class ToggleButtonGroup(context: android.content.Context) : LinearLayout(context) {
        val children: List<View> get() = (0 until childCount).map { getChildAt(it) }
    }
}