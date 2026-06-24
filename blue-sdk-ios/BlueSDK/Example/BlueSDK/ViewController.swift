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
        label.text = "连接认证中..."
        label.font = .systemFont(ofSize: 15)
        label.textColor = .label
        label.textAlignment = .center
        container.addSubview(label)
        self.loadingLabel = label

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("取消", for: .normal)
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

    private let soundTypeSegment = UISegmentedControl(items: ["A", "B", "C"])
    private let volumeSegment = UISegmentedControl(items: ["低", "中", "高"])
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: S.debug, style: .plain, target: self, action: #selector(openDebugPanel))
        buildUI()
        
        scanButton.isHidden = false
        disconnectButton.isHidden = true
        
        BlueSDK.shared.initialize()
        BlueSDK.shared.delegate = self
        
        // 如果从设备列表进入，隐藏扫描相关 UI
        if isFromDeviceList {
            scanButton.isHidden = true
            phoneMacField.isHidden = true
            title = deviceName ?? "BlueSDK"
            if BlueSDK.shared.connectionState == .authenticated {
                disconnectButton.isHidden = false
                updateStatus(S.connected, color: .systemGreen)
            }
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        // 将 SDK 内部所有日志（含收发数据）转发到界面日志窗口，同时保留终端输出
        BlueSDK.shared.setLogHandler { [weak self] level, tag, message in
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
        log("🔑 \(BlueSDK.shared.currentAuthKeyDisplay)")
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
        let keyLabel = makeSmallLabel(SDKLocale.s("密钥", "Key"))
        keyLabel.snp.makeConstraints { $0.width.equalTo(30) }
        phoneMacField.placeholder = SDKLocale.s("输入自定义ID(12位hex)，留空自动", "Custom ID(12 hex), empty=auto")
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
            (S.protocolTest, .systemPurple, #selector(showProtocolTest)),
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
        configureCompactButton(durBtn, title: "设置", color: .systemTeal)
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
        l.snp.makeConstraints { $0.width.equalTo(36) }
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
        BlueSDK.shared.stopScan()
        BlueSDK.shared.disconnect()
        // 立即同步更新 UI（不依赖 delegate 回调）
        loadingOverlay.isHidden = true
        loadingIndicator.stopAnimating()
        scannedDevices.removeAll()
        scanButton.isEnabled = true
        statusLabel.text = S.notConnected
        statusDot.backgroundColor = .systemGray
        previousConnectionState = .disconnected
        log("用户取消连接")
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func showLoading(_ text: String = "连接认证中...") {
        loadingLabel?.text = text
        loadingOverlay.isHidden = false
    }

    private func hideLoading() {
        loadingOverlay.isHidden = true
    }

    // MARK: - 扫描连接

    @objc private func startScan() {
        scanButton.isEnabled = false
        showLoading("扫描连接中...")

        // 读取自定义密钥输入框
        let customKey = phoneMacField.text?.trimmingCharacters(in: .whitespaces).uppercased() ?? ""
        if customKey.count == 12 {
            BlueSDK.shared.config.customPhoneMac = customKey
            log("扫描中...（自定义密钥：\(customKey)）")
        } else if customKey.count == 4 {
            BlueSDK.shared.fixedAuthKey = customKey
            log("扫描中...（固定密钥：\(customKey)）")
        } else {
            BlueSDK.shared.fixedAuthKey = nil
            BlueSDK.shared.config.customPhoneMac = nil
            log("扫描中...（自动密钥）")
        }
        updateStatus("扫描中...", color: .systemOrange)
        scannedDevices.removeAll()
        BlueSDK.shared.startScan(timeout: 10) { [weak self] event in
            guard let self = self else { return }
            switch event {
            case .deviceFound(let device):
                guard self.scannedDevices.isEmpty else { return }
                self.scannedDevices.append(device)
                self.log("发现 \(device.deviceName)")
                self.showLoading("连接认证中...")
                BlueSDK.shared.connect(device)
                BlueSDK.shared.stopScan()
            case .error(let error):
                self.log("❌ \(error.localizedDescription)")
                self.updateStatus(S.scanFailed, color: .systemRed)
                self.hideLoading()
                DispatchQueue.main.async { self.scanButton.isEnabled = true }
            case .stopped:
                if self.scannedDevices.isEmpty {
                    self.log("⏹ 扫描超时")
                    self.hideLoading()
                    DispatchQueue.main.async { self.scanButton.isEnabled = true }
                }
            }
        }
    }

    @objc private func disconnect() {
        BlueSDK.shared.disconnect()
        log("已断开")
    }

    @objc private func queryDeviceInfo() {
        BlueSDK.shared.queryDeviceInfo { [weak self] r in
            switch r {
            case .success(let info): self?.log("📱 MAC:\(info.macAddressString) v\(info.firmwareVersion)")
            case .failure(let e): self?.log("❌ \(e.localizedDescription)")
            }
        }
    }

    @objc private func syncTime() {
        BlueSDK.shared.syncTime { [weak self] r in
            if case .success = r { self?.log("⏰ 时间已同步") }
            else if case .failure(let e) = r { self?.log("❌ \(e.localizedDescription)") }
        }
    }

    @objc private func showAlarmManager() {
        let vc = AlarmManagerViewController()
        if let nav = navigationController { nav.pushViewController(vc, animated: true) }
        else {
            let nav = UINavigationController(rootViewController: vc)
            vc.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "返回", style: .plain, target: vc, action: #selector(AlarmManagerViewController.dismissSelf))
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    @objc private func clearAllAlarms() {
        confirm(S.clearAlarmsTitle, msg: S.clearAlarmsMsg) {
            BlueSDK.shared.clearAllAlarms { [weak self] r in
                if case .success = r { self?.log("⏰ 所有闹钟已清空") }
                else if case .failure(let e) = r { self?.log("❌ \(e.localizedDescription)") }
            }
        }
    }

    // MARK: - 音频

    @objc private func soundTypeChanged(_ s: UISegmentedControl) {
        s.isEnabled = false
        BlueSDK.shared.setSoundType([.typeA, .typeB, .typeC][s.selectedSegmentIndex]) { [weak self] r in
            DispatchQueue.main.async { s.isEnabled = true }
            if case .success = r { self?.log("🔊 铃声已设置") }
            else if case .failure(let e) = r { self?.log("❌ \(e.localizedDescription)") }
        }
    }

    @objc private func volumeChanged(_ s: UISegmentedControl) {
        s.isEnabled = false
        BlueSDK.shared.setVolume([.low, .medium, .high][s.selectedSegmentIndex]) { [weak self] r in
            DispatchQueue.main.async { s.isEnabled = true }
            if case .success = r { self?.log("🔈 音量已设置") }
            else if case .failure(let e) = r { self?.log("❌ \(e.localizedDescription)") }
        }
    }

    @objc private func timeFormatChanged(_ s: UISegmentedControl) {
        s.isEnabled = false
        BlueSDK.shared.setTimeFormat(s.selectedSegmentIndex == 0 ? .hour12 : .hour24) { [weak self] r in
            DispatchQueue.main.async { s.isEnabled = true }
            if case .success = r { self?.log("🕐 时制已设置") }
            else if case .failure(let e) = r { self?.log("❌ \(e.localizedDescription)") }
        }
    }

    @objc private func silenceChanged(_ s: UISwitch) {
        BlueSDK.shared.setSilence(s.isOn) { [weak self] r in
            if case .success = r { self?.log(s.isOn ? "🔇 静音开" : "🔔 静音关") }
            else if case .failure(let e) = r { self?.log("❌ \(e.localizedDescription)") }
        }
    }

    @objc private func setDuration() {
        guard let t = durationField.text, let m = Int(t), m >= 1, m <= 5 else {
            log("❌ 响铃时长范围：1~5分钟")
            return
        }
        BlueSDK.shared.setAlertDuration(m) { [weak self] r in
            if case .success = r { self?.log("⏱ 持续 \(m)分") }
            else if case .failure(let e) = r { self?.log("❌ \(e.localizedDescription)") }
        }
    }

    // MARK: - 系统

    @objc private func restoreFactory() {
        confirm(S.restoreFactoryTitle, msg: S.restoreFactoryMsg) {
            BlueSDK.shared.restoreFactory { [weak self] r in
                if case .success = r {
                    MedicationDatabase.shared.deleteAll()
                    self?.log("✅ 已恢复出厂，本地数据已清空")
                } else if case .failure(let e) = r {
                    self?.log("❌ \(e.localizedDescription)")
                }
            }
        }
    }

    @objc private func clearLocalBinding() {
        confirm(S.clearBindingTitle, msg: S.clearBindingMsg) {
            BlueSDK.shared.clearBinding { [weak self] result in
                switch result {
                case .success:
                    MedicationDatabase.shared.deleteAll()
                    self?.log("✅ 解绑成功，本地数据已清空")
                case .failure(let error):
                    self?.log("❌ 解绑失败：\(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func showRecords() {
        pushOrPresent(MedicationRecordsViewController())
    }

    @objc private func showProtocolTest() {
        pushOrPresent(ProtocolTestViewController())
    }

    @objc private func showFAQ() {
        pushOrPresent(FAQViewController())
    }

    // MARK: - 日志

    @objc private func clearLog() { logTextView.text = "" }

    @objc private func openDebugPanel() {
        let debugVC = DebugViewController()
        navigationController?.pushViewController(debugVC, animated: true)
    }

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
        statusLabel.text = "认证失败"
        statusDot.backgroundColor = .systemRed
        previousConnectionState = .disconnected

        guard presentedViewController == nil else { return }
        log("🔐 认证失败")
        let a = UIAlertController(title: "认证失败", message: "密钥不一致，请对设备长按按键恢复出厂设置后重试。", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "确定", style: .default))
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
        a.addAction(UIAlertAction(title: "取消", style: .cancel))
        a.addAction(UIAlertAction(title: "确定", style: .destructive) { _ in action() })
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
    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
            case .disconnected:
                self.scanButton.isHidden = self.isFromDeviceList ? true : false
                self.disconnectButton.isHidden = true
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
                        self.log("⚠️ 设备连接已断开")
                        let alert = UIAlertController(
                            title: SDKLocale.s("连接断开", "Disconnected"),
                            message: SDKLocale.s("设备连接已断开，请检查设备状态后重新连接。", "Device disconnected. Check device and reconnect."),
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: SDKLocale.s("确定", "OK"), style: .default))
                        self.present(alert, animated: true)
                    }
                }
            case .connecting:
                self.scanButton.isHidden = true
                self.disconnectButton.isHidden = true
                self.updateStatus("连接中...", color: .systemOrange)
                self.loadingIndicator.startAnimating()
            case .connected:
                self.scanButton.isHidden = true
                self.disconnectButton.isHidden = true
                self.updateStatus("认证中...", color: .systemYellow)
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
                self.updateStatus("重连中...", color: .systemOrange)
                self.loadingIndicator.startAnimating()
            @unknown default: break
            }

            if state == .disconnected { self.scannedDevices.removeAll() }
            self.previousConnectionState = state
        }
    }

    func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?) {
        if !success {
            log("🔐 认证失败")
            handleAuthFailed()
        }
    }
    
    func blueSDKDidRequestTimeSync(_ sdk: BlueSDK) { log("⏰ 时间同步（已自动处理）") }
    func blueSDK(_ sdk: BlueSDK, didUpdateAlarm alarm: AlarmInfo) {
        log("⏰ 闹钟\(alarm.index) \(String(format: "%02d:%02d", alarm.hour, alarm.minute))")
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
    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo) { log("🔔 闹钟\(alarmIndex)响铃") }
    func blueSDK(_ sdk: BlueSDK, didAlarmTimeout alarmIndex: Int, alarmInfo: AlarmInfo) { log("⚠️ 闹钟\(alarmIndex)超时") }

    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus) {
        let statusText = SDKLocale.isZh ? status.displayNameZh : status.displayNameEn
        log("💊 闹钟\(alarmIndex) \(statusText)")
        // 不入库 — 等 didReceiveMedicationRecord 上报完整记录（含设定时间和实际时间）
    }

    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationRecord record: MedicationRecord) {
        let statusText = SDKLocale.isZh ? record.status.displayNameZh : record.status.displayNameEn
        log("📋 用药记录：闹钟\(record.alarmIndex) \(statusText)")
        MedicationDatabase.shared.insert(timestamp: record.timestamp, alarmIndex: record.alarmIndex, alarmHour: record.alarmHour, alarmMinute: record.alarmMinute, status: record.status.rawValue)
    }

    func blueSDK(_ sdk: BlueSDK, didChangeSoundType type: SoundType) {
        log("🔊 铃声变更: \(type)")
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
            case .typeC: break // 预留，界面无对应
            @unknown default: break
            }
        }
    }
    func blueSDK(_ sdk: BlueSDK, didChangeTimeFormat format: TimeFormat) {
        log("🕐 时制变更")
        DispatchQueue.main.async { [weak self] in
            switch format {
            case .hour12: self?.timeFormatSegment.selectedSegmentIndex = 0
            case .hour24: self?.timeFormatSegment.selectedSegmentIndex = 1
            @unknown default: break
            }
        }
    }
    func blueSDKDidReportLowBattery(_ sdk: BlueSDK) { log("🪫 低电") }

    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationNotification type: Int) {
        switch type {
        case 1:
            log("🔔 闹钟响铃，等待取药")
            // 前台时弹窗提醒
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let alert = UIAlertController(
                    title: SDKLocale.s("💊 闹钟响铃", "💊 Alarm Ringing"),
                    message: SDKLocale.s("请及时取药", "Please take your medication"),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: SDKLocale.s("知道了", "OK"), style: .default))
                self.present(alert, animated: true)
            }
        case 2:
            log("⚠️ 超时未取药")
            // 推送漏服通知
            let content = UNMutableNotificationContent()
            content.title = SDKLocale.s("用药提醒", "Medication Reminder")
            content.body = SDKLocale.s("您已超时未取药，请尽快服药！", "You missed your medication. Please take it now!")
            content.sound = UNNotificationSound.default()
            let request = UNNotificationRequest(identifier: "missed_\(Date().timeIntervalSince1970)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        case 3:
            log("✅ 用户已取药")
            // 鼓励通知/弹窗
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let alert = UIAlertController(
                    title: SDKLocale.s("👏 按时服药", "👏 Well Done"),
                    message: SDKLocale.s("太棒了！坚持按时服药有助于健康。", "Great job! Keep taking your medication on time."),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: SDKLocale.s("好的", "OK"), style: .default))
                self.present(alert, animated: true)
            }
        default: break
        }
    }
    func blueSDK(_ sdk: BlueSDK, didEncounterError error: BlueError) { log("⚠️ \(error.localizedDescription)") }
}

// MARK: - DismissableVC Protocol

@objc protocol DismissableVC {
    @objc func dismissSelf()
}

extension AlarmManagerViewController: DismissableVC {}
extension MedicationRecordsViewController: DismissableVC {}
extension ProtocolTestViewController: DismissableVC {}
