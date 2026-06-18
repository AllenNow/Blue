// ProtocolTestViewController.swift
// BlueSDK Example - 协议指令自动化验证页面
// 逐条执行所有 BLE 协议指令，成功 ✅ / 失败 ❌ 并中断测试

import UIKit
import BlueSDK

/// 单条测试用例
struct TestCase {
    let name: String
    let execute: (@escaping (Result<String, Error>) -> Void) -> Void
}

/// 测试结果
enum TestResult {
    case pending
    case running
    case passed(String)  // 附加信息
    case failed(String)  // 错误信息
}

class ProtocolTestViewController: UIViewController {

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.register(TestResultCell.self, forCellReuseIdentifier: "TestCell")
        tv.rowHeight = 56
        tv.allowsSelection = false
        return tv
    }()

    private lazy var startButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("开始测试", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 12
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(startTests), for: .touchUpInside)
        return btn
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.text = "点击\"开始测试\"运行全部协议验证"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - 状态

    private var testCases: [TestCase] = []
    private var results: [TestResult] = []
    private var currentIndex = 0
    private var isRunning = false

    private lazy var logTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        tv.backgroundColor = .black
        tv.textColor = .systemGreen
        tv.layer.cornerRadius = 6
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "协议验证"
        view.backgroundColor = .systemBackground
        setupUI()
        buildTestCases()
        results = Array(repeating: .pending, count: testCases.count)

        // 监听 SDK 日志，显示收发数据
        BlueSDK.shared.setLogHandler { [weak self] level, tag, message in
            print("[BlueSDK][\(level)][\(tag)] \(message)")
            // 只显示收发帧和关键信息
            if message.contains("发送帧") || message.contains("收到数据") ||
               message.contains("认证") || message.contains("失败") || message.contains("成功") {
                self?.appendLog(message)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 恢复主页的 logHandler
        BlueSDK.shared.setLogHandler(nil)
    }

    @objc func dismissSelf() {
        dismiss(animated: true)
    }

    private func setupUI() {
        view.addSubview(statusLabel)
        view.addSubview(startButton)
        view.addSubview(tableView)
        view.addSubview(logTextView)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            startButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            startButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            startButton.heightAnchor.constraint(equalToConstant: 44),

            tableView.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.45),

            logTextView.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 4),
            logTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            logTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            logTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4)
        ])
    }

    private func appendLog(_ msg: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.logTextView.text += "\(msg)\n"
            let end = NSRange(location: self.logTextView.text.count - 1, length: 1)
            self.logTextView.scrollRangeToVisible(end)
        }
    }

    // MARK: - 构建测试用例

    private func buildTestCases() {
        testCases = [
            // 1. 查询设备信息
            TestCase(name: "查询设备信息 (CMD=0x01)") { completion in
                BlueSDK.shared.queryDeviceInfo { result in
                    switch result {
                    case .success(let info):
                        completion(.success("MAC=\(info.macAddressString) v\(info.firmwareVersion)"))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            },

            // 2. 时间同步
            TestCase(name: "同步时间 (CMD=0xE1)") { completion in
                BlueSDK.shared.syncTime { result in
                    switch result {
                    case .success: completion(.success("已下发"))
                    case .failure(let error): completion(.failure(error))
                    }
                }
            },

            // 3. 设置闹钟1
            TestCase(name: "设置闹钟1 08:00 (DPID=0x66)") { completion in
                BlueSDK.shared.setAlarm(index: 1, hour: 8, minute: 0, days: .all) { result in
                    switch result {
                    case .success(let a): completion(.success("\(String(format: "%02d:%02d", a.hour, a.minute)) 每天"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 4. 设置闹钟2
            TestCase(name: "设置闹钟2 12:30 (DPID=0x67)") { completion in
                BlueSDK.shared.setAlarm(index: 2, hour: 12, minute: 30, days: .weekdays) { result in
                    switch result {
                    case .success(let a): completion(.success("\(String(format: "%02d:%02d", a.hour, a.minute)) 工作日"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 5. 删除闹钟2
            TestCase(name: "删除闹钟2 (DPID=0x67 FF)") { completion in
                BlueSDK.shared.deleteAlarm(index: 2) { result in
                    switch result {
                    case .success: completion(.success("已删除"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 6. 设置铃声类型A
            TestCase(name: "设置铃声-类型A (DPID=0x6F val=01)") { completion in
                BlueSDK.shared.setSoundType(.typeA) { result in
                    switch result {
                    case .success: completion(.success("类型A"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 7. 设置铃声类型B
            TestCase(name: "设置铃声-类型B (DPID=0x6F val=02)") { completion in
                BlueSDK.shared.setSoundType(.typeB) { result in
                    switch result {
                    case .success: completion(.success("类型B"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 8. 设置时间格式24H
            TestCase(name: "设置时间格式-24H (DPID=0x73 val=01)") { completion in
                BlueSDK.shared.setTimeFormat(.hour24) { result in
                    switch result {
                    case .success: completion(.success("24小时制"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 9. 设置时间格式12H
            TestCase(name: "设置时间格式-12H (DPID=0x73 val=00)") { completion in
                BlueSDK.shared.setTimeFormat(.hour12) { result in
                    switch result {
                    case .success: completion(.success("12小时制"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 10. 清空所有闹钟
            TestCase(name: "清空所有闹钟 (DPID=0x70)") { completion in
                BlueSDK.shared.clearAllAlarms { result in
                    switch result {
                    case .success: completion(.success("已清空"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // --- 以下指令低电模式可能失败 ---

            // 11. 设置音量-低
            TestCase(name: "⚡设置音量-低 (DPID=0x6E val=01)") { completion in
                BlueSDK.shared.setVolume(.low) { result in
                    switch result {
                    case .success: completion(.success("低音量"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 12. 设置音量-高
            TestCase(name: "⚡设置音量-高 (DPID=0x6E val=03)") { completion in
                BlueSDK.shared.setVolume(.high) { result in
                    switch result {
                    case .success: completion(.success("高音量"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 13. 静音开
            TestCase(name: "⚡静音开 (DPID=0x74 val=01)") { completion in
                BlueSDK.shared.setSilence(true) { result in
                    switch result {
                    case .success: completion(.success("静音已开"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 14. 静音关
            TestCase(name: "⚡静音关 (DPID=0x74 val=00)") { completion in
                BlueSDK.shared.setSilence(false) { result in
                    switch result {
                    case .success: completion(.success("静音已关"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 15. 设置提醒持续时间
            TestCase(name: "⚡提醒持续时间5分钟 (DPID=0x70)") { completion in
                BlueSDK.shared.setAlertDuration(5) { result in
                    switch result {
                    case .success: completion(.success("5分钟"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },
        ]
    }

    // MARK: - 测试执行

    @objc private func startTests() {
        guard !isRunning else { return }
        isRunning = true
        currentIndex = 0
        results = Array(repeating: .pending, count: testCases.count)
        tableView.reloadData()
        startButton.isEnabled = false
        startButton.setTitle("测试中...", for: .normal)
        statusLabel.text = "正在运行协议验证..."
        runNext()
    }

    private func runNext() {
        guard currentIndex < testCases.count else {
            finishTests(success: true)
            return
        }

        let index = currentIndex
        results[index] = .running
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        scrollToRow(index)

        // 每条测试之间间隔 0.5 秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.testCases[index].execute { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let info):
                        self.results[index] = .passed(info)
                        self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                        self.currentIndex += 1
                        self.statusLabel.text = "[\(index + 1)/\(self.testCases.count)] \(self.testCases[index].name) ✅"
                        self.runNext()
                    case .failure(let error):
                        self.results[index] = .failed(error.localizedDescription)
                        self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                        // 失败跳过，继续下一条
                        self.currentIndex += 1
                        self.statusLabel.text = "[\(index + 1)/\(self.testCases.count)] \(self.testCases[index].name) ❌ 已跳过"
                        self.statusLabel.textColor = .systemOrange
                        self.runNext()
                    }
                }
            }
        }
    }

    private func finishTests(success: Bool) {
        isRunning = false
        startButton.isEnabled = true
        startButton.setTitle("重新测试", for: .normal)

        let passed = results.filter { if case .passed = $0 { return true }; return false }.count
        let failed = results.filter { if case .failed = $0 { return true }; return false }.count
        let total = testCases.count

        if failed == 0 {
            statusLabel.text = "🎉 全部通过！\(passed)/\(total)"
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.text = "完成：通过 \(passed) · 失败 \(failed) · 共 \(total)"
            statusLabel.textColor = .systemOrange
        }
    }

    private func scrollToRow(_ row: Int) {
        let indexPath = IndexPath(row: row, section: 0)
        tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension ProtocolTestViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return testCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TestCell", for: indexPath) as! TestResultCell
        cell.configure(index: indexPath.row + 1, name: testCases[indexPath.row].name, result: results[indexPath.row])
        return cell
    }
}

// MARK: - TestResultCell

class TestResultCell: UITableViewCell {

    private let indexLabel = UILabel()
    private let nameLabel = UILabel()
    private let resultLabel = UILabel()
    private let spinner = UIActivityIndicatorView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        indexLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        indexLabel.textColor = .secondaryLabel
        indexLabel.translatesAutoresizingMaskIntoConstraints = false
        indexLabel.widthAnchor.constraint(equalToConstant: 28).isActive = true

        nameLabel.font = .systemFont(ofSize: 14)
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        resultLabel.font = .systemFont(ofSize: 13)
        resultLabel.textAlignment = .right
        resultLabel.translatesAutoresizingMaskIntoConstraints = false

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true

        contentView.addSubview(indexLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(resultLabel)
        contentView.addSubview(spinner)

        NSLayoutConstraint.activate([
            indexLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            indexLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: indexLabel.trailingAnchor, constant: 4),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: resultLabel.leadingAnchor, constant: -8),

            resultLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            resultLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            resultLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 120),

            spinner.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(index: Int, name: String, result: TestResult) {
        indexLabel.text = "\(index)."
        nameLabel.text = name

        switch result {
        case .pending:
            resultLabel.text = "⏳"
            resultLabel.textColor = .tertiaryLabel
            spinner.stopAnimating()
            contentView.backgroundColor = nil
        case .running:
            resultLabel.text = ""
            spinner.startAnimating()
            contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.03)
        case .passed(let info):
            resultLabel.text = "✅ \(info)"
            resultLabel.textColor = .systemGreen
            spinner.stopAnimating()
            contentView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.03)
        case .failed(let error):
            resultLabel.text = "❌"
            resultLabel.textColor = .systemRed
            spinner.stopAnimating()
            contentView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.05)
            nameLabel.text = "\(name)\n\(error)"
            nameLabel.textColor = .systemRed
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.textColor = .label
        contentView.backgroundColor = nil
        spinner.stopAnimating()
    }
}
