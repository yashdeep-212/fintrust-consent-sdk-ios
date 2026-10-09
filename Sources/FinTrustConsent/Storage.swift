import Foundation
import Security

/// Equivalent of Storage.kt — uses iOS Keychain (secure, survives app restarts,
/// same role as Android's EncryptedSharedPreferences).
internal enum ConsentStorage {

    private static let service = "com.fintrust.consentsdk"
    private static let deviceIdKey = "fintrust_device_id"

    // MARK: - Low-level Keychain helpers

    private static func set(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Org-scoped keys, same idea as Storage.kt's key(suffix) — one org's consent
    /// data doesn't collide with another's if the app ever switches orgId.
    private static func key(_ suffix: String) throws -> String {
        let orgId = try ConsentConfig.shared.require().organizationId
        return "fintrust_consent_\(orgId)_\(suffix)"
    }

    // MARK: - Consent state

    static func save(consentId: String, preferences: [String: Bool], status: ConsentStatus) throws {
        let version = try ConsentConfig.shared.require().consentVersion
        let prefsData = try JSONSerialization.data(withJSONObject: preferences)
        let prefsJson = String(data: prefsData, encoding: .utf8) ?? "{}"

        set(consentId, forKey: try key("id"))
        set(String(version), forKey: try key("version"))
        set(String(Date().timeIntervalSince1970 * 1000), forKey: try key("ts"))
        set(prefsJson, forKey: try key("prefs"))
        set(status.rawValue, forKey: try key("status"))
    }

    static func getConsentId() -> String? {
        guard let k = try? key("id") else { return nil }
        return get(k)
    }

    static func getSavedPreferences() -> [String: Bool]? {
        guard let k = try? key("prefs"), let raw = get(k), let data = raw.data(using: .utf8) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Bool] else { return nil }
        return obj
    }

    static func getSavedStatus() -> ConsentStatus? {
        guard let k = try? key("status"), let raw = get(k) else { return nil }
        return ConsentStatus(rawValue: raw)
    }

    static func isConsentStillValid() -> Bool {
        guard let cfg = try? ConsentConfig.shared.require() else { return false }
        guard let idKey = try? key("id"), get(idKey) != nil else { return false }

        guard let versionKey = try? key("version"),
              let versionRaw = get(versionKey),
              let storedVersion = Int(versionRaw),
              storedVersion == cfg.consentVersion else { return false }

        guard let tsKey = try? key("ts"),
              let tsRaw = get(tsKey),
              let storedTs = Double(tsRaw) else { return false }

        let ageDays = (Date().timeIntervalSince1970 * 1000 - storedTs) / (1000.0 * 60 * 60 * 24)
        if ageDays > Double(cfg.consentMaxAgeDays) { return false }

        return true
    }

    // MARK: - Device ID (org-independent — same device id no matter which org's SDK config is active)

    static func getOrCreateDeviceId() -> String {
        if let existing = get(deviceIdKey) {
            return existing
        }
        let newId = UUID().uuidString
        set(newId, forKey: deviceIdKey)
        return newId
    }

    // MARK: - Reset

    static func clear() {
        // Device id intentionally NOT removed here — the device's identity should
        // survive a consent reset, same as the Android SDK.
        guard let cfg = try? ConsentConfig.shared.require() else { return }
        let orgId = cfg.organizationId
        for suffix in ["id", "version", "ts", "prefs", "status"] {
            remove("fintrust_consent_\(orgId)_\(suffix)")
        }
    }
}
