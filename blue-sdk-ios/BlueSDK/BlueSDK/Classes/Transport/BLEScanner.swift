// BLEScanner.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// BLE 设备扫描器：过滤广播名前缀为 LX-PD02 的设备（FR01）
// 使用 BLECentralManager 单例，确保与连接器共用同一个 CBCentralManager

import Foundation
import CoreBluetooth

/// 扫描到的设备信息
@objc public class ScannedDevice: NSObject {
    /// 设备唯一标识（UUID 字符串）
    @objc public let deviceId: String
    /// 设备广播名称（如 LX-PD02-A1B2）
    @objc public let deviceName: String
    /// 信号强度（RSSI，单位 dBm）
    @objc public let rssi: Int
    /// 底层 CBPeripheral（内部使用）
    internal let peripheral: CBPeripheral

    internal init(peripheral: CBPeripheral, rssi: Int) {
        self.deviceId = peripheral.identifier.uuidString
        self.deviceName = peripheral.name ?? "Unknown"
        self.rssi = rssi
        self.peripheral = peripheral
    }
}

/// BLE 扫描器代理协议（供 BLECentralManager 回调转发）
protocol BLEScannerDelegate: AnyObject {
    func bleCentralManagerDidUpdateState(_ central: CBCentralManager)
    func bleCentralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber)
}

/// BLE 设备扫描器
final class BLEScanner: NSObject, BLEScannerDelegate {

    // MARK: - 常量

    private static let deviceNamePrefix = "LX-PD02"
    private static let scanDelayAfterDisconnect: TimeInterval = 0.5

    // MARK: - 状态

    private(set) var isScanning = false
    private var onDeviceFound: ((ScannedDevice) -> Void)?
    private var onError: ((BlueError) -> Void)?
    private let logger = BlueLogger.shared
    private let centralManager = BLECentralManager.shared
    private var pendingScanTimer: Timer?

    // MARK: - 公开方法

    /// 开始扫描 LX-PD02 设备
    /// - Parameters:
    ///   - onDeviceFound: 发现设备回调（主线程）
    ///   - onError: 错误回调（主线程）
    func startScan(
        onDeviceFound: @escaping (ScannedDevice) -> Void,
        onError: @escaping (BlueError) -> Void
    ) {
        pendingScanTimer?.invalidate()
        pendingScanTimer = nil

        if isScanning {
            centralManager.centralManager.stopScan()
            isScanning = false
        }

        self.onDeviceFound = onDeviceFound
        self.onError = onError

        centralManager.scanDelegate = self

        if centralManager.state == .poweredOn {
            pendingScanTimer = Timer.scheduledTimer(withTimeInterval: BLEScanner.scanDelayAfterDisconnect, repeats: false) { [weak self] _ in
                self?.startScanImmediately()
            }
        } else {
            logger.debug("Bluetooth not ready, waiting for state change")
        }
    }

    private func startScanImmediately() {
        guard !isScanning else { return }
        isScanning = true
        centralManager.centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        logger.info("BLE scan started, prefix filter: \(BLEScanner.deviceNamePrefix)")
    }

    /// 停止扫描
    func stopScan() {
        pendingScanTimer?.invalidate()
        pendingScanTimer = nil

        guard isScanning else { return }
        centralManager.centralManager.stopScan()
        isScanning = false
        onDeviceFound = nil
        onError = nil
        logger.info("BLE scan stopped")
    }

    // MARK: - 私有方法

    private func startScanIfReady() {
        guard centralManager.state == .poweredOn, onDeviceFound != nil else { return }
        startScanImmediately()
    }

    // MARK: - BLEScannerDelegate

    func bleCentralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            logger.info("Bluetooth powered on")
            startScanIfReady()
        case .poweredOff:
            logger.warn("Bluetooth powered off")
            CallbackDispatcher.shared.dispatch { [weak self] in
                self?.onError?(.bleError(underlying: nil))
            }
        case .unauthorized:
            logger.warn("Bluetooth permission denied")
            CallbackDispatcher.shared.dispatch { [weak self] in
                self?.onError?(.permissionDenied)
            }
        default:
            break
        }
    }

    func bleCentralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // 过滤广播名前缀
        guard let name = peripheral.name,
              name.hasPrefix(BLEScanner.deviceNamePrefix) else { return }

        let device = ScannedDevice(peripheral: peripheral, rssi: RSSI.intValue)
        logger.debug("Device found: \(name), RSSI: \(RSSI)")

        CallbackDispatcher.shared.dispatch { [weak self] in
            self?.onDeviceFound?(device)
        }
    }
}
