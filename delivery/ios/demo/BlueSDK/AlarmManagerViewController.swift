// AlarmManagerViewController.swift
// BlueSDK Example - Alarm Manager Page
// Displays 7 alarm slot states, supports tap to edit, toggle enable, and delete

import UIKit
import BlueSDK

/// Alarm slot state
struct AlarmSlot {
    let index: Int          // 1~7
    var isEnabled: Bool
    var hour: Int
    var minute: Int
    var weekMask: Int       // bit0=Mon...bit6=Sun
    var isSet: Bool         // Whether set (unset when hour=0xFF)
    var runState: AlarmRunState = .idle  // Run state: idle/ringing/ended

    var timeString: String {
        guard isSet else { return "--:--" }
        return String(format: "%02d:%02d", hour, minute)
    }

    /// Format time display based on 12/24 hour format
    func formatTime(is24Hour: Bool) -> String {
        guard isSet else { return "--:--" }
        if is24Hour {
            return String(format: "%02d:%02d", hour, minute)
        } else {
            let displayHour: Int
            switch hour {
            case 0: displayHour = 12
            case 1...12: displayHour = hour
            default: displayHour = hour - 12
            }
            let amPm = hour < 12 ? S.am : S.pm
            return String(format: "%d:%02d %@", displayHour, minute, amPm)
        }
    }

    var weekDescription: String {
        guard isSet else { return "" }
        if weekMask == 0x7F { return S.weekdayDaily }
        if weekMask == 0x1F { return S.weekdayWeekdays }
        if weekMask == 0x60 { return S.weekdayWeekend }
        let days = S.weekdays
        var result: [String] = []
        for i in 0..<7 {
            if weekMask & (1 << i) != 0 {
                result.append(days[i])
            }
        }
        return result.joined(separator: " ")
    }

    var runStateText: String {
        switch runState {
        case .idle: return ""
        case .ringing: return "🔔 \(S.alarmRinging)"
        case .ended: return "✅ \(S.alarmDone)"
        }
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
        UIBarButtonItem(title: S.clearAll, style: .plain, target: self, action: #selector(clearAll))
    }()

    // "Next alarm" card at top
    private let nextAlarmTimeLabel: UILabel = {
        let label = UILabel()
        label.text = "--:--"
        label.font = .monospacedDigitSystemFont(ofSize: 36, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let nextAlarmDescLabel: UILabel = {
        let label = UILabel()
        label.text = S.noActiveAlarms
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private lazy var nextAlarmCard: UIView = {
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.17, alpha: 1)
        card.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = S.nextAlarmTitle
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, nextAlarmTimeLabel, nextAlarmDescLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20)
        ])

        return card
    }()

    // MARK: - State

    private var alarms: [AlarmSlot] = AlarmStorage.shared.loadAll()

    /// Whether currently using 24-hour format
    private var is24Hour: Bool {
        return BlueSDKManager.shared.currentTimeFormat == .hour24
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = S.alarmManager
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = clearButton
        setupUI()
        // Register as SDK event observer to receive alarm changes from device in real time
        BlueSDKManager.shared.addObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh from local storage (may have been updated on other pages)
        alarms = AlarmStorage.shared.loadAll()
        tableView.reloadData()
        updateNextAlarm()
    }

