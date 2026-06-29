package com.blue.demo

import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.method.ScrollingMovementMethod
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.blue.sdk.BlueSDKManager
import com.blue.sdk.error.BlueError
import com.blue.sdk.enums.LogLevel
import com.blue.sdk.enums.SoundType
import com.blue.sdk.enums.TimeFormat
import com.blue.sdk.enums.VolumeLevel

data class TestCase(val name: String, val execute: (callback: (Result<String>) -> Unit) -> Unit)

enum class TestResult {
    PENDING, RUNNING, PASSED, FAILED
}

class ProtocolTestActivity : AppCompatActivity() {

    private val sdk get() = BlueSDKManager.getInstance(this)

    private lateinit var statusLabel: TextView
    private lateinit var startButton: Button
    private lateinit var recyclerView: RecyclerView
    private lateinit var logTextView: TextView
    private lateinit var adapter: TestResultAdapter

    private var testCases: List<TestCase> = emptyList()
    private var results = mutableListOf<TestResult>()
    private var resultMessages = mutableListOf<String>()
    private var currentIndex = 0
    private var isRunning = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        supportActionBar?.title = S.protocolTest
        setContentView(buildRoot())
        buildTestCases()
        setupLogHandler()
    }

    override fun onDestroy() {
        super.onDestroy()
        sdk.setLogHandler(null)
    }

    private fun buildRoot(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#1C1C1E"))
        }

        statusLabel = TextView(this).apply {
            text = S.protocolTestHint
            setTextColor(Color.parseColor("#8E8E93"))
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(0, dp(8), 0, dp(4))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
        }
        root.addView(statusLabel)

        startButton = Button(this).apply {
            text = S.startTest
            setTextColor(Color.WHITE)
            isAllCaps = false
            textSize = 17f
            setBackgroundColor(Color.parseColor("#007AFF"))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(44)).apply {
                setMargins(dp(20), 0, dp(20), dp(8))
            }
            setOnClickListener { startTests() }
        }
        root.addView(startButton)

        recyclerView = RecyclerView(this).apply {
            layoutManager = LinearLayoutManager(this@ProtocolTestActivity)
            adapter = TestResultAdapter().also { this@ProtocolTestActivity.adapter = it }
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, 0, 0.45f)
        }
        root.addView(recyclerView)

        logTextView = TextView(this).apply {
            textSize = 9f
            setTextColor(Color.parseColor("#4AF626"))
            setBackgroundColor(Color.BLACK)
            movementMethod = ScrollingMovementMethod()
            gravity = Gravity.TOP
            setPadding(dp(8), dp(8), dp(8), dp(8))
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, 0, 0.55f)
        }
        root.addView(logTextView)

        return root
    }

    private fun setupLogHandler() {
        sdk.setLogHandler { level, tag, message ->
            if (message.contains("Send") || message.contains("TX:") || message.contains("RX:") ||
                message.contains("auth") || message.contains("Auth") ||
                message.contains("failed") || message.contains("success")) {
                appendLog(message)
            }
        }
    }

    private fun appendLog(msg: String) {
        Handler(Looper.getMainLooper()).post {
            logTextView.append("$msg\n")
            logTextView.layout?.let { layout ->
                val scrollAmount = layout.getLineTop(logTextView.lineCount) - logTextView.height
                if (scrollAmount > 0) logTextView.scrollTo(0, scrollAmount)
            }
        }
    }

    private fun buildTestCases() {
        testCases = listOf(
            TestCase("查询设备信息 (CMD=0x01)") { completion ->
                sdk.queryDeviceInfo { result ->
                    result.fold(
                        onSuccess = { completion(Result.success("MAC=${it.macAddress} v${it.firmwareVersion}")) },
                        onFailure = { completion(Result.failure(it)) }
                    )
                }
            },
            TestCase("同步时间 (CMD=0xE1)") { completion ->
                sdk.syncTime { result ->
                    result.fold(
                        onSuccess = { completion(Result.success("已下发")) },
                        onFailure = { completion(Result.failure(it)) }
                    )
                }
            },
            TestCase("设置闹钟1 08:00 (DPID=0x66)") { completion ->
                sdk.setAlarm(1, 8, 0, com.blue.sdk.enums.WeekDays.ALL) { result ->
                    result.fold(
                        onSuccess = { completion(Result.success(String.format("%02d:%02d 每天", it.hour, it.minute))) },
                        onFailure = { completion(Result.failure(it)) }
                    )
                }
            },
            TestCase("设置闹钟2 12:30 (DPID=0x67)") { completion ->
                sdk.setAlarm(2, 12, 30, com.blue.sdk.enums.WeekDays.MONDAY) { result ->
                    result.fold(
                        onSuccess = { completion(Result.success(String.format("%02d:%02d 工作日", it.hour, it.minute))) },
                        onFailure = { completion(Result.failure(it)) }
                    )
                }
            },
            TestCase("删除闹钟2 (DPID=0x67 FF)") { completion ->
                sdk.deleteAlarm(2) { result ->
                    result.fold(
                        onSuccess = { completion(Result.success("已删除")) },
                        onFailure = { completion(Result.failure(it)) }
                    )
                }
            },
            TestCase("设置铃声-类型A (DPID=0x6F val=01)") { completion ->
                sdk.setSoundType(SoundType.TYPE_A) { result ->
                    result.fold(
                        onSuccess = { completion(Result.success("类型A")) },
                        onFailure = { completion(Result.failure(it)) }
                    )
                }
            },
            TestCase("设置铃声-类型B (DPID=0x6F val=02)") { completion ->
                sdk.setSoundType(SoundType.TYPE_B) { result ->
                    result.fold(
                        onSuccess = { completion(Result.success("类型B")) },
                        onFailure = { completion(Result.failure(it)) }
                    )
                }
            },
            TestCase("设置时间格式-24H (DPID=0x73 val=01)") { completion ->
                sdk.setTimeFormat(TimeFormat.HOUR_24) { result ->
                    result.fold(
                        onSuccess = { completion(Result.success("24小时制")) },
                        onFailure = { completion(Result.failure(it)) }
                    )
                }
            },
            TestCase("设置时间格式-12H (DPID=0x73 val=00)") { completion ->
                sdk.setTimeFormat(TimeFormat.HOUR_12) { result ->
                    result.fold(
                        onSuccess = { completion(Result.success("12小时制")) },
                        onFailure = { completion(Result.failure(it)) }
                    )
                }
            },
            TestCase("清空所有闹钟 (DPID=0x70)") { completion ->
                sdk.clearAllAlarms { result ->
                    result.fold(
                        onSuccess = { completion(Result.success("已清空")) },
                        onFailure = { completion(Result.failure(it)) }
                    )
                }
            },
            TestCase("⚡设置音量-低 (DPID=0x6E val=01)") { completion ->
                sdk.setVolume(VolumeLevel.LOW) { result ->
                    result.fold(
                        onSuccess = { completion(Result.success("低音量")) },
                        onFailure = { completion(Result.failure(it)) }
                    )
                }
            },
            TestCase("⚡设置音量-高 (DPID=0x6E val=03)") { completion ->
                sdk.setVolume(VolumeLevel.HIGH) { result ->
                    result.fold(
                        onSuccess = { completion(Result.success("高音量")) },
                        onFailure = { completion(Result.failure(it)) }
                    )
                }
            },
            TestCase("⚡静音开 (DPID=0x74 val=01)") { completion ->
                sdk.setSilence(true) { result ->
                    result.fold(
                        onSuccess = { completion(Result.success("静音已开")) },
                        onFailure = { completion(Result.failure(it)) }
                    )
                }
            },
            TestCase("⚡静音关 (DPID=0x74 val=00)") { completion ->
                sdk.setSilence(false) { result ->
                    result.fold(
                        onSuccess = { completion(Result.success("静音已关")) },
                        onFailure = { completion(Result.failure(it)) }
                    )
                }
            },
            TestCase("⚡提醒持续时间5分钟 (DPID=0x70)") { completion ->
                sdk.setAlertDuration(5) { result ->
                    result.fold(
                        onSuccess = { completion(Result.success("5分钟")) },
                        onFailure = { completion(Result.failure(it)) }
                    )
                }
            }
        )
        results = MutableList(testCases.size) { TestResult.PENDING }
        resultMessages = MutableList(testCases.size) { "" }
        adapter.submitList(testCases.mapIndexed { i, tc ->
            TestItem(i + 1, tc.name, results[i], resultMessages[i])
        })
    }

    private fun startTests() {
        if (isRunning) return
        isRunning = true
        currentIndex = 0
        results = MutableList(testCases.size) { TestResult.PENDING }
        resultMessages = MutableList(testCases.size) { "" }
        adapter.submitList(testCases.mapIndexed { i, tc ->
            TestItem(i + 1, tc.name, results[i], resultMessages[i])
        })
        startButton.isEnabled = false
        startButton.text = S.testing
        statusLabel.text = S.runningProtocolTest
        runNext()
    }

    private fun runNext() {
        if (currentIndex >= testCases.size) {
            finishTests()
            return
        }

        val index = currentIndex
        results[index] = TestResult.RUNNING
        adapter.updateItem(index, TestItem(index + 1, testCases[index].name, TestResult.RUNNING, ""))
        scrollToPosition(index)

        Handler(Looper.getMainLooper()).postDelayed({
            testCases[index].execute { result ->
                Handler(Looper.getMainLooper()).post {
                    result.fold(
                        onSuccess = { msg ->
                            results[index] = TestResult.PASSED
                            resultMessages[index] = msg
                            adapter.updateItem(index, TestItem(index + 1, testCases[index].name, TestResult.PASSED, msg))
                            statusLabel.text = "[${index + 1}/${testCases.size}] ${testCases[index].name} ✅"
                            statusLabel.setTextColor(Color.parseColor("#34C759"))
                        },
                        onFailure = { e ->
                            results[index] = TestResult.FAILED
                            resultMessages[index] = (e as? BlueError)?.message ?: "未知错误"
                            adapter.updateItem(index, TestItem(index + 1, testCases[index].name, TestResult.FAILED, resultMessages[index]))
                            statusLabel.text = "[${index + 1}/${testCases.size}] ${testCases[index].name} ❌ ${S.testSkipped}"
                            statusLabel.setTextColor(Color.parseColor("#FF9500"))
                        }
                    )
                    currentIndex++
                    runNext()
                }
            }
        }, 500)
    }

    private fun finishTests() {
        isRunning = false
        startButton.isEnabled = true
        startButton.text = S.retest

        val passed = results.count { it == TestResult.PASSED }
        val failed = results.count { it == TestResult.FAILED }
        val total = testCases.size

        if (failed == 0) {
            statusLabel.text = "${S.allTestsPassed} $passed/$total"
            statusLabel.setTextColor(Color.parseColor("#34C759"))
        } else {
            statusLabel.text = S.testSummary
                .replaceFirst("%d", passed.toString())
                .replaceFirst("%d", failed.toString())
                .replaceFirst("%d", total.toString())
            statusLabel.setTextColor(Color.parseColor("#FF9500"))
        }
    }

    private fun scrollToPosition(position: Int) {
        recyclerView.smoothScrollToPosition(position)
    }

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    data class TestItem(val index: Int, val name: String, val result: TestResult, val message: String)

    class TestResultAdapter : RecyclerView.Adapter<TestResultAdapter.ViewHolder>() {

        private var items = emptyList<TestItem>()

        fun submitList(newItems: List<TestItem>) {
            items = newItems
            notifyDataSetChanged()
        }

        fun updateItem(position: Int, item: TestItem) {
            items = items.toMutableList().apply { set(position, item) }
            notifyItemChanged(position)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            return ViewHolder(LinearLayout(parent.context).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(12, 16, 12, 16)
                layoutParams = RecyclerView.LayoutParams(MATCH_PARENT, dp(56, parent.context))
            })
        }

        private fun dp(v: Int, ctx: android.content.Context) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), ctx.resources.displayMetrics).toInt()

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            val item = items[position]
            holder.bind(item)
        }

        override fun getItemCount() = items.size

        class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
            private val indexLabel = TextView(itemView.context).apply {
                textSize = 13f
                setTextColor(Color.parseColor("#8E8E93"))
                layoutParams = LinearLayout.LayoutParams(dp(28, itemView.context), WRAP_CONTENT).apply {
                    gravity = Gravity.CENTER_VERTICAL
                }
            }
            private val nameLabel = TextView(itemView.context).apply {
                textSize = 14f
                setTextColor(Color.WHITE)
                layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f).apply {
                    gravity = Gravity.CENTER_VERTICAL
                    marginStart = dp(4, itemView.context)
                }
            }
            private val resultLabel = TextView(itemView.context).apply {
                textSize = 13f
                layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply {
                    gravity = Gravity.CENTER_VERTICAL
                }
            }
            private val progressBar = ProgressBar(itemView.context).apply {
                layoutParams = LinearLayout.LayoutParams(dp(24, itemView.context), dp(24, itemView.context)).apply {
                    gravity = Gravity.CENTER_VERTICAL
                    marginStart = dp(8, itemView.context)
                }
            }

            init {
                (itemView as LinearLayout).apply {
                    addView(indexLabel)
                    addView(nameLabel)
                    addView(resultLabel)
                    addView(progressBar)
                }
            }

            fun bind(item: TestItem) {
                indexLabel.text = "${item.index}."
                progressBar.visibility = View.GONE

                when (item.result) {
                    TestResult.PENDING -> {
                        resultLabel.text = "⏳"
                        resultLabel.setTextColor(Color.parseColor("#636366"))
                        nameLabel.setTextColor(Color.WHITE)
                        nameLabel.text = item.name
                        (itemView as ViewGroup).setBackgroundColor(Color.TRANSPARENT)
                    }
                    TestResult.RUNNING -> {
                        resultLabel.text = ""
                        progressBar.visibility = View.VISIBLE
                        nameLabel.setTextColor(Color.WHITE)
                        nameLabel.text = item.name
                        (itemView as ViewGroup).setBackgroundColor(Color.parseColor("#007AFF10"))
                    }
                    TestResult.PASSED -> {
                        resultLabel.text = "✅ ${item.message}"
                        resultLabel.setTextColor(Color.parseColor("#34C759"))
                        nameLabel.setTextColor(Color.WHITE)
                        nameLabel.text = item.name
                        (itemView as ViewGroup).setBackgroundColor(Color.parseColor("#34C75910"))
                    }
                    TestResult.FAILED -> {
                        resultLabel.text = "❌"
                        resultLabel.setTextColor(Color.parseColor("#FF3B30"))
                        nameLabel.setTextColor(Color.parseColor("#FF3B30"))
                        nameLabel.text = "${item.name}\n${item.message}"
                        (itemView as ViewGroup).setBackgroundColor(Color.parseColor("#FF3B3015"))
                    }
                }
            }

            private fun dp(v: Int, ctx: android.content.Context) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), ctx.resources.displayMetrics).toInt()
        }
    }
}