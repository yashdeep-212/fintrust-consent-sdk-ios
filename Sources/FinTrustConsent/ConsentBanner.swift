import SwiftUI

private enum ConsentStep {
    case banner
    case preferences
}

/// Equivalent of ConsentBanner.kt — two-step bottom sheet (banner -> preference
/// center), backed by FinTrustConsent's internal ConsentManager.
///
/// Drop this near the root of your app, e.g.:
/// ```swift
/// var body: some View {
///     ZStack {
///         MyRootScreen()
///         ConsentBanner(onConsentChange: { result in ... })
///     }
/// }
/// ```
public struct ConsentBanner: View {
    private let autoShow: Bool
    private let onConsentChange: ((ConsentResult) -> Void)?

    public init(autoShow: Bool = true, onConsentChange: ((ConsentResult) -> Void)? = nil) {
        self.autoShow = autoShow
        self.onConsentChange = onConsentChange
    }

    @State private var visible = false
    @State private var step: ConsentStep = .banner
    @State private var fetching = false
    @State private var saving = false
    @State private var loadError: String?
    @State private var cookies: [ConsentCookie] = []
    @State private var categories: [ConsentCategory] = []
    @State private var toggled: [String: Bool] = [:]

    public var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                ConsentBannerBridge.shared.register { open() }
                if autoShow && ConsentManager.shouldShowBanner() {
                    open()
                }
            }
            .sheet(isPresented: $visible) {
                sheetContent
                    .presentationDetents([.medium, .large])
            }
    }

    private var accentColor: Color {
        guard let cfg = try? ConsentConfig.shared.require() else { return Color(red: 0.72, green: 0.53, blue: 0.24) }
        return Color(hex: cfg.accentColorHex)
    }

    private var appName: String {
        (try? ConsentConfig.shared.require().appName) ?? "this app"
    }

    @ViewBuilder
    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(step == .banner ? "Cookie Notice" : "Privacy Preference Center")
                    .font(.headline)
                Spacer()
                Button(action: { visible = false }) {
                    Image(systemName: "xmark")
                }
            }

            if fetching {
                HStack {
                    Spacer()
                    ProgressView().tint(accentColor)
                    Spacer()
                }
                .padding()
            } else if let error = loadError {
                VStack(alignment: .leading, spacing: 10) {
                    Text(error).font(.footnote).foregroundColor(.red)
                    Button("Retry") { open() }
                        .buttonStyle(.bordered)
                }
            } else if step == .banner {
                bannerStep
            } else {
                preferencesStep
            }
        }
        .padding(20)
    }

    private var bannerStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("By continuing using \(appName), you accept third party cookies or other tracers used for app analysis and statistics, to provide you with interest-based advertising and to offer you videos, social sharing buttons and contents from social platforms.")
                .font(.footnote)

            HStack(spacing: 8) {
                Button("PERSONALIZE") { step = .preferences }
                    .buttonStyle(.bordered)
                    .disabled(saving)
                    .frame(maxWidth: .infinity)

                Button(action: { handleSave(.acceptAll) }) {
                    if saving {
                        ProgressView().tint(.black)
                    } else {
                        Text("OK, ACCEPT ALL")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .disabled(saving)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var preferencesStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose which categories of cookies this app can use. Necessary cookies keep the app working and can't be switched off.")
                .font(.footnote)

            ScrollView {
                VStack(spacing: 0) {
                    if categories.isEmpty {
                        Text("No cookie categories configured yet.")
                            .font(.footnote)
                    }
                    ForEach(categories, id: \.name) { cat in
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(cat.name).font(.body)
                                    Text("\(cat.count) cookie\(cat.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if cat.isNecessary {
                                    Text("ALWAYS ACTIVE")
                                        .font(.caption)
                                        .foregroundColor(accentColor)
                                } else {
                                    Toggle("", isOn: Binding(
                                        get: { toggled[cat.name] ?? false },
                                        set: { toggled[cat.name] = $0 }
                                    ))
                                    .labelsHidden()
                                    .tint(accentColor)
                                }
                            }
                            .padding(.vertical, 8)
                            Divider()
                        }
                    }
                }
            }
            .frame(maxHeight: 300)

            HStack(spacing: 8) {
                Button("BACK") { step = .banner }
                    .buttonStyle(.bordered)
                    .disabled(saving)
                    .frame(maxWidth: .infinity)

                Button("ALLOW ALL") { handleSave(.acceptAll) }
                    .buttonStyle(.bordered)
                    .disabled(saving)
                    .frame(maxWidth: .infinity)

                Button(action: { handleSave(.custom) }) {
                    if saving {
                        ProgressView().tint(.black)
                    } else {
                        Text("SAVE")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .disabled(saving)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func open() {
        step = .banner
        visible = true
        fetching = true
        loadError = nil
        Task {
            do {
                let (fetchedCookies, grouped) = try await ConsentManager.loadCategories()
                cookies = fetchedCookies
                categories = grouped
                // opt-in by default until user changes — same behavior as the Android SDK.
                toggled = Dictionary(uniqueKeysWithValues: grouped.map { ($0.name, true) })
            } catch {
                loadError = "\(error)"
            }
            fetching = false
        }
    }

    private func handleSave(_ mode: ConsentSaveMode) {
        saving = true
        Task {
            do {
                let result = try await ConsentManager.save(cookies: cookies, categories: categories, mode: mode, toggled: toggled)
                onConsentChange?(result)
            } catch {
                print("[FinTrustConsent] save failed: \(error)")
            }
            saving = false
            visible = false
        }
    }
}

private extension Color {
    /// Parses a "#RRGGBB" hex string, same as Android's parseHexColor().
    init(hex: String) {
        var clean = hex
        if clean.hasPrefix("#") { clean.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
