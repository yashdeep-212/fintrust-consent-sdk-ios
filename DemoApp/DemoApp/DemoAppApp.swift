import SwiftUI
import FinTrustConsent

@main
struct DemoAppApp: App {
    init() {
        
        FinTrustConsent.initialize(options: FinTrustConsentOptions(
        organizationId: "c69ab324bec44e50a12fe808e8b17cf1",
        apiBaseUrl: "http://192.168.29.48:5161",   
        appName: "ConsentSdkTest",
        consentMaxAgeDays: 1
))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
