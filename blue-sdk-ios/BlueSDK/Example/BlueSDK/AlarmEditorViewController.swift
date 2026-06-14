// AlarmEditorViewController.swift
// BlueSDK Example - 闹钟编辑页面

import UIKit
import BlueSDK

class AlarmEditorViewController: UIViewController {

    // MARK: - 回调

    var onSave: ((AlarmSlot) -> Void)?

    // MARK: - UI

    private lazy var timePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        if #available(iOS 13.4, *) {
            picker.preferredDatePickerStyle = .wheels
        }
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()

    private lazy var weekStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var weekButtons: [UIButton] = []

    private lazy var saveButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("保存闹钟", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 12
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(save), for: .touchUpInside)
        return btn
    }()

    private lazy var deleteButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("删除闹钟", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15)
        btn.setTitleColor(.systemRed, for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(deleteAlarm), for: .touchUpInside)
        btn.isHidden = !slot.isSet
        return btn
    }()

    // MARK: - 状态

    private var slot: AlarmSlot
    private var selectedWeekMask: Int

    // MARK: - 初始化

    init(slot: AlarmSlot) {
        self.slot = slot
        self.selectedWeekMask = slot.isSet ? slot.weekMask : 0x7F
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "闹钟 \(slot.index)"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(cancel))
        setupUI()
        configureInitialValues()
    }

    private func setupUI() {
        let days = ["一", "二", "三", "四", "五", "六", "日"]
        for (i, day) in days.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(day, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            btn.tag = i
            btn.layer.cornerRadius = 18
            btn.heightAnchor.constraint(equalToConstant: 36).isActive = true
            btn.addTarget(self, action: #selector(weekTapped(_:)), for: .touchUpInside)
            weekButtons.append(btn)
            weekStack.addArrangedSubview(btn)
        }

        let repeatLabel = UILabel()
        repeatLabel.text = "重复"
        repeatLabel.font = .systemFont(ofSize: 15, weight: .medium)
        repeatLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(timePicker)
        view.addSubview(repeatLabel)
        view.addSubview(weekStack)
        view.addSubview(saveButton)
        view.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            timePicker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            timePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            timePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            timePicker.heightAnchor.constraint(equalToConstant: 200),

            repeatLabel.topAnchor.constraint(equalTo: timePicker.bottomAnchor, constant: 24),
            repeatLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            weekStack.topAnchor.constraint(equalTo: repeatLabel.bottomAnchor, constant: 12),
            weekStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            weekStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            weekStack.heightAnchor.constraint(equalToConstant: 36),

            saveButton.topAnchor.constraint(equalTo: weekStack.bottomAnchor, constant: 40),
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 50),

            deleteButton.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 16),
            deleteButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func configureInitialValues() {
        // 设置时间
        if slot.isSet {
            var comps = DateComponents()
            comps.hour = slot.hour
            comps.minute = slot.minute
            if let date = Calendar.current.date(from: comps) {
                timePicker.date = date
            }
        }
        // 设置周按钮状态
        updateWeekButtons()
    }

    private func updateWeekButtons() {
        for btn in weekButtons {
            let selected = (selectedWeekMask & (1 << btn.tag)) != 0
            btn.backgroundColor = selected ? UIColor.systemBlue : UIColor.systemGray5
            btn.setTitleColor(selected ? .white : .label, for: .normal)
        }
    }

    // MARK: - 操作

    @objc private func weekTapped(_ sender: UIButton) {
        selectedWeekMask ^= (1 << sender.tag)
        if selectedWeekMask == 0 { selectedWeekMask = (1 << sender.tag) } // 至少选一天
        updateWeekButtons()
    }

    @objc private func save() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: timePicker.date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0

        saveButton.isEnabled = false
        BlueSDK.shared.setAlarm(index: slot.index, hour: hour, minute: minute, weekMask: selectedWeekMask) { [weak self] result in
            DispatchQueue.main.async {
                self?.saveButton.isEnabled = true
                switch result {
                case .success(let alarm):
                    let updated = AlarmSlot(
                        index: alarm.index,
                        isEnabled: true,
                        hour: alarm.hour,
                        minute: alarm.minute,
                        weekMask: alarm.weekMask,
                        isSet: true
                    )
                    self?.onSave?(updated)
                    self?.dismiss(animated: true)
                case .failure(let error):
                    let alert = UIAlertController(title: "设置失败", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }

    @objc private func deleteAlarm() {
        BlueSDK.shared.deleteAlarm(index: slot.index) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    guard let self = self else { return }
                    let empty = AlarmSlot(index: self.slot.index, isEnabled: false, hour: 0, minute: 0, weekMask: 0x7F, isSet: false)
                    self.onSave?(empty)
                    self.dismiss(animated: true)
                }
            }
        }
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }
}
