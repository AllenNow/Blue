// DeviceListViewController.swift
// BlueSDK Example - 设备列表主页
// 展示已绑定设备，进入时自动扫描更新在线状态

import UIKit
import BlueSDK
import SnapKit

class DeviceListViewController: UIViewController {

    // MARK: - UI 控件

    private let titleLabel = UILabel()
    private let scanIndicator = UILabel()
    private let addButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = UIStackView()

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
        cancelBtn.addTarget(self, action: #selector(cancelConnect), for: .touchUpInside)
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

    // MARK: - 状态

    private var devices: [BoundDevice] = []
    private var onlineDevices: Set<String> = []
    private var rssiMap: [String: Int] = [:]
    /// 缓存扫描到的 ScannedDevice 对象（用于直接连接）
    private var scannedDeviceCache: [String: ScannedDevice] = [:]
    private var isScanning = false
    private var pendingConnectDevice: BoundDevice?
    /// 当前已连接的设备 ID（跟踪连接状态用）
    private var connectedDeviceId: String?
    /// 认证是否失败（防止 .disconnected 事件触发自动重连循环）
    private var isAuthFailed = false
    /// 用户是否主动断开（主动断开不触发自动重连）
    private var isUserDisconnect = false

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.title = "Blue SDK Demo"
        buildUI()
        BlueSDKManager.shared.addObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 同步当前连接状态（从控制页返回时可能仍已连接或已断开）
        if BlueSDKManager.shared.connectionState != .authenticated {
            connectedDeviceId = nil
        }
        refreshList()
        startOnlineScan()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isScanning {
            BlueSDKManager.shared.stopScan()
            isScanning = false
        }
    }

    deinit {
        BlueSDKManager.shared.removeObserver(self)
    }

    // MARK: - UI 构建

    private func buildUI() {
        // 左上角语言切换按钮
        let langBtn = UIButton(type: .system)
        langBtn.setTitle("🌐", for: .normal)
        langBtn.titleLabel?.font = .systemFont(ofSize: 22)
        langBtn.addTarget(self, action: #selector(openLanguageSettings), for: .touchUpInside)
        let langItem = UIBarButtonItem(customView: langBtn)

        // FAQ 按钮
        let faqBtn = UIButton(type: .system)
        faqBtn.setTitle("❓", for: .normal)
        faqBtn.titleLabel?.font = .systemFont(ofSize: 20)
        faqBtn.addTarget(self, action: #selector(openFAQ), for: .touchUpInside)
        let faqItem = UIBarButtonItem(customView: faqBtn)

        navigationItem.leftBarButtonItems = [langItem, faqItem]

        // 右上角添加按钮
        let addItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(openScanPage))
        navigationItem.rightBarButtonItem = addItem

        // 扫描指示器
        scanIndicator.text = S.scanning
        scanIndicator.font = .systemFont(ofSize: 13)
        scanIndicator.textColor = .systemBlue
        scanIndicator.isHidden = true
        view.addSubview(scanIndicator)
        scanIndicator.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(4)
            $0.centerX.equalToSuperview()
        }

        // 表格
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(DeviceCell.self, forCellReuseIdentifier: "DeviceCell")
        tableView.separatorStyle = .none
        tableView.backgroundColor = .systemBackground
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(24)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        // 空态视图
        emptyView.axis = .vertical
        emptyView.alignment = .center
        emptyView.spacing = 8
        emptyView.isHidden = true

        let emptyIcon = UILabel()
        emptyIcon.text = "📱"
        emptyIcon.font = .systemFont(ofSize: 48)
        emptyView.addArrangedSubview(emptyIcon)

        let emptyTitle = UILabel()
        emptyTitle.text = S.noBoundDevices
        emptyTitle.font = .systemFont(ofSize: 16)
        emptyTitle.textColor = .secondaryLabel
        emptyView.addArrangedSubview(emptyTitle)

        let emptySubtitle = UILabel()
        emptySubtitle.text = S.noBoundDevicesHint
        emptySubtitle.font = .systemFont(ofSize: 13)
        emptySubtitle.textColor = .tertiaryLabel
        emptyView.addArrangedSubview(emptySubtitle)

        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.center.equalToSuperview()
        }

        // Loading 遮罩
        view.addSubview(loadingOverlay)
        loadingOverlay.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    // MARK: - 数据刷新

    private func refreshList() {
        devices = DeviceStorage.shared.loadAll()
        emptyView.isHidden = !devices.isEmpty
        tableView.isHidden = devices.isEmpty
        tableView.reloadData()
    }

    // MARK: - 在线扫描

