// ViewController.swift
// BlueSDK Example - LX-PD02 智能药盒 SDK 集成演示

import UIKit
import BlueSDK

class ViewController: UIViewController {

    // MARK: - UI 组件

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 12
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "状态：未连接"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var logTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.backgroundColor = UIColor.systemGray6
        tv.layer.cornerRadius = 8
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: - 状态

    private var scannedDevices: [ScannedDevice] = []
    private let phoneMac: [UInt8] = [0xC7, 0x50, 0xB2, 0xAA, 0xC3, 0xF3]
    private let deviceMac: [UInt8] = [0xA6, 0xC0, 0x82, 0x00, 0xA1, 0xC2]

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "BlueSDK Demo"
        view.backgroundColor = .systemBackground
        setupUI()
        BlueSDK.shared.delegate = self
        log("BlueSDK Demo 已启动")
    }

    // MARK: - UI 搭建

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])

        stackView.addArrangedSubview(statusLabel)

        stackView.addArrangedSubview(makeSectionLabel("连接管理"))
        stackView.addArrangedSubview(makeButton("检查蓝牙权限", action: #selector(checkPermissions)))
        stackView.addArrangedSubview(makeButton("开始扫描设备", action: #selector(startScan)))
        stackView.addArrangedSubview(makeButton("停止扫描", action: #selector(stopScan)))
        stackView.addArrangedSubview(makeButton("断开连接", action: #selector(disconnect), style: .destructive))

        stackView.addArrangedSubview(makeSectionLabel("认证"))
        stackView.addArrangedSubview(makeButton("发送密钥认证", action: #selector(authenticate)))

        stackView.addArrangedSubview(makeSectionLabel("设备信息"))
        stackView.addArrangedSubview(makeButton("查询设备信息", action: #selector(queryDeviceInfo)))
        stackView.addArrangedSubview(makeButton("同步当前时间", action: #selector(syncTime)))

        stackView.addArrangedSubview(makeSectionLabel("闹钟管理"))
        stackView.addArrangedSubview(makeButton("设置闹钟1（08:00 每天）", action: #selector(setAlarm1)))
        stackView.addArrangedSubview(makeButton("设置闹钟2（12:30 工作日）", action: #selector(setAlarm2)))
        stackView.addArrangedSubview(makeButton("删除闹钟1", action: #selector(deleteAlarm1)))
        stackView.addArrangedSubview(makeButton("清空所有闹钟", action: #selector(clearAllAlarms), style: .destructive))

        stackView.addArrangedSubview(makeSectionLabel("音频与系统设置"))
        stackView.addArrangedSubview(makeButton("设置音量：中", action: #selector(setVolumeMedium)))
        stackView.addArrangedSubview(makeButton("设置铃声：类型A", action: #selector(setSoundTypeA)))
        stackView.addArrangedSubview(makeButton("设置时间格式：24小时制", action: #selector(setTimeFormat24)))
        stackView.addArrangedSubview(makeButton("静音开", action: #selector(setSilenceOn)))

        stackView.addArrangedSubview(makeSectionLabel("日志"))
        stackView.addArrangedSubview(makeButton("清空日志", action: #selector(clearLog)))

        stackView.addArrangedSubview(logTextView)
        logTextView.heightAnchor.constraint(equalToConstant: 200).isActive = true
    }

    // MARK: - 按钮动作

    @objc private func checkPermissions() {
        let status = BlueSDK.shared.checkPermissions()
        switch status {
        case .granted:       log("✅ 蓝牙权限：已授权")
        case .denied:        log("❌ 蓝牙权限：已拒绝，请在设置中开启")
        case .notDetermined: log("⚠️ 蓝牙权限：尚未请求，将在首次扫描时触发")
        @unknown default:    break
        }
    }

    @objc private func startScan() {
        log("开始扫描 LX-PD02 设备...")
        scannedDevices.removeAll()
        BlueSDK.shared.startScan(
            onDeviceFound: { [weak self] device in
                guard let self = self else { return }
                self.log("📡 发现设备：\(device.deviceName)，RSSI：\(device.rssi) dBm")
                // 自动连接第一个发现的设备
                if self.scannedDevices.isEmpty {
                    self.scannedDevices.append(device)
                    self.log("🔗 正在连接：\(device.deviceName)...")
                    BlueSDK.shared.connect(device)
                    BlueSDK.shared.stopScan()
                }
            },
            onError: { [weak self] error in
                self?.log("❌ 扫描错误：\(error.localizedDescription)")
            }
        )
    }

    @objc private func stopScan() {
        BlueSDK.shared.stopScan()
        log("扫描已停止")
    }

    @objc private func disconnect() {
        BlueSDK.shared.disconnect()
        log("已主动断开连接")
        updateStatus("未连接")
    }

    @objc private func authenticate() {
        log("发送密钥认证包...")
        BlueSDK.shared.authenticate(phoneMac: phoneMac, deviceMac: deviceMac) { [weak self] result in
            switch result {
            case .success:
                self?.log("✅ 认证成功，可执行业务指令")
                self?.updateStatus("已认证")
            case .failure(let error):
                self?.log("❌ 认证失败：\(error.localizedDescription)")
            }
        }
    }

    @objc private func queryDeviceInfo() {
        BlueSDK.shared.queryDeviceInfo { [weak self] result in
            switch result {
            case .success(let info):
                self?.log("✅ 设备信息：固件版本 \(info.firmwareVersion)")
            case .failure(let error):
                self?.log("❌ 查询失败：\(error.localizedDescription)")
            }
        }
    }

    @objc private func syncTime() {
        BlueSDK.shared.syncTime { [weak self] result in
            switch result {
            case .success:
                self?.log("✅ 时间同步成功：\(Date())")
            case .failure(let error):
                self?.log("❌ 时间同步失败：\(error.localizedDescription)")
            }
        }
    }

    @objc private func setAlarm1() {
        BlueSDK.shared.setAlarm(index: 1, hour: 8, minute: 0, weekMask: 0x7F) { [weak self] result in
            switch result {
            case .success(let alarm):
                self?.log("✅ 闹钟\(alarm.index)已设置：\(String(format: "%02d:%02d", alarm.hour, alarm.minute)) 每天")
            case .failure(let error):
                self?.log("❌ 设置失败：\(error.localizedDescription)")
            }
        }
    }

    @objc private func setAlarm2() {
        BlueSDK.shared.setAlarm(index: 2, hour: 12, minute: 30, weekMask: 0x3E) { [weak self] result in
            switch result {
            case .success(let alarm):
                self?.log("✅ 闹钟\(alarm.index)已设置：\(String(format: "%02d:%02d", alarm.hour, alarm.minute)) 工作日")
            case .failure(let error):
                self?.log("❌ 设置失败：\(error.localizedDescription)")
            }
        }
    }

    @objc private func deleteAlarm1() {
        BlueSDK.shared.deleteAlarm(index: 1) { [weak self] result in
            switch result {
            case .success:  self?.log("✅ 闹钟1已删除")
            case .failure(let error): self?.log("❌ 删除失败：\(error.localizedDescription)")
            }
        }
    }

    @objc private func clearAllAlarms() {
        BlueSDK.shared.clearAllAlarms { [weak self] result in
            switch result {
            case .success:  self?.log("✅ 所有闹钟已清空")
            case .failure(let error): self?.log("❌ 清空失败：\(error.localizedDescription)")
            }
        }
    }

    @objc private func setVolumeMedium() {
        BlueSDK.shared.setVolume(.medium) { [weak self] result in
            switch result {
            case .success:  self?.log("✅ 音量已设置为：中")
            case .failure(let error): self?.log("❌ 设置失败：\(error.localizedDescription)")
            }
        }
    }

    @objc private func setSoundTypeA() {
        BlueSDK.shared.setSoundType(.typeA) { [weak self] result in
            switch result {
            case .success:  self?.log("✅ 铃声类型已设置为：A")
            case .failure(let error): self?.log("❌ 设置失败：\(error.localizedDescription)")
            }
        }
    }

    @objc private func setTimeFormat24() {
        BlueSDK.shared.setTimeFormat(.hour24) { [weak self] result in
            switch result {
            case .success:  self?.log("✅ 时间格式已设置为：24小时制")
            case .failure(let error): self?.log("❌ 设置失败：\(error.localizedDescription)")
            }
        }
    }

    @objc private func setSilenceOn() {
        BlueSDK.shared.setSilence(true) { [weak self] result in
            switch result {
            case .success:  self?.log("✅ 静音已开启")
            case .failure(let error): self?.log("❌ 设置失败：\(error.localizedDescription)")
            }
        }
    }

    @objc private func clearLog() {
        logTextView.text = ""
    }

    // MARK: - 辅助方法

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(timestamp)] \(message)\n"
        DispatchQueue.main.async { [weak self] in
            self?.logTextView.text += line
            let bottom = NSRange(location: (self?.logTextView.text.count ?? 1) - 1, length: 1)
            self?.logTextView.scrollRangeToVisible(bottom)
        }
    }

    private func updateStatus(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = "状态：\(text)"
        }
    }

    private func makeSectionLabel(_ title: String) -> UILabel {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        return label
    }

    private enum ButtonStyle { case normal, destructive }

    private func makeButton(_ title: String, action: Selector, style: ButtonStyle = .normal) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15)
        button.setTitleColor(style == .destructive ? .systemRed : .systemBlue, for: .normal)
        button.backgroundColor = UIColor.systemGray6
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
}

// MARK: - BlueSDKDelegate

extension ViewController: BlueSDKDelegate {

    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState) {
        let stateText: String
        switch state {
        case .disconnected:  stateText = "已断开"
        case .connecting:    stateText = "连接中..."
        case .connected:     stateText = "已连接（未认证）"
        case .authenticated: stateText = "已认证 ✅"
        case .reconnecting:  stateText = "重连中..."
        @unknown default:    stateText = "未知"
        }
        log("🔗 连接状态：\(stateText)")
        updateStatus(stateText)
    }

    func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError) {
        log(success ? "🔐 认证成功" : "🔐 认证失败：\(error.localizedDescription)")
    }

    func blueSDKDidRequestTimeSync(_ sdk: BlueSDK) {
        log("⏰ 设备请求时间同步，自动下发...")
        sdk.syncTime { [weak self] result in
            switch result {
            case .success:  self?.log("⏰ 时间同步完成")
            case .failure(let error): self?.log("⏰ 时间同步失败：\(error.localizedDescription)")
            }
        }
    }

    func blueSDK(_ sdk: BlueSDK, didUpdateAlarm alarm: AlarmInfo) {
        log("⏰ 设备端闹钟\(alarm.index)变更：\(String(format: "%02d:%02d", alarm.hour, alarm.minute))")
    }

    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo) {
        log("🔔 闹钟\(alarmIndex)开始响铃！\(String(format: "%02d:%02d", alarmInfo.hour, alarmInfo.minute))")
    }

    func blueSDK(_ sdk: BlueSDK, didAlarmTimeout alarmIndex: Int, alarmInfo: AlarmInfo) {
        log("⚠️ 闹钟\(alarmIndex)超时未取药！")
    }

    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus) {
        let statusText: String
        switch status {
        case .taken:    statusText = "✅ 按时取药"
        case .timeout:  statusText = "⏰ 超时取药"
        case .missed:   statusText = "❌ 漏服"
        case .early:    statusText = "⏩ 提前取药"
        @unknown default: statusText = "未知"
        }
        log("💊 闹钟\(alarmIndex)用药结果：\(statusText)")
    }

    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationRecord record: MedicationRecord) {
        // timestamp 为毫秒，转换为 Date
        let date = Date(timeIntervalSince1970: TimeInterval(record.timestamp) / 1000.0)
        let dateStr = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
        log("📋 用药记录：闹钟\(record.alarmIndex)，\(dateStr)，\(record.status)")
    }

    func blueSDK(_ sdk: BlueSDK, didChangeSoundType type: SoundType) {
        log("🔊 铃声类型变更：\(type)")
    }

    func blueSDK(_ sdk: BlueSDK, didChangeTimeFormat format: TimeFormat) {
        log("🕐 时间格式变更：\(format == .hour24 ? "24小时制" : "12小时制")")
    }
}
