//
//  Keychain.swift
//  LarioGo
//
//  Minimal Keychain wrapper for the session token.
//

import Foundation
import Security

/// Thin wrapper over the Keychain Services C API.
///
/// Deliberately small: this stores one credential. A general-purpose Keychain
/// abstraction would be more surface area to get wrong for no benefit.
enum Keychain {

    /// `afterFirstUnlock` rather than `whenUnlocked`: background refresh and
    /// notification handling need the token while the device is locked. It is
    /// *not* `ThisDeviceOnly`-exempt — the token must never sync to iCloud or
    /// restore onto a different device from a backup.
    private static let accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    static func read(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    @discardableResult
    static func write(_ data: Data, service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        // Update in place when an entry exists; SecItemAdd fails with
        // errSecDuplicateItem rather than overwriting.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        guard updateStatus == errSecItemNotFound else { return false }

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = accessibility
        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func delete(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        // Nothing to delete is a success from the caller's point of view.
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
