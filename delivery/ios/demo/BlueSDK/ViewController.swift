// ViewController.swift
// BlueSDK Example - LX-PD02 智能药盒 SDK 集成演示
// 紧凑单页布局，SnapKit 约束，适配 Dark/Light Mode

import UIKit
import BlueSDK
import SnapKit
import UserNotifications

class ViewController: UIViewController {

    // MARK: - 从设备列表传入的设备信息

    var deviceId: String?
    var deviceName: String?
    /// 是否从设备列表页进入（新流程）
    private var isFromDeviceList: Bool { deviceId != nil }

    // MARK: - 连接状态区

    private let statusDot = UIView()
    private let statusLabel = UILabel()
    private let scanButton = UIButton(type: .system)
    private let disconnectButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView()
    private let phoneMacField = UITextField()

    // MARK: - 全屏 Loading 遮罩

    private lazy var loadingOverlay: UIView = {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        overlay.isHidden = true

        let container = UIView()
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 12
        overlay.addSubview(container)

        let spinner = UIActivityIndicatorView()
        spinner.startAnimating()
        container.addSubview(spinner)

        let label = UILabel()
        label.text = S.connectingAuth
        label.font = .systemFont(ofSize: 15)
        label.textColor = .label
        label.textAlignment = .center
        container.addSubview(label)
        self.loadingLabel = label

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle(S.cancel, for: .normal)
        cancelBtn.setTitleColor(.systemRed, for: .normal)
        cancelBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        cancelBtn.addTarget(self, action: #selector(cancelConnection), for: .touchUpInside)
        container.addSubview(cancelBtn)

        container.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.equalTo(200)
            $0.height.equalTo(140)
        }
        spinner.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(20)
        }
        label.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(spinner.snp.bottom).offset(12)
        }
        cancelBtn.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().offset(-12)
        }

        return overlay
    }()
    private weak var loadingLabel: UILabel?

    // MARK: - 功能控件

    private let soundTypeSegment = UISegmentedControl(items: ["A", "B"])
    private let volumeSegment = UISegmentedControl(items: [S.low, S.medium, S.high])
    private let timeFormatSegment = UISegmentedControl(items: ["12H", "24H"])
    private let silenceSwitch = UISwitch()
    private let durationField = UITextField()
    private let logTextView = UITextView()

    // MARK: - 状态

    private var scannedDevices: [ScannedDevice] = []
    private var previousConnectionState: ConnectionState = .disconnected
    private var isAuthFailed = false

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "BlueSDK"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = nil
        buildUI()
        
        scanButton.isHidden = false
        disconnectButton.isHidden = true
        
        BlueSDKManager.shared.initialize()
        BlueSDKManager.shared.delegate = self
        
        // 如果从设备列表进入，隐藏扫描相关 UI
        if isFromDeviceList {
            scanButton.isHidden = true
            phoneMacField.isHidden = true
            title = deviceName ?? "BlueSDK"
            if BlueSDKManager.shared.connectionState == .authenticated {
                disconnectButton.isHidden = false
                updateStatus(S.connected, color: .systemGreen)
            }
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        // 将 SDK 内部所有日志（含收发数据）转发到界面日志窗口，同时保留终端输出
        BlueSDKManager.shared.setLogHandler { [weak self] level, tag, message in
            // 保留终端打印
            print("[BlueSDK][\(level)][\(tag)] \(message)")
            // 转发到界面
            let prefix: String
            switch level {
            case .debug: prefix = "📋"
            case .info:  prefix = "ℹ️"
            case .warn:  prefix = "⚠️"
            case .error: prefix = "❌"
            default:     prefix = ""
            }
            self?.log("\(prefix) \(message)")
        }
        log(S.sdkStarted)
        log("🔑 \(BlueSDKManager.shared.currentAuthKeyDisplay)")
    }

    // MARK: - UI 构建

    private func buildUI() {
        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = 10
        view.addSubview(mainStack)
        mainStack.snp.makeConstraints {
            $0.edges.equalTo(view.safeAreaLayoutGuide).inset(12)
        }

        // 1. 连接状态卡片
        let connCard = makeCard()
        mainStack.addArrangedSubview(connCard)

        let connStack = UIStackView()
        connStack.spacing = 8
        connStack.alignment = .center
        connCard.addSubview(connStack)
        connStack.snp.makeConstraints {
            $0.top.equalToSuperview().inset(10)
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.bottom.equalToSuperview().inset(10)
        }

        statusDot.backgroundColor = .systemGray
        statusDot.layer.cornerRadius = 5
        statusDot.snp.makeConstraints { $0.size.equalTo(10) }

        statusLabel.text = S.notConnected
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = .label

        configureCompactButton(scanButton, title: S.scan, color: .systemBlue)
        scanButton.addTarget(self, action: #selector(startScan), for: .touchUpInside)

        configureCompactButton(disconnectButton, title: S.disconnect, color: .systemRed)
        disconnectButton.addTarget(self, action: #selector(disconnect), for: .touchUpInside)

        connStack.addArrangedSubview(statusDot)
        connStack.addArrangedSubview(statusLabel)
        connStack.addArrangedSubview(loadingIndicator)
        connStack.addArrangedSubview(makeSpacer())
        connStack.addArrangedSubview(scanButton)
        connStack.addArrangedSubview(disconnectButton)

        // 密钥输入框（连接卡片下方）
        let keyRow = UIStackView()
        keyRow.spacing = 6
        keyRow.alignment = .center
        let keyLabel = makeSmallLabel(S.authKeyLabel)
        keyLabel.snp.makeConstraints { $0.width.equalTo(30) }
        phoneMacField.placeholder = S.customKeyHint
        phoneMacField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        phoneMacField.borderStyle = .roundedRect
        phoneMacField.autocapitalizationType = .allCharacters
        phoneMacField.autocorrectionType = .no
        keyRow.addArrangedSubview(keyLabel)
        keyRow.addArrangedSubview(phoneMacField)
        connCard.addSubview(keyRow)
        keyRow.snp.makeConstraints {
            $0.top.equalTo(connStack.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.bottom.equalToSuperview().offset(-8)
        }

        // 2. 快捷操作
        mainStack.addArrangedSubview(makeButtonRow([
            (S.deviceInfo, .systemIndigo, #selector(queryDeviceInfo)),
            (S.syncTime, .systemIndigo, #selector(syncTime)),
        ]))

        // 3. 音频设置卡片
        let audioCard = makeCard()
        mainStack.addArrangedSubview(audioCard)

        let audioStack = UIStackView()
        audioStack.axis = .vertical
        audioStack.spacing = 8
        audioCard.addSubview(audioStack)
        audioStack.snp.makeConstraints { $0.edges.equalToSuperview().inset(10) }

        soundTypeSegment.selectedSegmentIndex = 0
        soundTypeSegment.addTarget(self, action: #selector(soundTypeChanged), for: .valueChanged)
        audioStack.addArrangedSubview(makeLabeledRow(S.soundType, soundTypeSegment))

        volumeSegment.selectedSegmentIndex = 1
        volumeSegment.addTarget(self, action: #selector(volumeChanged), for: .valueChanged)
        audioStack.addArrangedSubview(makeLabeledRow(S.volume, volumeSegment))

        timeFormatSegment.selectedSegmentIndex = 1
        timeFormatSegment.addTarget(self, action: #selector(timeFormatChanged), for: .valueChanged)
        audioStack.addArrangedSubview(makeLabeledRow(S.timeFormat, timeFormatSegment))

        silenceSwitch.addTarget(self, action: #selector(silenceChanged), for: .valueChanged)
        audioStack.addArrangedSubview(makeLabeledRow(S.silence, silenceSwitch))

        durationField.text = "5"
        durationField.font = .systemFont(ofSize: 14)
        durationField.borderStyle = .roundedRect
        durationField.keyboardType = .numberPad
        durationField.textAlignment = .center
        durationField.snp.makeConstraints { $0.width.equalTo(44) }

        let durBtn = UIButton(type: .system)
        configureCompactButton(durBtn, title: S.setBtn, color: .systemTeal)
        durBtn.addTarget(self, action: #selector(setDuration), for: .touchUpInside)

        let durRow = UIStackView(arrangedSubviews: [makeSmallLabel(S.duration), durationField, makeSmallLabel(S.minutes), durBtn])
        durRow.spacing = 6
        durRow.alignment = .center
        audioStack.addArrangedSubview(durRow)

        // 4. 工具 & 系统
        mainStack.addArrangedSubview(makeButtonRow([
            (S.medicationRecords, .systemOrange, #selector(showRecords)),
            (S.alarmManager, .systemIndigo, #selector(showAlarmManager)),
            (S.faq, .systemGreen, #selector(showFAQ)),
        ]))

        mainStack.addArrangedSubview(makeButtonRow([
            (S.clearAlarms, .systemTeal, #selector(clearAllAlarms)),
            (S.restoreFactory, .systemRed, #selector(restoreFactory)),
            (S.clearBinding, .systemRed, #selector(clearLocalBinding)),
        ]))

        // 5. 日志（填充剩余空间）
        let logHeader = UIStackView(arrangedSubviews: [makeSmallLabel(S.log), makeSpacer()])
        let clearBtn = UIButton(type: .system)
        configureCompactButton(clearBtn, title: S.clear, color: .systemGray)
        clearBtn.addTarget(self, action: #selector(clearLog), for: .touchUpInside)
        logHeader.addArrangedSubview(clearBtn)
        logHeader.spacing = 8
        mainStack.addArrangedSubview(logHeader)

        // 日志区域（带版本号水印）
        let logContainer = UIView()
        logContainer.layer.cornerRadius = 8
        logContainer.clipsToBounds = true

        // 版本号水印
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let watermark = UILabel()
        watermark.text = "v\(version)"
        watermark.font = .systemFont(ofSize: 28, weight: .bold)
        watermark.textColor = UIColor.label.withAlphaComponent(0.05)
        watermark.textAlignment = .center
        logContainer.addSubview(watermark)

        logTextView.isEditable = false
        logTextView.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        logTextView.backgroundColor = .clear
        logTextView.textColor = .label
        logContainer.addSubview(logTextView)
        logContainer.backgroundColor = .secondarySystemBackground

        mainStack.addArrangedSubview(logContainer)
        logContainer.snp.makeConstraints { $0.height.greaterThanOrEqualTo(150) }
        logTextView.snp.makeConstraints { $0.edges.equalToSuperview() }
        watermark.snp.makeConstraints { $0.center.equalToSuperview() }

        // 全屏 Loading 遮罩（最后添加，确保在最上层）
        view.addSubview(loadingOverlay)
        loadingOverlay.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    // MARK: - UI 工具

    private func makeCard() -> UIView {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 10
        return v
    }

    private func configureCompactButton(_ btn: UIButton, title: String, color: UIColor) {
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = color
        btn.layer.cornerRadius = 6
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        btn.configuration = config
        btn.configuration?.background.backgroundColor = color
        btn.configuration?.baseForegroundColor = .white
        btn.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            return out
        }
    }

    private func makeButtonRow(_ items: [(String, UIColor, Selector)]) -> UIStackView {
        let s = UIStackView()
        s.spacing = 8
        s.distribution = .fillEqually
        for (title, color, action) in items {
            let b = UIButton(type: .system)
            configureCompactButton(b, title: title, color: color)
            b.addTarget(self, action: action, for: .touchUpInside)
            s.addArrangedSubview(b)
        }
        return s
    }

    private func makeLabeledRow(_ label: String, _ control: UIView) -> UIStackView {
        let l = makeSmallLabel(label)
        l.snp.makeConstraints { $0.width.equalTo(56) }
        let s = UIStackView(arrangedSubviews: [l, control])
        s.spacing = 8
        s.alignment = .center
        return s
    }

    private func makeSmallLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        l.setContentHuggingPriority(.required, for: .horizontal)
        return l
    }

    private func makeSpacer() -> UIView {
        let v = UIView()
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return v
    }

    @objc private func cancelConnection() {
        BlueSDKManager.shared.stopScan()
        BlueSDKManager.shared.disconnect()
        // 立即同步更新 UI（不依赖 delegate 回调）
        loadingOverlay.isHidden = true
        loadingIndicator.stopAnimating()
        scannedDevices.removeAll()
        scanButton.isEnabled = true
        statusLabel.text = S.notConnected
        statusDot.backgroundColor = .systemGray
        previousConnectionState = .disconnected
        log(S.userCancelled)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func showLoading(_ text: String = S.connectingAuth) {
        loadingLabel?.text = text
        loadingOverlay.isHidden = false
    }

    private func hideLoading() {
        loadingOverlay.isHidden = true
    }

    // MARK: - 扫描连接

    @objc private func startScan() {
        scanButton.isEnabled = false
        showLoading(S.scanConnecting)

        // 读取自定义密钥输入框
        let customKey = phoneMacField.text?.trimmingCharacters(in: .whitespaces).uppercased() ?? ""
        if customKey.count == 12 {
            BlueSDKManager.shared.config.customPhoneMac = customKey
            log(S.scanningCustomKey.replacingOccurrences(of: "%@", with: customKey))
        } else if customKey.count == 4 {
            BlueSDKManager.shared.fixedAuthKey = customKey
            log(S.scanningFixedKey.replacingOccurrences(of: "%@", with: customKey))
        } else {
            BlueSDKManager.shared.fixedAuthKey = nil
            BlueSDKManager.shared.config.customPhoneMac = nil
            log(S.scanningAuto)
        }
        updateStatus(S.scanning, color: .systemOrange)
        scannedDevices.removeAll()
        BlueSDKManager.shared.startScan(timeout: 10) { [weak self] event in
            guard let self = self else { return }
            switch event {
            case .deviceFound(let device):
                guard self.scannedDevices.isEmpty else { return }
                self.scannedDevices.append(device)
                self.log("\(S.found) \(device.deviceName)")
                self.showLoading(S.connectingAuth)
                BlueSDKManager.shared.connect(device)
                BlueSDKManager.shared.stopScan()
            case .error(let error):
                self.log("❌ \(error.localizedDescription)")
                self.updateStatus(S.scanFailed, color: .systemRed)
                self.hideLoading()
                DispatchQueue.main.async { self.scanButton.isEnabled = true }
            case .stopped:
                if self.scannedDevices.isEmpty {
                    self.log("⏹ \(S.scanTimeout)")
                    self.hideLoading()
                    DispatchQueue.main.async { self.scanButton.isEnabled = true }
                }
            }
        }
    }

    @objc private func disconnect() {
        BlueSDKManager.shared.disconnect()
        log(S.disconnected)
    }

    @objc private func queryDeviceInfo() {
        BlueSDKManager.shared.queryDeviceInfo { [weak self] r in
            switch r {
            case .success(let info): self?.log("📱 MAC:\(info.macAddressString) v\(info.firmwareVersion)")
            case .failure(let e): self?.log("❌ \(e.localizedDescription)")
            }
        }
    }

    @objc private func syncTime() {
        BlueSDKManager.shared.syncTime { [weak self] r in
            if case .success = r { self?.log("⏰ Time synced") }
            else if case .failure(let e) = r { self?.log("❌ \(e.localizedDescription)") }
        }
    }

    @objc private func showAlarmManager() {
        let vc = AlarmManagerViewController()
        if let nav = navigationController { nav.pushViewController(vc, animated: true) }
        else {
            let nav = UINavigationController(rootViewController: vc)
            vc.navigationItem.leftBarButtonItem = UIBarButtonItem(title: S.back, style: .plain, target: vc, action: #selector(AlarmManagerViewController.dismissSelf))
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    @objc private func clearAllAlarms() {
        confirm(S.clearAlarmsTitle, msg: S.clearAlarmsMsg) {
            BlueSDKManager.shared.clearAllAlarms { [weak self] r in
                if case .success = r { self?.log("⏰ \(S.alarmsCleared)") }
                else if case .failure(let e) = r { self?.log("❌ \(e.localizedDescription)") }
            }
        }
    }

    // MARK: - 音频

    @objc private func soundTypeChanged(_ s: UISegmentedControl) {
        s.isEnabled = false
        BlueSDKManager.shared.setSoundType([.typeA, .typeB][s.selectedSegmentIndex]) { [weak self] r in
            DispatchQueue.main.async { s.isEnabled = true }
            if case .success = r { self?.log("🔊 Sound set") }
            else if case .failure(let e) = r { self?.log("❌ \(e.localizedDescription)") }
        }
    }

    @objc private func volumeChanged(_ s: UISegmentedControl) {
        s.isEnabled = false
        BlueSDKManager.shared.setVolume([.low, .medium, .high][s.selectedSegmentIndex]) { [weak self] r in
            DispatchQueue.main.async { s.isEnabled = true }
            if case .success = r { self?.log("🔈 Volume set") }
            else if case .failure(let e) = r { self?.log("❌ \(e.localizedDescription)") }
        }
    }

    @objc private func timeFormatChanged(_ s: UISegmentedControl) {
        s.isEnabled = false
        BlueSDKManager.shared.setTimeFormat(s.selectedSegmentIndex == 0 ? .hour12 : .hour24) { [weak self] r in
            DispatchQueue.main.async { s.isEnabled = true }
            if case .success = r { self?.log("🕐 Time format set") }
            else if case .failure(let e) = r { self?.log("❌ \(e.localizedDescription)") }
        }
    }

    @objc private func silenceChanged(_ s: UISwitch) {
        BlueSDKManager.shared.setSilence(s.isOn) { [weak self] r in
            if case .success = r { self?.log(s.isOn ? "🔇 Mute ON" : "🔔 Mute OFF") }
            else if case .failure(let e) = r { self?.log("❌ \(e.localizedDescription)") }
        }
    }

    @objc private func setDuration() {
        guard let t = durationField.text, let m = Int(t), m >= 1, m <= 5 else {
            log("❌ \(S.durationError)")
            return
        }
        BlueSDKManager.shared.setAlertDuration(m) { [weak self] r in
            if case .success = r { self?.log("⏱ Duration \(m)min") }
            else if case .failure(let e) = r { self?.log("❌ \(e.localizedDescription)") }
        }
    }

    // MARK: - 系统

    @objc private func restoreFactory() {
        confirm(S.restoreFactoryTitle, msg: S.restoreFactoryMsg) {
            BlueSDKManager.shared.restoreFactory { [weak self] r in
                if case .success = r {
                    MedicationDatabase.shared.deleteAll()
                    self?.log("✅ \(S.factoryRestored)")
                } else if case .failure(let e) = r {
                    self?.log("❌ \(e.localizedDescription)")
                }
            }
        }
    }

    @objc private func clearLocalBinding() {
        confirm(S.clearBindingTitle, msg: S.clearBindingMsg) {
            BlueSDKManager.shared.clearBinding { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        AlarmStorage.shared.clearAll()
                        MedicationDatabase.shared.deleteAll()
                        self?.log("✅ \(S.unbindSuccess)")
                        self?.hideLoading()
                        // 返回设备列表页
                        if self?.isFromDeviceList == true {
                            self?.navigationController?.popViewController(animated: true)
                        }
                    case .failure(let error):
                        self?.log("❌ \(S.unbindFailed)：\(error.localizedDescription)")
                        self?.hideLoading()
                    }
                }
            }
        }
    }

    @objc private func showRecords() {
        pushOrPresent(MedicationRecordsViewController())
    }

    @objc private func showFAQ() {
        pushOrPresent(FAQViewController())
    }

    // MARK: - 日志

    @objc private func clearLog() { logTextView.text = "" }

    private func log(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        DispatchQueue.main.async { [weak self] in
            self?.logTextView.text += "[\(ts)] \(msg)\n"
            let end = NSRange(location: (self?.logTextView.text.count ?? 1) - 1, length: 1)
            self?.logTextView.scrollRangeToVisible(end)
        }
    }

    private func updateStatus(_ text: String, color: UIColor = .systemGray) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = text
            self?.statusDot.backgroundColor = color
        }
    }

    // MARK: - 辅助

    @objc private func handleAuthFailed() {
        isAuthFailed = true
        loadingOverlay.isHidden = true
        loadingIndicator.stopAnimating()
        scanButton.isEnabled = true
        scannedDevices.removeAll()
        statusLabel.text = S.authFailedStatus
        statusDot.backgroundColor = .systemRed
        previousConnectionState = .disconnected

        guard presentedViewController == nil else { return }
        log("🔐 Auth failed")
        let a = UIAlertController(title: S.authFailedTitle, message: S.authFailedMsg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: S.confirm, style: .default))
        present(a, animated: true)
    }

    private func topVC() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let p = top?.presentedViewController { top = p }
        return top ?? self
    }

    private func confirm(_ title: String, msg: String, action: @escaping () -> Void) {
        let a = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        a.addAction(UIAlertAction(title: S.confirm, style: .destructive) { _ in action() })
        present(a, animated: true)
    }

    private func pushOrPresent(_ vc: UIViewController) {
        if let nav = navigationController { nav.pushViewController(vc, animated: true) }
        else {
            let nav = UINavigationController(rootViewController: vc)
            if let dismissable = vc as? DismissableVC {
                vc.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: dismissable, action: #selector(DismissableVC.dismissSelf))
            }
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }
}

// MARK: - BlueSDKDelegate

extension ViewController: BlueSDKDelegate {
    func blueSDK(_ sdk: BlueSDKManager, didChangeConnectionState state: ConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
            case .disconnected:
                self.scanButton.isHidden = self.isFromDeviceList ? true : false
                self.disconnectButton.isHidden = true
                self.hideLoading()
                if self.isAuthFailed {
                    self.isAuthFailed = false
                } else {
                    self.updateStatus(S.notConnected, color: .systemGray)
                    self.loadingIndicator.stopAnimating()
                    self.scanButton.isEnabled = true
                    self.hideLoading()
                    // 从设备列表进入时，断开连接自动返回
                    if self.isFromDeviceList {
                        if self.previousConnectionState == .authenticated || self.previousConnectionState == .connected {
                            self.navigationController?.popViewController(animated: true)
                            return
                        }
                    }
                    // 设备意外断开弹窗提示
                    if self.previousConnectionState == .authenticated || self.previousConnectionState == .connected {
                        self.log("⚠️ \(S.deviceDisconnectedToast)")
                        let alert = UIAlertController(
                            title: S.disconnectedTitle,
                            message: S.disconnectedMsg,
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: S.ok, style: .default))
                        self.present(alert, animated: true)
                    }
                }
            case .connecting:
                self.scanButton.isHidden = true
                self.disconnectButton.isHidden = true
                self.updateStatus(S.connecting, color: .systemOrange)
                self.loadingIndicator.startAnimating()
            case .connected:
                self.scanButton.isHidden = true
                self.disconnectButton.isHidden = true
                self.updateStatus(S.authenticating, color: .systemYellow)
                self.loadingIndicator.startAnimating()
            case .authenticated:
                self.scanButton.isHidden = true
                self.disconnectButton.isHidden = false
                self.updateStatus(S.connected, color: .systemGreen)
                self.loadingIndicator.stopAnimating()
                self.hideLoading()
            case .reconnecting:
                self.scanButton.isHidden = true
                self.disconnectButton.isHidden = true
                self.updateStatus(S.reconnecting, color: .systemOrange)
                self.loadingIndicator.startAnimating()
            @unknown default: break
            }

            if state == .disconnected { self.scannedDevices.removeAll() }
            self.previousConnectionState = state
        }
    }

    func blueSDK(_ sdk: BlueSDKManager, didAuthenticateWithSuccess success: Bool, error: BlueError?) {
        if !success {
            log("🔐 Auth failed")
            handleAuthFailed()
        }
    }
    
    func blueSDKDidRequestTimeSync(_ sdk: BlueSDKManager) { log("⏰ Time sync (auto)") }
    func blueSDK(_ sdk: BlueSDKManager, didUpdateAlarm alarm: AlarmInfo) {
        log("⏰ Alarm\(alarm.index) \(String(format: "%02d:%02d", alarm.hour, alarm.minute))")
        // 设备上报闹钟变更，同步更新本地存储
        let slot = AlarmSlot(
            index: alarm.index,
            isEnabled: true,
            hour: alarm.hour,
            minute: alarm.minute,
            weekMask: alarm.weekMask,
            isSet: alarm.hour != 0xFF && alarm.minute != 0xFF
        )
        AlarmStorage.shared.save(slot: slot)
    }
    func blueSDK(_ sdk: BlueSDKManager, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo) { log("🔔 Alarm\(alarmIndex) ringing") }
    func blueSDK(_ sdk: BlueSDKManager, didAlarmTimeout alarmIndex: Int, alarmInfo: AlarmInfo) { log("⚠️ Alarm\(alarmIndex) timeout") }

    func blueSDK(_ sdk: BlueSDKManager, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus) {
        let statusText = S.isZh ? status.displayNameZh : status.displayNameEn
        log("💊 Alarm\(alarmIndex) \(statusText)")
        // 不入库 — 等 didReceiveMedicationRecord 上报完整记录（含设定时间和实际时间）
    }

    func blueSDK(_ sdk: BlueSDKManager, didReceiveMedicationRecord record: MedicationRecord) {
        let statusText = S.isZh ? record.status.displayNameZh : record.status.displayNameEn
        log("📋 Record: Alarm\(record.alarmIndex) \(statusText)")
        MedicationDatabase.shared.insert(timestamp: record.timestamp, alarmIndex: record.alarmIndex, alarmHour: record.alarmHour, alarmMinute: record.alarmMinute, status: record.status.rawValue)
    }

    func blueSDK(_ sdk: BlueSDKManager, didChangeSoundType type: SoundType) {
        log("🔊 Sound changed: \(type)")
        DispatchQueue.main.async { [weak self] in
            switch type {
            case .mute:
                self?.soundTypeSegment.selectedSegmentIndex = UISegmentedControlNoSegment
                self?.silenceSwitch.setOn(true, animated: true)
            case .typeA:
                self?.soundTypeSegment.selectedSegmentIndex = 0
                self?.silenceSwitch.setOn(false, animated: true)
            case .typeB:
                self?.soundTypeSegment.selectedSegmentIndex = 1
                self?.silenceSwitch.setOn(false, animated: true)
            default: break
            }
        }
    }
    func blueSDK(_ sdk: BlueSDKManager, didChangeTimeFormat format: TimeFormat) {
        log("🕐 Time format changed")
        DispatchQueue.main.async { [weak self] in
            switch format {
            case .hour12: self?.timeFormatSegment.selectedSegmentIndex = 0
            case .hour24: self?.timeFormatSegment.selectedSegmentIndex = 1
            @unknown default: break
            }
        }
    }
    func blueSDKDidReportLowBattery(_ sdk: BlueSDKManager) { log("🪫 Low battery") }
    func blueSDK(_ sdk: BlueSDKManager, didChangeAlertDuration minutes: Int) {
        log("⏱ Alert duration: \(minutes)min")
        DispatchQueue.main.async { [weak self] in
            self?.durationField.text = "\(minutes)"
        }
    }

    func blueSDK(_ sdk: BlueSDKManager, didReceiveMedicationNotification type: MedicationNotificationType) {
        switch type {
        case .ringing:
            log("🔔 Alarm ringing, awaiting medication")
            // 前台时弹窗提醒
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let alert = UIAlertController(
                    title: S.alarmRingingTitle,
                    message: S.alarmRingingMsg,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: S.ok, style: .default))
                self.present(alert, animated: true)
            }
        case .timeout:
            log("⚠️ Timeout, medication missed")
            // 推送漏服通知
            let content = UNMutableNotificationContent()
            content.title = S.missedTitle
            content.body = S.missedMsg
            content.sound = UNNotificationSound.default()
            let request = UNNotificationRequest(identifier: "missed_\(Date().timeIntervalSince1970)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        case .taken:
            log("✅ Medication taken")
            // 鼓励通知/弹窗
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let alert = UIAlertController(
                    title: S.takenTitle,
                    message: S.takenMsg,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: S.ok, style: .default))
                self.present(alert, animated: true)
            }
        @unknown default: break
        }
    }
    func blueSDK(_ sdk: BlueSDKManager, didEncounterError error: BlueError) { log("⚠️ \(error.localizedDescription)") }
}

// MARK: - DismissableVC Protocol

@objc protocol DismissableVC {
    @objc func dismissSelf()
}

extension AlarmManagerViewController: DismissableVC {}
extension MedicationRecordsViewController: DismissableVC {}