    private func startOnlineScan() {
        guard !isScanning else { return }
        guard !devices.isEmpty else { return }

        isScanning = true
        onlineDevices.removeAll()
        rssiMap.removeAll()
        scanIndicator.isHidden = false

        BlueSDKManager.shared.startScan(timeout: 5) { [weak self] event in
            guard let self = self else { return }
            switch event {
            case .deviceFound(let device):
                if DeviceStorage.shared.isBound(deviceId: device.deviceId) {
                    self.onlineDevices.insert(device.deviceId)
                    self.rssiMap[device.deviceId] = device.rssi
                    self.scannedDeviceCache[device.deviceId] = device
                    DispatchQueue.main.async { self.tableView.reloadData() }
                }
            case .stopped:
                self.isScanning = false
                DispatchQueue.main.async {
                    self.scanIndicator.isHidden = true
                    self.tableView.reloadData()
                }
            case .error:
                self.isScanning = false
                DispatchQueue.main.async { self.scanIndicator.isHidden = true }
            }
        }
    }

    // MARK: - 操作

    @objc private func openLanguageSettings() {
        let langVC = LanguageViewController()
        langVC.isFromSettings = true
        langVC.onLanguageChanged = { [weak self] in
            // 语言切换后刷新页面标题和列表
            self?.navigationItem.title = "Blue SDK Demo"
            self?.refreshList()
        }
        navigationController?.pushViewController(langVC, animated: true)
    }

    @objc private func openScanPage() {
        let scanVC = ScanViewController()
        navigationController?.pushViewController(scanVC, animated: true)
    }

    @objc private func openFAQ() {
        let faqVC = FAQViewController()
        navigationController?.pushViewController(faqVC, animated: true)
    }

    private func connectDevice(_ device: BoundDevice) {
        // 如果已经连接认证到该设备，直接跳转
        if BlueSDKManager.shared.connectionState == .authenticated && connectedDeviceId == device.deviceId {
            navigateToControl(device: device)
            return
        }

        pendingConnectDevice = device
        showLoading()

        // 如果当前有连接，先断开，等断开回调后再连新设备
        if BlueSDKManager.shared.connectionState != .disconnected {
            // 标记等待断开后自动连接
            BlueSDKManager.shared.disconnect()
            // delegate 中 .disconnected 会触发 reconnectPending
            return
        }

        performConnect(device)
    }

    /// 实际执行连接逻辑
    private func performConnect(_ device: BoundDevice) {
        isAuthFailed = false  // 重置认证失败标记
        // 优先使用缓存的 ScannedDevice（扫描到的设备可直接连接）
        if let cached = scannedDeviceCache[device.deviceId] {
            BlueSDKManager.shared.connect(cached)
            return
        }

        // 没有缓存时，通过 UUID 直接连接
        BlueSDKManager.shared.connect(byIdentifier: device.deviceId) { [weak self] error in
            if let _ = error {
                // UUID 连接失败，回退到扫描方式
                BlueSDKManager.shared.startScan(timeout: 8) { [weak self] event in
                    guard let self = self else { return }
                    switch event {
                    case .deviceFound(let scanned):
                        if scanned.deviceId == device.deviceId {
                            BlueSDKManager.shared.stopScan()
                            self.scannedDeviceCache[device.deviceId] = scanned
                            BlueSDKManager.shared.connect(scanned)
                        }
                    case .stopped:
                        if self.pendingConnectDevice != nil {
                            DispatchQueue.main.async {
                                self.hideLoading()
                                self.pendingConnectDevice = nil
                                self.showToast(S.deviceNotFound)
                            }
                        }
                    case .error:
                        DispatchQueue.main.async {
                            self.hideLoading()
                            self.pendingConnectDevice = nil
                        }
                    }
                }
            }
        }
    }

    private func navigateToControl(device: BoundDevice) {
        // 防止重复跳转：如果导航栈顶部已经是设备控制页则不再 push
        if navigationController?.topViewController is ViewController {
            return
        }
        pendingConnectDevice = nil
        let vc = ViewController()
        vc.deviceId = device.deviceId
        vc.deviceName = device.deviceName
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func cancelConnect() {
        BlueSDKManager.shared.stopScan()
        isUserDisconnect = true
        BlueSDKManager.shared.disconnect()
        pendingConnectDevice = nil
        hideLoading()
    }

    private func showDeleteAlert(for device: BoundDevice) {
        let title = S.removeDeviceTitle
        let msg = S.removeDeviceMsg.replacingOccurrences(of: "%@", with: device.deviceName)
        let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: S.confirm, style: .destructive) { [weak self] _ in
            if self?.pendingConnectDevice?.deviceId == device.deviceId {
                BlueSDKManager.shared.disconnect()
                self?.pendingConnectDevice = nil
            }
            DeviceStorage.shared.remove(deviceId: device.deviceId)
            self?.refreshList()
        })
        present(alert, animated: true)
    }

    // MARK: - Loading

    private func showLoading() {
        loadingLabel?.text = S.connectingAuth
        loadingOverlay.isHidden = false
    }

    private func hideLoading() {
        loadingOverlay.isHidden = true
    }

    private func showToast(_ message: String) {
        let toast = UILabel()
        toast.text = message
        toast.font = .systemFont(ofSize: 14)
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 8
        toast.clipsToBounds = true
        toast.numberOfLines = 0
        view.addSubview(toast)
        toast.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-32)
            $0.width.lessThanOrEqualTo(280)
            $0.height.greaterThanOrEqualTo(36)
        }
        toast.layoutIfNeeded()
        UIView.animate(withDuration: 0.3, delay: 2.0, options: .curveEaseOut) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }
}

