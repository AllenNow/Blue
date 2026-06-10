// DeviceInfo.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// 设备信息数据模型

import Foundation

/// 设备基础信息
@objc public class DeviceInfo: NSObject {
    /// 固件版本号（如 "1.0.0"）
    @objc public let firmwareVersion: String
    /// 设备 MAC 地址
    @objc public let deviceId: String

    @objc public init(firmwareVersion: String, deviceId: String) {
        self.firmwareVersion = firmwareVersion
        self.deviceId = deviceId
    }
}
