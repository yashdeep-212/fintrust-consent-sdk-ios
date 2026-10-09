// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FinTrustConsent",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "FinTrustConsent",
            targets: ["FinTrustConsent"]
        )
    ],
    targets: [
        .target(
            name: "FinTrustConsent",
            path: "Sources/FinTrustConsent"
        )
    ]
)
