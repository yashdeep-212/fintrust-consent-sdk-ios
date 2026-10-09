import SwiftUI
import FinTrustConsent

struct ContentView: View {
    @State private var lastResult = "No consent yet"

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                Text("FinTrust Consent SDK — Test")
                    .font(.headline)
                Text(lastResult)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Open Cookie Settings") {
                    FinTrustConsent.show()
                }
                .buttonStyle(.borderedProminent)

                Button("Reset Consent (debug)") {
                    FinTrustConsent.resetConsent()
                    lastResult = "Consent reset — restart app to see banner"
                }
                .buttonStyle(.bordered)

                Button("Check Saved Consent") {
                    print("Device ID: \(FinTrustConsent.getDeviceId())")
                    if let consent = FinTrustConsent.getConsent() {
                        lastResult = "\(consent)"
                    } else {
                        lastResult = "No saved consent found"
                    }
                }
                .buttonStyle(.bordered)

                Button("Identify User") {
                    lastResult = "Identifying..."
                    Task {
                        await FinTrustConsent.identify(email: "testuser@example.com")
                        lastResult = "identify() called — check console for result"
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()

            // Mounted as a sibling, same pattern as the Android ConsentBanner usage.
            ConsentBanner(autoShow: true, onConsentChange: { result in
                print("Consent changed: \(result)")
            })
        }
    }
}

#Preview {
    ContentView()
}
