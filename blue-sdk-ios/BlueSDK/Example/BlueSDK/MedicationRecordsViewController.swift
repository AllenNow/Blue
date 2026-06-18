// MedicationRecordsViewController.swift
// BlueSDK Example - 用药记录查看页面（支持日历选择日期查询）

import UIKit
import BlueSDK

class MedicationRecordsViewController: UIViewController {

    // MARK: - UI 组件

    private lazy var datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        if #available(iOS 14.0, *) {
            picker.preferredDatePickerStyle = .inline
        }
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        return picker
    }()

    private lazy var summaryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(MedicationRecordCell.self, forCellReuseIdentifier: "RecordCell")
        tv.rowHeight = UITableViewAutomaticDimension
        tv.estimatedRowHeight = 80
        tv.tableFooterView = UIView()
        return tv
    }()

    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "该日期暂无用药记录"
        label.font = .systemFont(ofSize: 15)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    private lazy var segmentControl: UISegmentedControl = {
        let seg = UISegmentedControl(items: ["按日期", "全部记录"])
        seg.selectedSegmentIndex = 0
        seg.translatesAutoresizingMaskIntoConstraints = false
        seg.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        return seg
    }()

    private lazy var deleteButton: UIBarButtonItem = {
        return UIBarButtonItem(title: "清空", style: .plain, target: self, action: #selector(deleteAll))
    }()

    // MARK: - 状态

    private var records: [MedicationEntry] = []
    private let db = MedicationDatabase.shared
    private weak var headerLabel: UILabel?

    /// 时间格式化器 — 跟随药盒当前时制（12H/24H）
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        if BlueSDK.shared.currentTimeFormat == .hour12 {
            df.dateFormat = "h:mm a"
        } else {
            df.dateFormat = "HH:mm"
        }
        return df
    }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "用药记录"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = deleteButton
        setupUI()
        loadRecords(for: datePicker.date)
        // 注册为 SDK 事件观察者，实时接收用药记录上报
        BlueSDK.shared.addObserver(self)
    }

    @objc func dismissSelf() {
        dismiss(animated: true)
    }

    // MARK: - UI 搭建

    private func setupUI() {
        view.addSubview(segmentControl)

        // 状态图例
        let legendStack = UIStackView()
        legendStack.axis = .horizontal
        legendStack.spacing = 12
        legendStack.alignment = .center
        legendStack.distribution = .fillEqually
        legendStack.translatesAutoresizingMaskIntoConstraints = false

        let legends: [(String, String, String)] = [
            ("✅", "按时取药", "On time"),
            ("⏰", "超时取药", "Late"),
            ("❌", "漏服", "Missed"),
            ("⏩", "提前取药", "Early"),
        ]
        for (emoji, zh, en) in legends {
            let label = UILabel()
            label.text = "\(emoji) \(SDKLocale.isZh ? zh : en)"
            label.font = .systemFont(ofSize: 11)
            label.textColor = .secondaryLabel
            label.textAlignment = .center
            legendStack.addArrangedSubview(label)
        }
        view.addSubview(legendStack)

        view.addSubview(datePicker)
        view.addSubview(summaryLabel)

        let headerLabel = UILabel()
        headerLabel.text = SDKLocale.isZh
            ? "设定时间 → 实际取药时间"
            : "Scheduled → Actual time"
        headerLabel.font = .systemFont(ofSize: 12, weight: .medium)
        headerLabel.textColor = .tertiaryLabel
        headerLabel.textAlignment = .center
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)
        self.headerLabel = headerLabel

        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            segmentControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            legendStack.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 6),
            legendStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            legendStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            datePicker.topAnchor.constraint(equalTo: legendStack.bottomAnchor, constant: 4),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            summaryLabel.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 4),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            headerLabel.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 6),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])
    }

    // MARK: - 数据加载

    private func loadRecords(for date: Date) {
        records = db.query(date: date)
        updateUI()
    }

    private func loadAllRecords() {
        records = db.queryAll()
        updateUI()
    }

    private func updateUI() {
        tableView.reloadData()
        emptyLabel.isHidden = !records.isEmpty

        if segmentControl.selectedSegmentIndex == 0 {
            let df = DateFormatter()
            df.dateFormat = "yyyy年M月d日"
            summaryLabel.text = "\(df.string(from: datePicker.date)) · \(records.count) 条记录"
        } else {
            summaryLabel.text = "共 \(records.count) 条记录"
        }
    }

    // MARK: - 事件

    @objc private func dateChanged() {
        if segmentControl.selectedSegmentIndex == 0 {
            loadRecords(for: datePicker.date)
        }
    }

    @objc private func segmentChanged() {
        datePicker.isHidden = segmentControl.selectedSegmentIndex == 1
        if segmentControl.selectedSegmentIndex == 0 {
            loadRecords(for: datePicker.date)
        } else {
            loadAllRecords()
        }
    }

    @objc private func deleteAll() {
        let alert = UIAlertController(title: "清空记录", message: "确定删除所有用药记录？此操作不可恢复。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.db.deleteAll()
            self?.records.removeAll()
            self?.updateUI()
        })
        present(alert, animated: true)
    }
}

// MARK: - BlueSDKDelegate（实时接收用药记录上报）

extension MedicationRecordsViewController: BlueSDKDelegate {
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationRecord record: MedicationRecord) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 重新加载当前视图的数据
            if self.segmentControl.selectedSegmentIndex == 0 {
                self.loadRecords(for: self.datePicker.date)
            } else {
                self.loadAllRecords()
            }
        }
    }

    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.segmentControl.selectedSegmentIndex == 0 {
                self.loadRecords(for: self.datePicker.date)
            } else {
                self.loadAllRecords()
            }
        }
    }
}

// MARK: - UITableViewDataSource & Delegate

extension MedicationRecordsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return records.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RecordCell", for: indexPath) as! MedicationRecordCell
        let record = records[indexPath.row]
        cell.configure(with: record, dateFormatter: dateFormatter, showDate: segmentControl.selectedSegmentIndex == 1)
        return cell
    }
}

// MARK: - 自定义 Cell

class MedicationRecordCell: UITableViewCell {

    private let emojiLabel = UILabel()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        emojiLabel.font = .systemFont(ofSize: 24)
        emojiLabel.textAlignment = .center
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        detailLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        detailLabel.textColor = .secondaryLabel
        detailLabel.textAlignment = .center
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(emojiLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            emojiLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            emojiLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),

            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 4),

            detailLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with record: MedicationEntry, dateFormatter: DateFormatter, showDate: Bool) {
        emojiLabel.text = record.statusEmoji
        titleLabel.text = SDKLocale.isZh
            ? "闹钟\(record.alarmIndex) · \(record.statusText)"
            : "Alarm \(record.alarmIndex) · \(record.statusText)"

        let eventTime = dateFormatter.string(from: record.date)
        if record.alarmHour > 0 || record.alarmMinute > 0 {
            detailLabel.text = SDKLocale.isZh
                ? "设定 \(record.alarmTimeString) → 实际 \(eventTime)"
                : "Scheduled \(record.alarmTimeString) → Actual \(eventTime)"
        } else if showDate {
            let df = DateFormatter()
            df.dateFormat = BlueSDK.shared.currentTimeFormat == .hour12 ? "M/d h:mm a" : "M/d HH:mm"
            detailLabel.text = df.string(from: record.date)
        } else {
            detailLabel.text = eventTime
        }
    }
}
