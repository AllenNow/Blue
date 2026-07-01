// BLEConnector.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// BLE 连接器：管理与 LX-PD02 设备的 GATT 连接和数据收发
// 使用 BLECentralManager 单例，确保与扫描器共用同一个 CBCentralManager

import Foundation
import CoreBluetooth

/// BLE 连接器事件回调
protocol BLEConnectorDelegate: AnyObject {
    func bleConnectorDidConnect()
    func bleConnectorDidDisconnect(error: Error?)
    func bleConnectorDidReceiveData(_ data: Data)
}

/// BLE 连接器
/// 负责 GATT 连接建立、特征值读写和 Notify 订阅
final class BLEConnector: NSObject {

    // MARK: - GATT 服务/特征 UUID（LX-PD02）
    static let serviceUUID    = CBUUID(string: "D459")
    private static let writeCharUUID  = CBUUID(string: "0013") // 下行写特征
    private static let notifyCharUUID = CBUUID(string: "0014") // 上行通知特征

    // MARK: - 状态

    private let bleCentral = BLECentralManager.shared
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private let logger = BlueLogger.shared

    weak var delegate: BLEConnectorDelegate?

    // MARK: - 公开方法

    /// 连接指定设备
    func connect(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
        // 注册为连接事件代理，接收 centralManager 的连接/断开回调
        bleCentral.connectionDelegate = self
        bleCentral.centralManager.connect(peripheral, options: nil)
        logger.info("Connecting to device: \(peripheral.name ?? peripheral.identifier.uuidString)")
    }

    /// 断开连接
    func disconnect() {
        guard let peripheral = peripheral else { return }
        
        if let notifyChar = notifyCharacteristic {
            peripheral.setNotifyValue(false, for: notifyChar)
        }
        
        bleCentral.centralManager.cancelPeripheralConnection(peripheral)
        
        writeCharacteristic = nil
        notifyCharacteristic = nil
        self.peripheral = nil
        
        logger.info("Disconnected manually")
    }

    /// 发送数据帧
    func write(_ bytes: [UInt8]) {
        guard let peripheral = peripheral,
              let characteristic = writeCharacteristic else {
            logger.error("Write characteristic not ready")
            return
        }
        let data = Data(bytes)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        if logger.rawFrameLogEnabled {
            logger.debug("TX: \(bytes.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }
    }
}

// MARK: - BLECentralConnectionDelegate

extension BLEConnector: BLECentralConnectionDelegate {

    func centralDidConnect(peripheral: CBPeripheral) {
        logger.info("Device connected, discovering services")
        peripheral.discoverServices([BLEConnector.serviceUUID])
    }

    func centralDidDisconnect(peripheral: CBPeripheral, error: Error?) {
        writeCharacteristic = nil
        notifyCharacteristic = nil
        logger.info("Device disconnected: \(error?.localizedDescription ?? "normal")")
        delegate?.bleConnectorDidDisconnect(error: error)
    }

    func centralDidFailToConnect(peripheral: CBPeripheral, error: Error?) {
        logger.error("Connection failed: \(error?.localizedDescription ?? "unknown")")
        delegate?.bleConnectorDidDisconnect(error: error)
    }
}

// MARK: - CBPeripheralDelegate

extension BLEConnector: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let service = peripheral.services?.first(where: { $0.uuid == BLEConnector.serviceUUID }) else {
            logger.error("Service discovery failed: \(error?.localizedDescription ?? "target service not found")")
            delegate?.bleConnectorDidDisconnect(error: error)
            return
        }
        peripheral.discoverCharacteristics(
            [BLEConnector.writeCharUUID, BLEConnector.notifyCharUUID],
            for: service
        )
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            logger.error("Characteristic discovery failed: \(error!.localizedDescription)")
            return
        }

        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == BLEConnector.writeCharUUID {
                writeCharacteristic = characteristic
            }
            if characteristic.uuid == BLEConnector.notifyCharUUID,
               characteristic.properties.contains(.notify) {
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }

        if writeCharacteristic != nil {
            logger.info("GATT characteristics ready, connection complete")
            delegate?.bleConnectorDidConnect()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        if logger.rawFrameLogEnabled {
            logger.debug("RX: \([UInt8](data).map { String(format: "%02X", $0) }.joined(separator: " "))")
        }
        delegate?.bleConnectorDidReceiveData(data)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Write failed: \(error.localizedDescription)")
        }
    }
}
