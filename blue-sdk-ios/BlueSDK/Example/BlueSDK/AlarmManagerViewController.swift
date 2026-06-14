// AlarmManagerViewController.swift
// BlueSDK Example - 闹钟管理页面
// 展示 7 个闹钟槽位状态，支持点击编辑、开关启用、删除

import UIKit
import BlueSDK

/// 闹钟槽位状态
struct AlarmSlot {
    let index: Int          // 1~7
    var isEnabled: Bool
    var hour: Int
    var minute: Int
    var weekMask: Int       // bit0=周一...bit6=周日
    var isSet: Bool         // 是否已设置（未设置时 hour=0xFF）

    var timeString: String {
        guard isSet else { return "--:--" }
        return String(format: "%02d:%02d", hour, minute)
    }

    var weekDescription: String {
        guard isSet else { return "" }
        if weekMask == 0x7F { return "每天" }
        if weekMask == 0x1F { return "工作日" }
        if weekMask == 0x60 { return "周末" }
        let days = ["一", "二", "三", "四", "五", "六", "日"]
        var result: [String] = []
        for i in 0..<7 {
            if weekMask & (1 << i) != 0 {
                result.append(days[i])
            }
        }
        return result.joined(separator: " ")
    }
}

class AlarmManagerViewController: UIViewController {

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(AlarmSlotCell.self, forCellReuseIdentifier: "AlarmCell")
        tv.rowHeight = 80
        return tv
    }()

    private lazy var clearButton: UIBarButtonItem = {
        UIBarButtonItem(title: "清空全部", style: .plain, target: self, action: #selector(clearAll))
    }()

    // MARK: - 状态

    private var alarms: [AlarmSlot] = (1...7).map {
        AlarmSlot(index: $0, isEnabled: false, hour: 0, minute: 0, weekMask: 0x7F, isSet: false)
    }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "闹钟管理"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = clearButton
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 查询设备信息后设备会自动上报所有闹钟配置
        // 这里暂时不主动查询，靠连接时设备上报
    }

    private func setupUI() {
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - 更新闹钟显示

    func updateAlarm(index: Int, hour: Int, minute: Int, weekMask: Int, enabled: Bool) {
        guard index >= 1, index <= 7 else { return }
        let isSet = hour != 0xFF && minute != 0xFF
        alarms[index - 1] = AlarmSlot(
            index: index,
            isEnabled: enabled && isSet,
            hour: isSet ? hour : 0,
            minute: isSet ? minute : 0,
            weekMask: weekMask,
            isSet: isSet
        )
        tableView.reloadRows(at: [IndexPath(row: index - 1, section: 0)], with: .automatic)
    }

    // MARK: - 操作

    @objc func dismissSelf() {
        dismiss(animated: true)
    }

    @objc private func clearAll() {
        let alert = UIAlertController(title: "清空闹钟", message: "确定清空所有闹钟设置？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { [weak self] _ in
            BlueSDK.shared.clearAllAlarms { result in
                if case .success = result {
                    DispatchQueue.main.async {
                        self?.alarms = (1...7).map {
                            AlarmSlot(index: $0, isEnabled: false, hour: 0, minute: 0, weekMask: 0x7F, isSet: false)
                        }
                        self?.tableView.reloadData()
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    private func showEditor(for slot: AlarmSlot) {
        let editor = AlarmEditorViewController(slot: slot)
        editor.onSave = { [weak self] updatedSlot in
            self?.updateAlarm(
                index: updatedSlot.index,
                hour: updatedSlot.hour,
                minute: updatedSlot.minute,
                weekMask: updatedSlot.weekMask,
                enabled: updatedSlot.isEnabled
            )
        }
        let nav = UINavigationController(rootViewController: editor)
        present(nav, animated: true)
    }

    private func deleteAlarm(at index: Int) {
        BlueSDK.shared.deleteAlarm(index: index) { [weak self] result in
            if case .success = result {
                DispatchQueue.main.async {
                    self?.alarms[index - 1] = AlarmSlot(
                        index: index, isEnabled: false, hour: 0, minute: 0, weekMask: 0x7F, isSet: false
                    )
                    self?.tableView.reloadRows(at: [IndexPath(row: index - 1, section: 0)], with: .automatic)
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource & Delegate

extension AlarmManagerViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 7 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AlarmCell", for: indexPath) as! AlarmSlotCell
        cell.configure(with: alarms[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showEditor(for: alarms[indexPath.row])
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let slot = alarms[indexPath.row]
        guard slot.isSet else { return nil }
        let delete = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            self?.deleteAlarm(at: slot.index)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

// MARK: - AlarmSlotCell

class AlarmSlotCell: UITableViewCell {

    private let indexLabel = UILabel()
    private let timeLabel = UILabel()
    private let weekLabel = UILabel()
    private let statusBadge = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator

        indexLabel.font = .systemFont(ofSize: 13, weight: .medium)
        indexLabel.textColor = .secondaryLabel
        indexLabel.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 32, weight: .light)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        weekLabel.font = .systemFont(ofSize: 13)
        weekLabel.textColor = .secondaryLabel
        weekLabel.translatesAutoresizingMaskIntoConstraints = false

        statusBadge.font = .systemFont(ofSize: 12, weight: .medium)
        statusBadge.textAlignment = .center
        statusBadge.layer.cornerRadius = 4
        statusBadge.clipsToBounds = true
        statusBadge.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(indexLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(weekLabel)
        contentView.addSubview(statusBadge)

        NSLayoutConstraint.activate([
            indexLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            indexLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),

            timeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            timeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 4),

            weekLabel.leadingAnchor.constraint(equalTo: timeLabel.trailingAnchor, constant: 12),
            weekLabel.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor),

            statusBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            statusBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            statusBadge.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with slot: AlarmSlot) {
        indexLabel.text = "闹钟 \(slot.index)"
        timeLabel.text = slot.timeString
        weekLabel.text = slot.weekDescription

        if slot.isSet {
            timeLabel.textColor = .label
            statusBadge.text = slot.isEnabled ? " 已开启 " : " 已关闭 "
            statusBadge.textColor = slot.isEnabled ? .systemGreen : .systemGray
            statusBadge.backgroundColor = (slot.isEnabled ? UIColor.systemGreen : UIColor.systemGray).withAlphaComponent(0.1)
        } else {
            timeLabel.textColor = .tertiaryLabel
            statusBadge.text = " 未设置 "
            statusBadge.textColor = .tertiaryLabel
            statusBadge.backgroundColor = UIColor.systemGray.withAlphaComponent(0.05)
        }
    }
}