// MARK: - UITableViewDataSource & Delegate

extension DeviceListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath) as! DeviceCell
        let device = devices[indexPath.row]
        let isConnected = BlueSDKManager.shared.connectionState == .authenticated &&
            connectedDeviceId == device.deviceId
        // 已连接的设备视为在线
        let isOnline = isConnected || onlineDevices.contains(device.deviceId)
        let rssi = rssiMap[device.deviceId]
        cell.configure(device: device, isOnline: isOnline, isConnected: isConnected, rssi: rssi)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let device = devices[indexPath.row]
        let isConnected = BlueSDKManager.shared.connectionState == .authenticated &&
            connectedDeviceId == device.deviceId
        let isOnline = isConnected || onlineDevices.contains(device.deviceId)

        if isOnline {
            connectDevice(device)
        } else {
            // 即使扫描不到也尝试连接（通过 UUID），而不是直接提示离线
            connectDevice(device)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let device = devices[indexPath.row]
        let deleteAction = UIContextualAction(style: .destructive, title: S.delete) { [weak self] _, _, completion in
            self?.showDeleteAlert(for: device)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: - BlueSDKDelegate

extension DeviceListViewController: BlueSDKDelegate {
    func blueSDK(_ sdk: BlueSDKManager, didChangeConnectionState state: ConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
            case .authenticated:
                guard let device = self.pendingConnectDevice else { return }
                self.connectedDeviceId = device.deviceId
                DeviceStorage.shared.updateLastConnected(deviceId: device.deviceId)
                self.hideLoading()
                self.navigateToControl(device: device)
            case .disconnected:
                self.connectedDeviceId = nil
                // 主动断开或认证失败后不自动重连
                if self.isUserDisconnect {
                    self.isUserDisconnect = false
                    self.pendingConnectDevice = nil
                    self.hideLoading()
                    self.refreshList()
                } else if self.isAuthFailed {
                    self.isAuthFailed = false
                    self.pendingConnectDevice = nil
                    self.hideLoading()
                    self.refreshList()
                } else if let pending = self.pendingConnectDevice {
                    // 切换设备场景：断开后延迟发起新连接
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.performConnect(pending)
                    }
                } else {
                    self.hideLoading()
                    self.refreshList()
                }
            default:
                break
            }
        }
    }

    func blueSDK(_ sdk: BlueSDKManager, didAuthenticateWithSuccess success: Bool, error: BlueError?) {
        if !success {
            DispatchQueue.main.async { [weak self] in
                self?.isAuthFailed = true
                self?.hideLoading()
                self?.pendingConnectDevice = nil
                self?.showToast("\(S.authFailedStatus)：\(error?.localizedDescription ?? "")")
                self?.refreshList()
            }
        }
    }
}

// MARK: - DeviceCell

class DeviceCell: UITableViewCell {

    private let nameLabel = UILabel()
    private let macLabel = UILabel()
    private let statusLabel = UILabel()
    private let rssiLabel = UILabel()
    private let cardView = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.backgroundColor = .secondarySystemBackground
        cardView.layer.cornerRadius = 10
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.top.bottom.equalToSuperview().inset(4)
        }

        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .label
        cardView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(14)
            $0.top.equalToSuperview().offset(12)
        }

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.layer.cornerRadius = 4
        statusLabel.clipsToBounds = true
        statusLabel.textAlignment = .center
        cardView.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-14)
            $0.centerY.equalTo(nameLabel)
            $0.width.greaterThanOrEqualTo(48)
            $0.height.equalTo(20)
        }

        macLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        macLabel.textColor = .secondaryLabel
        cardView.addSubview(macLabel)
        macLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(14)
            $0.bottom.equalToSuperview().offset(-12)
        }

        rssiLabel.font = .systemFont(ofSize: 11)
        rssiLabel.textColor = .tertiaryLabel
        cardView.addSubview(rssiLabel)
        rssiLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-14)
            $0.centerY.equalTo(macLabel)
        }
    }

    func configure(device: BoundDevice, isOnline: Bool, isConnected: Bool, rssi: Int?) {
        nameLabel.text = device.deviceName
        macLabel.text = device.deviceId

        if isConnected {
            statusLabel.text = S.connected
            statusLabel.textColor = .systemBlue
            statusLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            cardView.layer.borderWidth = 1.5
            cardView.layer.borderColor = UIColor.systemBlue.cgColor
        } else if isOnline {
            statusLabel.text = S.deviceOnline
            statusLabel.textColor = .systemGreen
            statusLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
            cardView.layer.borderWidth = 0
        } else {
            statusLabel.text = S.deviceOffline
            statusLabel.textColor = .secondaryLabel
            statusLabel.backgroundColor = UIColor.secondaryLabel.withAlphaComponent(0.1)
            cardView.layer.borderWidth = 0
        }

        if isOnline, let rssi = rssi {
            rssiLabel.text = "\(rssi)dBm"
            rssiLabel.isHidden = false
        } else {
            rssiLabel.isHidden = true
        }
    }
}
