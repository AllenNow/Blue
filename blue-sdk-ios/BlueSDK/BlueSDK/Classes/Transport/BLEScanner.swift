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

    // MARK: - 状态

    private(set) var isScanning = false
    private var onDeviceFound: ((ScannedDevice) -> Void)?
    private var onError: ((BlueError) -> Void)?
    private let logger = BlueLogger.shared
    private let centralManager = BLECentralManager.shared

    // MARK: - 公开方法

    /// 开始扫描 LX-PD02 设备
    /// - Parameters:
    ///   - onDeviceFound: 发现设备回调（主线程）
    ///   - onError: 错误回调（主线程）
    func startScan(
        onDeviceFound: @escaping (ScannedDevice) -> Void,
        onError: @escaping (BlueError) -> Void
    ) {
        guard !isScanning else {
            logger.warn("扫描已在进行中，忽略重复调用")
            return
        }

        self.onDeviceFound = onDeviceFound
        self.onError = onError

        // 注册为扫描代理
        centralManager.scanDelegate = self

        startScanIfReady()
    }

    /// 停止扫描
    func stopScan() {
        guard isScanning else { return }
        centralManager.centralManager.stopScan()
        isScanning = false
        logger.info("BLE 扫描已停止")
    }

    // MARK: - 私有方法

    private func startScanIfReady() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        centralManager.centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        logger.info("BLE 扫描已启动，过滤前缀：\(BLEScanner.deviceNamePrefix)")
    }

    // MARK: - BLEScannerDelegate

    func bleCentralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            logger.info("蓝牙已开启")
            startScanIfReady()
        case .poweredOff:
            logger.warn("蓝牙已关闭")
            CallbackDispatcher.shared.dispatch { [weak self] in
                self?.onError?(.bleError(underlying: nil))
            }
        case .unauthorized:
            logger.warn("蓝牙权限未授权")
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
        logger.debug("发现设备：\(name)，RSSI：\(RSSI)")

        CallbackDispatcher.shared.dispatch { [weak self] in
            self?.onDeviceFound?(device)
        }
    }
}
