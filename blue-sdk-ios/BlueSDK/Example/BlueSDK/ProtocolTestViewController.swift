// ProtocolTestViewController.swift
// BlueSDK Example - Protocol Command Automated Verification Page
// Executes all BLE protocol commands sequentially, pass ✅ / fail ❌ and skip on failure

import UIKit
import BlueSDK

/// Single test case
struct TestCase {
    let name: String
    let execute: (@escaping (Result<String, Error>) -> Void) -> Void
}

/// Test result
enum TestResult {
    case pending
    case running
    case passed(String)  // Additional info
    case failed(String)  // Error message
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
        btn.setTitle(S.startTest, for: .normal)
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
        label.text = S.protocolTestHint
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - State

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

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = S.protocolTest
        view.backgroundColor = .systemBackground
        setupUI()
        buildTestCases()
        results = Array(repeating: .pending, count: testCases.count)

        // Listen to SDK logs, show send/receive data
        BlueSDKManager.shared.setLogHandler { [weak self] level, tag, message in
            print("[BlueSDK][\(level)][\(tag)] \(message)")
            // Only show send/receive frames and key information
            if message.contains("TX:") || message.contains("RX:") ||
               message.contains("收到数据") || message.contains("发送帧") ||
               message.contains("auth") || message.contains("Auth") ||
               message.contains("failed") || message.contains("success") {
                self?.appendLog(message)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Restore main page logHandler
        BlueSDKManager.shared.setLogHandler(nil)
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

    // MARK: - Build Test Cases

    private func buildTestCases() {
        testCases = [
            // 1. Query device info
            TestCase(name: "Query Device Info (CMD=0x01)") { completion in
                BlueSDKManager.shared.queryDeviceInfo { result in
                    switch result {
                    case .success(let info):
                        completion(.success("MAC=\(info.macAddressString) v\(info.firmwareVersion)"))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            },

            // 2. Sync time
            TestCase(name: "Sync Time (CMD=0xE1)") { completion in
                BlueSDKManager.shared.syncTime { result in
                    switch result {
                    case .success: completion(.success("Sent"))
                    case .failure(let error): completion(.failure(error))
                    }
                }
            },

            // 3. Set alarm 1
            TestCase(name: "Set Alarm 1 08:00 (DPID=0x66)") { completion in
                BlueSDKManager.shared.setAlarm(index: 1, hour: 8, minute: 0, days: .all) { result in
                    switch result {
                    case .success(let a): completion(.success("\(String(format: "%02d:%02d", a.hour, a.minute)) Daily"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 4. Set alarm 2
            TestCase(name: "Set Alarm 2 12:30 (DPID=0x67)") { completion in
                BlueSDKManager.shared.setAlarm(index: 2, hour: 12, minute: 30, days: .weekdays) { result in
                    switch result {
                    case .success(let a): completion(.success("\(String(format: "%02d:%02d", a.hour, a.minute)) Weekdays"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 5. Delete alarm 2
            TestCase(name: "Delete Alarm 2 (DPID=0x67 FF)") { completion in
                BlueSDKManager.shared.deleteAlarm(index: 2) { result in
                    switch result {
                    case .success: completion(.success("Deleted"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 6. Set sound type A
            TestCase(name: "Set Sound Type A (DPID=0x6F val=01)") { completion in
                BlueSDKManager.shared.setSoundType(.typeA) { result in
                    switch result {
                    case .success: completion(.success("Type A"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 7. Set sound type B
            TestCase(name: "Set Sound Type B (DPID=0x6F val=02)") { completion in
                BlueSDKManager.shared.setSoundType(.typeB) { result in
                    switch result {
                    case .success: completion(.success("Type B"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 8. Set time format 24H
            TestCase(name: "Set Time Format 24H (DPID=0x73 val=01)") { completion in
                BlueSDKManager.shared.setTimeFormat(.hour24) { result in
                    switch result {
                    case .success: completion(.success("24-hour"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 9. Set time format 12H
            TestCase(name: "Set Time Format 12H (DPID=0x73 val=00)") { completion in
                BlueSDKManager.shared.setTimeFormat(.hour12) { result in
                    switch result {
                    case .success: completion(.success("12-hour"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 10. Clear all alarms
            TestCase(name: "Clear All Alarms (DPID=0x70)") { completion in
                BlueSDKManager.shared.clearAllAlarms { result in
                    switch result {
                    case .success: completion(.success("Cleared"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // --- Commands below may fail in low-power mode ---

            // 11. Set volume low
            TestCase(name: "⚡Set Volume Low (DPID=0x6E val=01)") { completion in
                BlueSDKManager.shared.setVolume(.low) { result in
                    switch result {
                    case .success: completion(.success("Low"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 12. Set volume high
            TestCase(name: "⚡Set Volume High (DPID=0x6E val=03)") { completion in
                BlueSDKManager.shared.setVolume(.high) { result in
                    switch result {
                    case .success: completion(.success("High"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 13. Silence on
            TestCase(name: "⚡Silence On (DPID=0x74 val=01)") { completion in
                BlueSDKManager.shared.setSilence(true) { result in
                    switch result {
                    case .success: completion(.success("Silence on"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 14. Silence off
            TestCase(name: "⚡Silence Off (DPID=0x74 val=00)") { completion in
                BlueSDKManager.shared.setSilence(false) { result in
                    switch result {
                    case .success: completion(.success("Silence off"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },

            // 15. Set alert duration
            TestCase(name: "⚡Alert Duration 5min (DPID=0x70)") { completion in
                BlueSDKManager.shared.setAlertDuration(5) { result in
                    switch result {
                    case .success: completion(.success("5 min"))
                    case .failure(let e): completion(.failure(e))
                    }
                }
            },
        ]
    }

    // MARK: - Test Execution

    @objc private func startTests() {
        guard !isRunning else { return }
        isRunning = true
        currentIndex = 0
        results = Array(repeating: .pending, count: testCases.count)
        tableView.reloadData()
        startButton.isEnabled = false
        startButton.setTitle(S.testing, for: .normal)
        statusLabel.text = S.runningProtocolTest
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

        // 0.5 second interval between tests
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
                        // Failed, skip and continue to next
                        self.currentIndex += 1
                        self.statusLabel.text = "[\(index + 1)/\(self.testCases.count)] \(self.testCases[index].name) ❌ \(S.testSkipped)"
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
        startButton.setTitle(S.retest, for: .normal)

        let passed = results.filter { if case .passed = $0 { return true }; return false }.count
        let failed = results.filter { if case .failed = $0 { return true }; return false }.count
        let total = testCases.count

        if failed == 0 {
            statusLabel.text = "\(S.allTestsPassed) \(passed)/\(total)"
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.text = String(format: S.testSummary, passed, failed, total)
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
