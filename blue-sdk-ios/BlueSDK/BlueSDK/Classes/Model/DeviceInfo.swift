// DeviceInfo.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 设备信息数据模型

import Foundation

/// 设备基础信息
@objc public class DeviceInfo: NSObject {
    /// 固件版本号（如 "1.0.0"）
    @objc public let firmwareVersion: String
    /// 设备 MAC 地址（6字节）
    public let macAddress: [UInt8]
    /// 设备 MAC 地址字符串（如 "6F:74:36:74:74:64"）
    @objc public var macAddressString: String {
        macAddress.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    public init(firmwareVersion: String, macAddress: [UInt8]) {
        self.firmwareVersion = firmwareVersion
        self.macAddress = macAddress
    }
}
