// MedicationRecordsViewController.swift
// BlueSDK Example - 用药记录查看页面（支持日历选择日期查询）

import UIKit

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
        tv.rowHeight = 64
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
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "用药记录"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = deleteButton
        setupUI()
        loadRecords(for: datePicker.date)
    }

    @objc func dismissSelf() {
        dismiss(animated: true)
    }

    // MARK: - UI 搭建

    private func setupUI() {
        view.addSubview(segmentControl)
        view.addSubview(datePicker)
        view.addSubview(summaryLabel)
        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            segmentControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            datePicker.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 8),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            summaryLabel.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 4),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 8),
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
    private let timeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        emojiLabel.font = .systemFont(ofSize: 24)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .secondaryLabel
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        timeLabel.textColor = .secondaryLabel
        timeLabel.textAlignment = .right
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(emojiLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)
        contentView.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            emojiLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            emojiLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            emojiLabel.widthAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: emojiLabel.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with record: MedicationEntry, dateFormatter: DateFormatter, showDate: Bool) {
        emojiLabel.text = record.statusEmoji
        titleLabel.text = "闹钟\(record.alarmIndex) · \(record.statusText)"

        if showDate {
            let df = DateFormatter()
            df.dateFormat = "M/d HH:mm"
            detailLabel.text = df.string(from: record.date)
        } else {
            detailLabel.text = dateFormatter.string(from: record.date)
        }

        timeLabel.text = dateFormatter.string(from: record.date)
        timeLabel.isHidden = showDate
    }
}
