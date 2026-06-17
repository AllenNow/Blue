// FAQViewController.swift
// BlueSDK Example - 常见问题页面
// 列表 + 搜索 + 点击进入详情 + 中英双语

import UIKit

struct FAQItem {
    let questionZh: String
    let questionEn: String
    let answerZh: String
    let answerEn: String
    let category: String

    var question: String { FAQLocale.isZh ? questionZh : questionEn }
    var answer: String { FAQLocale.isZh ? answerZh : answerEn }
}

enum FAQLocale {
    static var isZh: Bool {
        let lang = Locale.preferredLanguages.first ?? "en"
        return lang.hasPrefix("zh")
    }
    static var searchPlaceholder: String { isZh ? "搜索问题..." : "Search..." }
    static var title: String { isZh ? "常见问题" : "FAQ" }
    static var detailTitle: String { isZh ? "解答" : "Answer" }
    static var noResult: String { isZh ? "没有匹配的问题" : "No matching questions" }
}

class FAQViewController: UIViewController {

    // MARK: - 数据

    private let allItems: [FAQItem] = [
        FAQItem(
            questionZh: "扫描不到设备怎么办？",
            questionEn: "Can't find the device when scanning?",
            answerZh: """
            1. 确认设备已开机且蓝牙指示灯闪烁
            2. 确认手机蓝牙已开启
            3. iOS 需要在 Info.plist 中声明 NSBluetoothAlwaysUsageDescription
            4. 确认设备在手机 3 米范围内
            5. 如果之前连接过其他手机，需要先对设备长按按键恢复出厂设置
            6. 尝试重启手机蓝牙后再扫描
            """,
            answerEn: """
            1. Confirm the device is powered on and the Bluetooth LED is blinking
            2. Confirm phone Bluetooth is enabled
            3. iOS requires NSBluetoothAlwaysUsageDescription in Info.plist
            4. Confirm the device is within 3 meters
            5. If previously paired with another phone, factory reset the device (long press button)
            6. Try toggling phone Bluetooth off/on and scan again
            """,
            category: "连接 / Connection"),

        FAQItem(
            questionZh: "认证失败是什么原因？",
            questionEn: "Why does authentication fail?",
            answerZh: """
            认证失败通常有以下原因：

            1. 设备已被其他手机绑定
               → 解决：对设备长按按键恢复出厂设置，然后调用 clearBinding()

            2. fixedAuthKey 配置错误
               → 解决：确认密钥为 4 位十六进制（如 "05FA"），或设为 nil 自动计算

            3. 设备固件版本不兼容
               → 解决：通过 queryDeviceInfo() 查看版本
            """,
            answerEn: """
            Common causes:

            1. Device is already bound to another phone
               → Solution: Factory reset the device, then call clearBinding()

            2. fixedAuthKey is incorrect
               → Solution: Ensure it's a 4-char hex string (e.g. "05FA"), or set nil for auto

            3. Firmware version incompatibility
               → Solution: Check version via queryDeviceInfo()
            """,
            category: "连接 / Connection"),

        FAQItem(
            questionZh: "连接后自动断开是怎么回事？",
            questionEn: "Why does it disconnect automatically after connecting?",
            answerZh: """
            常见原因：
            1. 认证失败后 SDK 会自动断开（查看 onAuthResult 回调）
            2. 设备电量不足导致断线
            3. 距离过远（超过 3 米）或有障碍物干扰
            4. iOS 后台被系统回收

            SDK 会自动重连（最多 5 次，间隔 2s/4s/8s），可通过 onReconnecting 回调感知。
            """,
            answerEn: """
            Common causes:
            1. Authentication failed — SDK disconnects automatically (check onAuthResult)
            2. Low device battery
            3. Distance too far (>3m) or obstacles
            4. iOS killed the background connection

            SDK will auto-reconnect (up to 5 times, delays 2s/4s/8s). Monitor via onReconnecting callback.
            """,
            category: "连接 / Connection"),

        FAQItem(
            questionZh: "如何在后台保持连接？",
            questionEn: "How to maintain connection in background?",
            answerZh: """
            iOS 后台 BLE 连接需要：
            1. 在 Info.plist 的 UIBackgroundModes 中添加 bluetooth-central
            2. 使用 Core Bluetooth 的状态恢复机制

            注意：即使配置了后台模式，系统仍可能在内存压力时终止连接。
            """,
            answerEn: """
            iOS background BLE requires:
            1. Add bluetooth-central to UIBackgroundModes in Info.plist
            2. Use Core Bluetooth State Preservation and Restoration

            Note: Even with background modes, the system may terminate connections under memory pressure.
            """,
            category: "连接 / Connection"),

        FAQItem(
            questionZh: "最多能设置几个闹钟？",
            questionEn: "How many alarms can be set?",
            answerZh: """
            LX-PD02 支持最多 7 个闹钟槽位（index 1~7）。
            每个可独立设置时间和重复周期（WeekDays）。
            使用 setAlarm() 设置，deleteAlarm() 删除，clearAllAlarms() 清空。
            """,
            answerEn: """
            LX-PD02 supports up to 7 alarm slots (index 1~7).
            Each can have independent time and repeat schedule (WeekDays).
            Use setAlarm() to set, deleteAlarm() to remove, clearAllAlarms() to clear all.
            """,
            category: "闹钟 / Alarm"),

        FAQItem(
            questionZh: "批量设置闹钟会覆盖已有的吗？",
            questionEn: "Does batch setting overwrite existing alarms?",
            answerZh: """
            是的。setAlarms() 按索引逐个设置，已有闹钟会被覆盖。
            如果只想追加，先通过 queryAlarm(index:) 查询空闲槽位（isDeleted=true）。
            """,
            answerEn: """
            Yes. setAlarms() sets each by index, overwriting existing ones.
            To append only, first query free slots via queryAlarm(index:) where isDeleted=true.
            """,
            category: "闹钟 / Alarm"),

        FAQItem(
            questionZh: "用药事件有哪几种状态？",
            questionEn: "What medication event statuses are there?",
            answerZh: """
            MedicationStatus 有 4 种：
            • TAKEN (0x01) — 按时取药
            • TIMEOUT (0x02) — 超时取药
            • MISSED (0x03) — 漏服
            • EARLY (0x04) — 提前取药

            通过 onMedicationResult 和 onMedicationRecordReported 回调接收。
            """,
            answerEn: """
            MedicationStatus has 4 types:
            • TAKEN (0x01) — Taken on time
            • TIMEOUT (0x02) — Taken late
            • MISSED (0x03) — Missed dose
            • EARLY (0x04) — Taken early

            Received via onMedicationResult and onMedicationRecordReported callbacks.
            """,
            category: "用药 / Medication"),

        FAQItem(
            questionZh: "设备断线后用药记录会丢失吗？",
            questionEn: "Will medication records be lost after disconnection?",
            answerZh: """
            不会。设备会在本地缓存记录。
            下次连接后设备会自动上报，SDK 通过 onMedicationRecordReported 通知。
            建议 APP 使用 SQLite 持久化存储。
            """,
            answerEn: """
            No. The device caches records locally.
            After reconnection, the device auto-reports them via onMedicationRecordReported.
            Recommend using SQLite for persistent storage in your app.
            """,
            category: "用药 / Medication"),

        FAQItem(
            questionZh: "铃声和静音是什么关系？",
            questionEn: "What's the relationship between sound type and silence?",
            answerZh: """
            静音通过设置铃声类型为 MUTE(0x00) 实现。
            • setSilence(true) = setSoundType(.mute)
            • setSilence(false) = setSoundType(.typeA)
            两者本质相同，setSilence 只是便利方法。
            """,
            answerEn: """
            Silence is implemented by setting sound type to MUTE(0x00).
            • setSilence(true) = setSoundType(.mute)
            • setSilence(false) = setSoundType(.typeA)
            They're the same thing; setSilence is just a convenience method.
            """,
            category: "音频 / Audio"),

        FAQItem(
            questionZh: "多个指令可以连续调用吗？",
            questionEn: "Can multiple commands be called consecutively?",
            answerZh: """
            可以。SDK 内部 CommandQueue 自动串行排队。
            • 同时只有一条指令在等待应答
            • 指令间隔至少 200ms
            • 超时 5 秒自动重试，最多 3 次
            """,
            answerEn: """
            Yes. The internal CommandQueue handles serial queuing automatically.
            • Only one command awaits response at a time
            • Minimum 200ms interval between commands
            • 5-second timeout with up to 3 retries
            """,
            category: "SDK"),

        FAQItem(
            questionZh: "SDK 初始化耗时多久？",
            questionEn: "How long does SDK initialization take?",
            answerZh: """
            initialize() 耗时极短（< 100ms），仅做内存初始化，不涉及 BLE 操作。
            建议在 AppDelegate 中调用一次。
            """,
            answerEn: """
            initialize() is very fast (<100ms), only memory initialization, no BLE operations.
            Recommended to call once in AppDelegate.
            """,
            category: "SDK"),

        FAQItem(
            questionZh: "如何调试 BLE 通信问题？",
            questionEn: "How to debug BLE communication issues?",
            answerZh: """
            1. 开启 DEBUG 日志：setLogLevel(.debug)
            2. 自定义处理器：setLogHandler { ... }
            3. 导出日志：exportLog() — 最近 1000 条
            4. 使用「协议验证」页面自动化测试
            """,
            answerEn: """
            1. Enable DEBUG logs: setLogLevel(.debug)
            2. Custom handler: setLogHandler { ... }
            3. Export logs: exportLog() — last 1000 entries
            4. Use the "Protocol Test" page for automated testing
            """,
            category: "SDK"),

        FAQItem(
            questionZh: "恢复出厂设置后需要做什么？",
            questionEn: "What to do after factory reset?",
            answerZh: """
            设备恢复出厂后：
            1. 设备断开蓝牙连接
            2. 设备清除所有闹钟和配对信息
            3. APP 调用 clearBinding() 清除本地密钥
            4. 重新扫描连接（SDK 自动生成新 phoneMac）
            注意：此操作不可逆。
            """,
            answerEn: """
            After factory reset:
            1. Device disconnects Bluetooth
            2. Device clears all alarms and pairing info
            3. Call clearBinding() to clear local keys
            4. Re-scan and connect (SDK generates new phoneMac)
            Note: This operation is irreversible.
            """,
            category: "设备 / Device"),
    ]