    private func setupUI() {
        view.addSubview(nextAlarmCard)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            nextAlarmCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            nextAlarmCard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nextAlarmCard.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: nextAlarmCard.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Next Alarm Calculation

    private func updateNextAlarm() {
        let now = Calendar.current
        let nowHour = now.component(.hour, from: Date())
        let nowMinute = now.component(.minute, from: Date())
        // Calendar weekday 1=Sun...7=Sat → bit0=Sun
        let calDow = now.component(.weekday, from: Date())
        let todayBit = calDow - 1

        let activeAlarms = alarms.filter { $0.isSet && $0.isEnabled }
        guard !activeAlarms.isEmpty else {
            nextAlarmTimeLabel.text = "--:--"
            nextAlarmDescLabel.text = S.noActiveAlarms
            return
        }

        struct Candidate {
            let slot: AlarmSlot
            let minutesAway: Int
        }
        var candidates: [Candidate] = []

        let nowTotalMinutes = nowHour * 60 + nowMinute

        for alarm in activeAlarms {
            let alarmTotalMinutes = alarm.hour * 60 + alarm.minute
            var bestMinutesAway = Int.max

            for dayOffset in 0...6 {
                let checkDay = (todayBit + dayOffset) % 7
                guard alarm.weekMask & (1 << checkDay) != 0 else { continue }

                let minutesAway: Int
                if dayOffset == 0 {
                    let diff = alarmTotalMinutes - nowTotalMinutes
                    if diff <= 0 { continue } // Already passed today
                    minutesAway = diff
                } else {
                    minutesAway = dayOffset * 24 * 60 + alarmTotalMinutes - nowTotalMinutes
                }

                bestMinutesAway = minutesAway
                break
            }

            if bestMinutesAway != Int.max {
                candidates.append(Candidate(slot: alarm, minutesAway: bestMinutesAway))
            }
        }

        guard let next = candidates.min(by: { $0.minutesAway < $1.minutesAway }) else {
            nextAlarmTimeLabel.text = "--:--"
            nextAlarmDescLabel.text = S.noActiveAlarms
            return
        }

        nextAlarmTimeLabel.text = next.slot.formatTime(is24Hour: is24Hour)

        let hours = next.minutesAway / 60
        let mins = next.minutesAway % 60
        if hours > 0 {
            nextAlarmDescLabel.text = String(format: S.nextAlarmHoursMins, next.slot.index, hours, mins)
        } else {
            nextAlarmDescLabel.text = String(format: S.nextAlarmMins, next.slot.index, mins)
        }
    }

    // MARK: - Update Alarm Display

    func updateAlarm(index: Int, hour: Int, minute: Int, weekMask: Int, enabled: Bool, runState: AlarmRunState = .idle) {
        guard index >= 1, index <= 7 else { return }
        let isSet = hour != 0xFF && minute != 0xFF
        var slot = AlarmSlot(
            index: index,
            isEnabled: enabled && isSet,
            hour: isSet ? hour : 0,
            minute: isSet ? minute : 0,
            weekMask: weekMask,
            isSet: isSet
        )
        slot.runState = runState
        alarms[index - 1] = slot
        AlarmStorage.shared.save(slot: slot)
        tableView.reloadRows(at: [IndexPath(row: index - 1, section: 0)], with: .automatic)
        updateNextAlarm()
    }

    // MARK: - Actions

    @objc func dismissSelf() {
        dismiss(animated: true)
    }

    @objc private func clearAll() {
        let alert = UIAlertController(title: S.clearAlarmsTitle, message: S.clearAlarmsMsg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: S.clear, style: .destructive) { [weak self] _ in
            BlueSDKManager.shared.clearAllAlarms { result in
                if case .success = result {
                    DispatchQueue.main.async {
                        self?.alarms = (1...7).map {
                            AlarmSlot(index: $0, isEnabled: false, hour: 0, minute: 0, weekMask: 0x7F, isSet: false)
                        }
                        AlarmStorage.shared.clearAll()
                        self?.tableView.reloadData()
                        self?.updateNextAlarm()
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
        BlueSDKManager.shared.deleteAlarm(index: index) { [weak self] result in
            if case .success = result {
                DispatchQueue.main.async {
                    self?.alarms[index - 1] = AlarmSlot(
                        index: index, isEnabled: false, hour: 0, minute: 0, weekMask: 0x7F, isSet: false
                    )
                    AlarmStorage.shared.clear(index: index)
                    self?.tableView.reloadRows(at: [IndexPath(row: index - 1, section: 0)], with: .automatic)
                    self?.updateNextAlarm()
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
        cell.configure(with: alarms[indexPath.row], is24Hour: is24Hour)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showEditor(for: alarms[indexPath.row])
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let slot = alarms[indexPath.row]
        guard slot.isSet else { return nil }
        let delete = UIContextualAction(style: .destructive, title: S.delete) { [weak self] _, _, completion in
            self?.deleteAlarm(at: slot.index)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

// MARK: - BlueSDKDelegate (receive alarm changes and time format changes from device in real time)

extension AlarmManagerViewController: BlueSDKDelegate {
    func blueSDK(_ sdk: BlueSDKManager, didUpdateAlarm alarm: AlarmInfo) {
        DispatchQueue.main.async { [weak self] in
            self?.updateAlarm(
                index: alarm.index,
                hour: alarm.hour,
                minute: alarm.minute,
                weekMask: alarm.weekMask,
                enabled: true,
                runState: alarm.runState
            )
        }
    }

    func blueSDK(_ sdk: BlueSDKManager, didChangeTimeFormat format: TimeFormat) {
        DispatchQueue.main.async { [weak self] in
            // Refresh entire list and next alarm display when time format changes
            self?.tableView.reloadData()
            self?.updateNextAlarm()
        }
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

    func configure(with slot: AlarmSlot, is24Hour: Bool) {
        indexLabel.text = String(format: S.alarmSlotLabel, slot.index)
        timeLabel.text = slot.formatTime(is24Hour: is24Hour)
        weekLabel.text = slot.weekDescription

        if slot.isSet {
            timeLabel.textColor = .label
            // Show different labels based on run state
            switch slot.runState {
            case .ringing:
                statusBadge.text = " 🔔 \(S.alarmRinging) "
                statusBadge.textColor = .systemOrange
                statusBadge.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
            case .ended:
                statusBadge.text = " ✅ \(S.alarmDone) "
                statusBadge.textColor = .systemBlue
                statusBadge.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            case .idle:
                statusBadge.text = slot.isEnabled ? " \(S.alarmStatusOn) " : " \(S.alarmStatusOff) "
                statusBadge.textColor = slot.isEnabled ? .systemGreen : .systemGray
                statusBadge.backgroundColor = (slot.isEnabled ? UIColor.systemGreen : UIColor.systemGray).withAlphaComponent(0.1)
            @unknown default: break
            }
        } else {
            timeLabel.textColor = .tertiaryLabel
            statusBadge.text = " \(S.alarmStatusUnset) "
            statusBadge.textColor = .tertiaryLabel
            statusBadge.backgroundColor = UIColor.systemGray.withAlphaComponent(0.05)
        }
    }
}
