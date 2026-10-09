# FinTrust Consent SDK — iOS (Swift)

Mirrors the Android Kotlin SDK (`fintrust-consent-sdk`) 1:1 — same config,
same save/identify flow, same device-UUID tracking, same two-step cookie
banner UI.

## Structure

```
fintrust-consent-sdk-ios/
├── Package.swift                    # SDK definition (like build.gradle.kts)
├── Sources/FinTrustConsent/         # the SDK itself
│   ├── Config.swift                 # FinTrustConsentOptions + ConsentConfig
│   ├── Models.swift                 # data types + category grouping logic
│   ├── Storage.swift                # Keychain-backed persistence + device UUID
│   ├── Api.swift                    # URLSession networking
│   ├── ConsentManager.swift         # core save/identify/reset logic + event bus
│   ├── ConsentBanner.swift          # SwiftUI cookie banner UI
│   └── FinTrustConsent.swift        # public entry point
├── DemoApp/                         # test app (like ConsentSdkTest on Android)
│   ├── project.yml                  # XcodeGen spec — generates the .xcodeproj
│   └── DemoApp/
│       ├── DemoAppApp.swift
│       └── ContentView.swift
└── codemagic.yaml                   # CI config
```

## Why no `.xcodeproj` file in this repo

Xcode project files are a binary/plist format that's easy to corrupt if
hand-written outside Xcode. Instead, `DemoApp/project.yml` describes the
app using **XcodeGen**, which Codemagic installs and runs on its Mac to
generate a clean `.xcodeproj` automatically on every build. You never have
to touch Xcode yourself.

## First milestone: compile check (no Apple Developer account needed)

The `ios-compile-check` workflow in `codemagic.yaml` builds the DemoApp for
the **iOS Simulator**, which doesn't require code signing — so this works
even before you have a paid Apple Developer Program membership. This is
the fastest way to confirm the Swift code is valid, since there's no way
to compile it locally without a Mac.

## Next milestone (later): real device + TestFlight

Once the compile check passes, the next step is a signed build that
installs on your actual iPhone via TestFlight. That needs:
- An Apple Developer Program membership (~₹8-9k/year)
- Code signing certificates + provisioning profile (Codemagic can
  auto-manage these once the account is connected)
- A second workflow in `codemagic.yaml` that builds an `.ipa` and
  publishes it to TestFlight

Ask for this once the compile check is green.

## Local testing note

`DemoAppApp.swift` points `apiBaseUrl` at `http://localhost:5161`. That
only works in the iOS Simulator (which shares your Mac's/PC's network
stack via Codemagic — not applicable here since there's no local Mac).
For a real iPhone hitting your Windows PC's local backend, you'll need
your PC's LAN IP (e.g. `http://192.168.1.42:5161`) and both devices on
the same Wi-Fi — `adb reverse` has no iOS equivalent.
