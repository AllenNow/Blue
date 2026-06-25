// ScanViewController.swift
// BlueSDK Example - 扫描添加设备页
// 扫描附近 LX-PD02 设备，用户选择绑定

import UIKit
import BlueSDK
import SnapKit

class ScanViewController: UIViewController {

    // MARK: - UI

    private let statusLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let rescanButton = UIButton(type: .system)

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

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle(S.cancel, for: .normal)
        cancelBtn.setTitleColor(.systemRed, for: .normal)
        cancelBtn.addTarget(self, action: #selector(cancelBind), for: .touchUpInside)
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

    // MARK: - 状态

    private var discoveredDevices: [ScannedDevice] = []
    private var isScanning = false
    private var pendingBindDevice: ScannedDevice?

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        title = S.scanDevicesTitle
        view.backgroundColor = .systemBackground
        buildUI()
        BlueSDK.shared.addObserver(self)
        startDeviceScan()
    }

    deinit {
        BlueSDK.shared.removeObserver(self)
        if isScanning { BlueSDK.shared.stopScan() }
    }

    // MARK: - UI 构建

    private func buildUI() {
        statusLabel.text = S.searchingNearby
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        view.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ScanDeviceCell.self, forCellReuseIdentifier: "ScanDeviceCell")
        tableView.separatorStyle = .none
        tableView.backgroundColor = .systemBackground
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(statusLabel.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-60)
        }

        rescanButton.setTitle(S.rescan, for: .normal)
        rescanButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        rescanButton.setTitleColor(.white, for: .normal)
        rescanButton.backgroundColor = .systemBlue
        rescanButton.layer.cornerRadius = 8
        rescanButton.isHidden = true
        rescanButton.addTarget(self, action: #selector(rescan), for: .touchUpInside)
        view.addSubview(rescanButton)
        rescanButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-12)
            $0.height.equalTo(44)
        }

        view.addSubview(loadingOverlay)
        loadingOverlay.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    // MARK: - 扫描

    private func startDeviceScan() {
        guard !isScanning else { return }
        isScanning = true
        discoveredDevices.removeAll()
        tableView.reloadData()
        statusLabel.text = S.searchingNearby
        rescanButton.isHidden = true

        BlueSDK.shared.startScan(timeout: 15) { [weak self] event in
            guard let self = self else { return }
            switch event {
            case .deviceFound(let device):
                // 排除已绑定设备
                if DeviceStorage.shared.isBound(deviceId: device.deviceId) { return }
                // 去重（更新 RSSI）
                if let idx = self.discoveredDevices.firstIndex(where: { $0.deviceId == device.deviceId }) {
                    self.discoveredDevices[idx] = device
                } else {
                    self.discoveredDevices.append(device)
                }
                DispatchQueue.main.async { self.refreshUI() }
            case .stopped:
                self.isScanning = false
                DispatchQueue.main.async {
                    if self.discoveredDevices.isEmpty {
                        self.statusLabel.text = S.noNewDevices
                    } else {
                        self.statusLabel.text = S.devicesFoundCount.replacingOccurrences(of: "%d", with: "\(self.discoveredDevices.count)")
                    }
                    self.rescanButton.isHidden = false
                }
            case .error:
                self.isScanning = false
                DispatchQueue.main.async {
                    self.statusLabel.text = S.scanError
                    self.rescanButton.isHidden = false
                }
            }
        }
    }

    private func refreshUI() {
        tableView.reloadData()
        if isScanning {
            statusLabel.text = S.scanningFoundCount.replacingOccurrences(of: "%d", with: "\(discoveredDevices.count)")
        }
    }

    @objc private func rescan() {
        startDeviceScan()
    }

    // MARK: - 绑定

    private func bindDevice(_ device: ScannedDevice) {
        if isScanning {
            BlueSDK.shared.stopScan()
            isScanning = false
        }

        // 保存到本地
        let bound = BoundDevice(
            deviceId: device.deviceId,
            deviceName: device.deviceName,
            bindTime: Date().timeIntervalSince1970,
            lastConnectedTime: Date().timeIntervalSince1970
        )
        DeviceStorage.shared.add(bound)

        // 自动连接
        pendingBindDevice = device
        loadingOverlay.isHidden = false
        BlueSDK.shared.connect(device)
    }

    @objc private func cancelBind() {
        BlueSDK.shared.disconnect()
        pendingBindDevice = nil
        loadingOverlay.isHidden = true
    }
}

