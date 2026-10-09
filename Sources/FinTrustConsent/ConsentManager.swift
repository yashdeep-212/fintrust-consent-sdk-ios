import Foundation


internal final class ConsentEventBus {
    static let shared = ConsentEventBus()
    private init() {}

    private let lock = NSLock()
    private var listeners: [UUID: (ConsentResult) -> Void] = [:]

    func subscribe(_ callback: @escaping (ConsentResult) -> Void) -> UUID {
        let token = UUID()
        lock.lock(); listeners[token] = callback; lock.unlock()
        return token
    }

    func unsubscribe(_ token: UUID) {
        lock.lock(); listeners.removeValue(forKey: token); lock.unlock()
    }

    func emit(_ result: ConsentResult) {
        lock.lock(); let current = listeners.values; lock.unlock()
        current.forEach { $0(result) }
    }
}


internal final class ConsentBannerBridge {
    static let shared = ConsentBannerBridge()
    private init() {}

    private var openFn: (() -> Void)?

    func register(_ fn: @escaping () -> Void) { openFn = fn }
    func trigger() { openFn?() }
}

internal enum ConsentManager {

    private static func generateConsentId() -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        let rand = String((0..<9).map { _ in chars.randomElement()! })
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        return "CONSENT_\(rand)\(ts)"
    }

    static func shouldShowBanner() -> Bool {
        !ConsentStorage.isConsentStillValid()
    }

    static func loadCategories() async throws -> (cookies: [ConsentCookie], categories: [ConsentCategory]) {
        let orgId = try ConsentConfig.shared.require().organizationId
        let cookies = try await ConsentApi.fetchCookies(organizationId: orgId)
        return (cookies, ConsentCategoryLogic.groupCookiesByCategory(cookies))
    }

    static func getConsent() -> ConsentResult? {
        guard let consentId = ConsentStorage.getConsentId() else { return nil }
        let prefs = ConsentStorage.getSavedPreferences() ?? [:]
        let status = ConsentStorage.getSavedStatus() ?? .accepted
        return ConsentResult(consentId: consentId, preferences: prefs, status: status)
    }

    static func save(
        cookies: [ConsentCookie],
        categories: [ConsentCategory],
        mode: ConsentSaveMode,
        toggled: [String: Bool] = [:]
    ) async throws -> ConsentResult {
        let orgId = try ConsentConfig.shared.require().organizationId
        let finalPrefs = ConsentCategoryLogic.buildFinalPreferences(categories: categories, mode: mode, toggled: toggled)
        let status = ConsentCategoryLogic.computeStatus(categories: categories, finalPrefs: finalPrefs)

        let anchor = cookies.first { ConsentCategoryLogic.isNecessaryCategory($0.categoryName) } ?? cookies.first
        let consentId = generateConsentId()

        if let anchor = anchor {
            let message: String
            switch mode {
            case .acceptAll: message = "User accepted all cookies."
            case .rejectAll: message = "User rejected all optional cookies."
            case .custom: message = "User updated cookie consent preferences."
            }

            let prefsData = try JSONSerialization.data(withJSONObject: finalPrefs)
            let prefsJson = String(data: prefsData, encoding: .utf8) ?? "{}"

            let payload: [String: Any] = [
                "organizationId": orgId,
                "categoryId": anchor.cookieCategoryId ?? NSNull(),
                "consentCategoryName": "Cookie Preferences",
                "consentMessage": message,
                "isAccepted": status == .accepted,
                "uniqueConsentId": consentId,
                "acceptedDeclinedCategories": prefsJson,
                "deviceId": ConsentStorage.getOrCreateDeviceId()
            ]

            try await ConsentApi.submitConsent(payload: payload)
        }

        try ConsentStorage.save(consentId: consentId, preferences: finalPrefs, status: status)
        let result = ConsentResult(consentId: consentId, preferences: finalPrefs, status: status)
        ConsentEventBus.shared.emit(result)
        return result
    }

    static func identify(email: String? = nil, phone: String? = nil, age: Int? = nil) async {
        let hasEmail = !(email ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        let hasPhone = !(phone ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        if !hasEmail && !hasPhone && age == nil { return }

        
        let deviceId = ConsentStorage.getOrCreateDeviceId()
        let consentId = ConsentStorage.getConsentId()
        do {
            try await ConsentApi.identify(uniqueConsentId: consentId, email: email, deviceId: deviceId, phone: phone, age: age)
        } catch {
            print("[FinTrustConsent] identify() failed: \(error)")
        }
    }

    static func resetConsent() {
        ConsentStorage.clear()
    }
}