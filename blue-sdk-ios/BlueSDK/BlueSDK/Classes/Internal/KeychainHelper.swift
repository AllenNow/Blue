// KeychainHelper.swift
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK
//
// Keychain 存储工具
// 用于持久化存储手机端标识（phoneMac 替代值），卸载 APP 后仍保留

import Foundation
import Security

/// Keychain 存储工具
/// 封装 Security framework 的 Keychain 操作
enum KeychainHelper {

    private static let service = "com.blue.sdk.keychain"

    /// 存储数据到 Keychain
    /// - Parameters:
    ///   - data: 要存储的数据
    ///   - key: 存储键名
    /// - Returns: 是否存储成功
    @discardableResult
    static func save(data: Data, forKey key: String) -> Bool {
        // 先删除旧值
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// 从 Keychain 读取数据
    /// - Parameter key: 存储键名
    /// - Returns: 存储的数据，未找到返回 nil
    static func load(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// 删除 Keychain 中的数据
    /// - Parameter key: 存储键名
    @discardableResult
    static func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