// MARK: - UITableView

extension ScanViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoveredDevices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ScanDeviceCell", for: indexPath) as! ScanDeviceCell
        let device = discoveredDevices[indexPath.row]
        cell.configure(device: device) { [weak self] in
            self?.bindDevice(device)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 68
    }
}

// MARK: - BlueSDKDelegate

extension ScanViewController: BlueSDKDelegate {
    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
            case .authenticated:
                guard let device = self.pendingBindDevice else { return }
                DeviceStorage.shared.updateLastConnected(deviceId: device.deviceId)
                self.loadingOverlay.isHidden = true
                // 跳转控制页
                let vc = ViewController()
                vc.deviceId = device.deviceId
                vc.deviceName = device.deviceName
                // 替换导航栈：列表页 → 控制页
                if var vcs = self.navigationController?.viewControllers {
                    vcs.removeLast() // 移除 ScanViewController
                    vcs.append(vc)
                    self.navigationController?.setViewControllers(vcs, animated: true)
                }
            case .disconnected:
                if self.pendingBindDevice != nil {
                    self.loadingOverlay.isHidden = true
                    self.pendingBindDevice = nil
                }
            default:
                break
            }
        }
    }

    func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?) {
        if !success {
            DispatchQueue.main.async { [weak self] in
                self?.loadingOverlay.isHidden = true
                self?.pendingBindDevice = nil
                let msg = S.authFailedStatus
                let toast = UILabel()
                toast.text = msg
                toast.font = .systemFont(ofSize: 14)
                toast.textColor = .white
                toast.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
                toast.textAlignment = .center
                toast.layer.cornerRadius = 8
                toast.clipsToBounds = true
                self?.view.addSubview(toast)
                toast.snp.makeConstraints {
                    $0.centerX.equalToSuperview()
                    $0.bottom.equalTo(self!.view.safeAreaLayoutGuide).offset(-80)
                    $0.width.equalTo(160)
                    $0.height.equalTo(36)
                }
                UIView.animate(withDuration: 0.3, delay: 2.0) { toast.alpha = 0 } completion: { _ in toast.removeFromSuperview() }
            }
        }
    }
}

// MARK: - ScanDeviceCell

class ScanDeviceCell: UITableViewCell {

    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let bindButton = UIButton(type: .system)
    private let cardView = UIView()
    private var onBind: (() -> Void)?

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

        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = .label
        cardView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(14)
            $0.top.equalToSuperview().offset(12)
        }

        detailLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = .secondaryLabel
        cardView.addSubview(detailLabel)
        detailLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(14)
            $0.bottom.equalToSuperview().offset(-12)
        }

        bindButton.setTitle(S.bind, for: .normal)
        bindButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        bindButton.setTitleColor(.white, for: .normal)
        bindButton.backgroundColor = .systemBlue
        bindButton.layer.cornerRadius = 6
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            bindButton.configuration = config
            bindButton.configuration?.background.backgroundColor = .systemBlue
            bindButton.configuration?.baseForegroundColor = .white
        } else {
            bindButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        }
        bindButton.addTarget(self, action: #selector(bindTapped), for: .touchUpInside)
        cardView.addSubview(bindButton)
        bindButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-14)
            $0.centerY.equalToSuperview()
        }
    }

    func configure(device: ScannedDevice, onBind: @escaping () -> Void) {
        nameLabel.text = device.deviceName
        detailLabel.text = "\(device.deviceId)  \(device.rssi)dBm"
        self.onBind = onBind
    }

    @objc private func bindTapped() {
        onBind?()
    }
}