    private var filteredItems: [FAQItem] = []

    // MARK: - UI

    private lazy var searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = FAQLocale.searchPlaceholder
        sb.searchBarStyle = .minimal
        sb.delegate = self
        sb.translatesAutoresizingMaskIntoConstraints = false
        return sb
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "FAQCell")
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 56
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = FAQLocale.title
        view.backgroundColor = .systemBackground
        filteredItems = allItems
        setupUI()
    }

    @objc func dismissSelf() { dismiss(animated: true) }

    private func setupUI() {
        view.addSubview(searchBar)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func categories() -> [String] {
        var seen = [String]()
        for item in filteredItems {
            if !seen.contains(item.category) { seen.append(item.category) }
        }
        return seen
    }

    private func items(for category: String) -> [FAQItem] {
        filteredItems.filter { $0.category == category }
    }
}

// MARK: - UITableViewDataSource & Delegate

extension FAQViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { categories().count }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { categories()[section] }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items(for: categories()[section]).count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FAQCell", for: indexPath)
        let item = items(for: categories()[indexPath.section])[indexPath.row]
        cell.textLabel?.text = item.question
        cell.textLabel?.numberOfLines = 0
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items(for: categories()[indexPath.section])[indexPath.row]
        navigationController?.pushViewController(FAQDetailViewController(item: item), animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension FAQViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredItems = allItems
        } else {
            filteredItems = allItems.filter {
                $0.question.localizedCaseInsensitiveContains(searchText) ||
                $0.answer.localizedCaseInsensitiveContains(searchText) ||
                $0.questionZh.localizedCaseInsensitiveContains(searchText) ||
                $0.answerZh.localizedCaseInsensitiveContains(searchText)
            }
        }
        tableView.reloadData()
    }
}

// MARK: - 详情页

class FAQDetailViewController: UIViewController {
    private let item: FAQItem

    init(item: FAQItem) { self.item = item; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = FAQLocale.detailTitle
        view.backgroundColor = .systemBackground

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        let questionLabel = UILabel()
        questionLabel.text = item.question
        questionLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        questionLabel.numberOfLines = 0
        stack.addArrangedSubview(questionLabel)

        let categoryLabel = UILabel()
        categoryLabel.text = item.category
        categoryLabel.font = .systemFont(ofSize: 13)
        categoryLabel.textColor = .secondaryLabel
        stack.addArrangedSubview(categoryLabel)

        let answerLabel = UILabel()
        answerLabel.text = item.answer
        answerLabel.font = .systemFont(ofSize: 15)
        answerLabel.numberOfLines = 0
        stack.addArrangedSubview(answerLabel)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -40),
        ])
    }
}

extension FAQViewController: DismissableVC {}
