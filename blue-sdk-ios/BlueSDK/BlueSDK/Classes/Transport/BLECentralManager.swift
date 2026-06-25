// BLECentralManager.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// CBCentralManager 单例封装
// 全局唯一的 CBCentralManager 实例，扫描和连接共用，避免实例不一致问题

import Foundation
import CoreBluetooth

/// 连接事件代理（BLEConnector 实现）
protocol BLECentralConnectionDelegate: AnyObject {
    func centralDidConnect(peripheral: CBPeripheral)
    func centralDidDisconnect(peripheral: CBPeripheral, error: Error?)
    func centralDidFailToConnect(peripheral: CBPeripheral, error: Error?)
}

/// CBCentralManager 全局单例
/// 所有 BLE 操作（扫描、连接、断开）通过此单例访问同一个 CBCentralManager
final class BLECentralManager: NSObject {

    // MARK: - 单例

    static let shared = BLECentralManager()

    // MARK: - 状态

    private(set) var centralManager: CBCentralManager!
    private let logger = BlueLogger.shared

    /// 当前蓝牙状态
    var state: CBManagerState {
        return centralManager.state
    }

    // MARK: - 初始化

    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - 代理

    /// 扫描代理（BLEScanner 设置）
    weak var scanDelegate: BLEScannerDelegate?

    /// 连接代理（BLEConnector 设置）
    weak var connectionDelegate: BLECentralConnectionDelegate?
}

// MARK: - CBCentralManagerDelegate

extension BLECentralManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.info("Bluetooth state changed: \(central.state.rawValue)")
        scanDelegate?.bleCentralManagerDidUpdateState(central)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        scanDelegate?.bleCentralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionDelegate?.centralDidConnect(peripheral: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionDelegate?.centralDidDisconnect(peripheral: peripheral, error: error)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionDelegate?.centralDidFailToConnect(peripheral: peripheral, error: error)
    }
}
