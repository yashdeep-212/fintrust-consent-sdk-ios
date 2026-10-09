import Foundation

/// Options passed to FinTrustConsent.initialize(...).
/// Mirrors the Android Kotlin SDK's FinTrustConsentOptions.
public struct FinTrustConsentOptions {
    public let organizationId: String
    public let apiBaseUrl: String
    public let accentColorHex: String
    public let appName: String
    public let consentVersion: Int
    public let consentMaxAgeDays: Int

    /// trailing slash trimmed, same as Android/JS SDKs
    public let normalizedApiBaseUrl: String

    public init(
        organizationId: String,
        apiBaseUrl: String,
        accentColorHex: String = "#B8863B",
        appName: String = "this app",
        consentVersion: Int = 1,
        consentMaxAgeDays: Int = 180
    ) {
        self.organizationId = organizationId
        self.apiBaseUrl = apiBaseUrl
        self.accentColorHex = accentColorHex
        self.appName = appName
        self.consentVersion = consentVersion
        self.consentMaxAgeDays = consentMaxAgeDays

        var trimmed = apiBaseUrl
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        self.normalizedApiBaseUrl = trimmed
    }
}

/// Thrown when the SDK is used before initialize() is called.
public struct FinTrustConsentError: Error, CustomStringConvertible {
    public let message: String
    public var description: String { message }
}

/// Internal config store — equivalent of Config.kt's ConsentConfig object.
internal final class ConsentConfig {
    static let shared = ConsentConfig()
    private init() {}

    private let lock = NSLock()
    private var options: FinTrustConsentOptions?

    var isInitialized: Bool {
        lock.lock(); defer { lock.unlock() }
        return options != nil
    }

    func configure(_ opts: FinTrustConsentOptions) {
        lock.lock(); defer { lock.unlock() }
        options = opts
    }

    /// Same contract as the Kotlin SDK's require() — throws instead of crashing,
    /// so callers can handle "not initialized" gracefully.
    func require() throws -> FinTrustConsentOptions {
        lock.lock(); defer { lock.unlock() }
        guard let opts = options else {
            throw FinTrustConsentError(message: "[FinTrustConsent] SDK not initialized. Call FinTrustConsent.initialize(...) before using it.")
        }
        return opts
    }
}
