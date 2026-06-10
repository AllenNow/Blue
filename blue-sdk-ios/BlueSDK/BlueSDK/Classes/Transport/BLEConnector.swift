// BLEConnector.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// BLE 连接器：管理与 LX-PD02 设备的 GATT 连接和数据收发

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
    private static let serviceUUID    = CBUUID(string: "D459")
    private static let writeCharUUID  = CBUUID(string: "0013") // 下行写特征
    private static let notifyCharUUID = CBUUID(string: "0014") // 上行通知特征

    // MARK: - 状态

    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private let logger = BlueLogger.shared

    weak var delegate: BLEConnectorDelegate?

    // MARK: - 公开方法

    /// 连接指定设备
    func connect(peripheral: CBPeripheral, centralManager: CBCentralManager) {
        self.peripheral = peripheral
        self.centralManager = centralManager
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
        logger.info("正在连接设备：\(peripheral.name ?? peripheral.identifier.uuidString)")
    }

    /// 断开连接
    func disconnect() {
        guard let peripheral = peripheral,
              let central = centralManager else { return }
        central.cancelPeripheralConnection(peripheral)
        logger.info("主动断开连接")
    }

    /// 发送数据帧
    func write(_ bytes: [UInt8]) {
        guard let peripheral = peripheral,
              let characteristic = writeCharacteristic else {
            logger.error("写特征未就绪，无法发送数据")
            return
        }
        let data = Data(bytes)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        logger.debug("发送帧：\(bytes.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEConnector: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // 状态由 ConnectionManager 统一处理
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("设备已连接，开始发现服务")
        peripheral.discoverServices([BLEConnector.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        writeCharacteristic = nil
        notifyCharacteristic = nil
        logger.info("设备已断开：\(error?.localizedDescription ?? "正常断开")")
        delegate?.bleConnectorDidDisconnect(error: error)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("连接失败：\(error?.localizedDescription ?? "未知错误")")
        delegate?.bleConnectorDidDisconnect(error: error)
    }
}

// MARK: - CBPeripheralDelegate

extension BLEConnector: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let service = peripheral.services?.first(where: { $0.uuid == BLEConnector.serviceUUID }) else {
            logger.error("服务发现失败：\(error?.localizedDescription ?? "未找到目标服务")")
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
            logger.error("特征发现失败：\(error!.localizedDescription)")
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
            logger.info("GATT 特征就绪，连接完成")
            delegate?.bleConnectorDidConnect()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        logger.debug("收到数据：\([UInt8](data).map { String(format: "%02X", $0) }.joined(separator: " "))")
        delegate?.bleConnectorDidReceiveData(data)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("写入失败：\(error.localizedDescription)")
        }
    }
}
