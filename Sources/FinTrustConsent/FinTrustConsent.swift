import Foundation

/// Public entry point of the SDK — mirrors the Android Kotlin SDK's
/// `FinTrustConsent` object and the JS SDK's default export.
///
/// Usage:
/// ```swift
/// // App startup (e.g. in your App's init), once:
/// FinTrustConsent.initialize(
///     options: FinTrustConsentOptions(
///         organizationId: "YOUR-ORG-ID",
///         apiBaseUrl: "https://your-api.example.com",
///         accentColorHex: "#B8863B",
///         appName: "MyApp"
///     )
/// )
///
/// // Near the root of your SwiftUI view hierarchy:
/// ConsentBanner(onConsentChange: { result in
///     // enable/disable analytics based on result.preferences["Analytics"]
/// })
///
/// // Anywhere else:
/// let consent = FinTrustConsent.getConsent()
/// let token = FinTrustConsent.onConsentChange { result in ... }
/// await FinTrustConsent.identify(email: user.email) // async, call from a Task
/// ```
public enum FinTrustConsent {

    public static func initialize(options: FinTrustConsentOptions) {
        ConsentConfig.shared.configure(options)
    }

    public static func show() {
        ConsentBannerBridge.shared.trigger()
    }

    public static func getConsent() -> ConsentResult? {
        ConsentManager.getConsent()
    }

    public static func shouldShowBanner() -> Bool {
        ConsentManager.shouldShowBanner()
    }

    @discardableResult
    public static func onConsentChange(_ callback: @escaping (ConsentResult) -> Void) -> UUID {
        ConsentEventBus.shared.subscribe(callback)
    }

    public static func removeConsentChangeListener(_ token: UUID) {
        ConsentEventBus.shared.unsubscribe(token)
    }

    public static func identify(email: String? = nil, phone: String? = nil, age: Int? = nil) async {
        await ConsentManager.identify(email: email, phone: phone, age: age)
    }

    public static func getDeviceId() -> String {
        ConsentStorage.getOrCreateDeviceId()
    }

    public static func resetConsent() {
        ConsentManager.resetConsent()
    }
}