import SwiftUI

@MainActor
public final class VpnDisclosureConsent: ObservableObject {
    public static let shared = VpnDisclosureConsent()
    public static let currentVersion = 1

    @Published private var revision = 0
    private let defaults = UserDefaults.standard

    private init() {
        if CommandLine.arguments.contains("--reset-vpn-disclosure") {
            defaults.removeObject(forKey: key(for: "mock-user"))
        }
    }

    public func isAccepted(for userId: String) -> Bool {
        _ = revision
        return defaults.integer(forKey: key(for: userId)) >= Self.currentVersion
    }

    public func accept(for userId: String) {
        defaults.set(Self.currentVersion, forKey: key(for: userId))
        revision += 1
    }

    public func revoke(for userId: String) {
        defaults.removeObject(forKey: key(for: userId))
        revision += 1
    }

    private func key(for userId: String) -> String {
        "com.hushtunnel.vpnDisclosure.\(userId)"
    }
}

public struct VpnDisclosureView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject private var lang = LanguageManager.shared
    let onAccept: () -> Void
    let onDecline: () -> Void

    public init(onAccept: @escaping () -> Void, onDecline: @escaping () -> Void) {
        self.onAccept = onAccept
        self.onDecline = onDecline
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 54))
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)

                    Text(lang.tr("vpnDisclosure.title"))
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(lang.tr("vpnDisclosure.intro"))
                        .font(.body.bold())

                    disclosureRow(icon: "network", key: "vpnDisclosure.core")
                    disclosureRow(icon: "lock.fill", key: "vpnDisclosure.processing")
                    disclosureRow(icon: "externaldrive.fill", key: "vpnDisclosure.data")
                    disclosureRow(icon: "hand.raised.fill", key: "vpnDisclosure.monetization")

                    Text(lang.tr("vpnDisclosure.choice"))
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    HStack(spacing: 18) {
                        Button(lang.tr("privacy.policy")) {
                            if let url = URL(string: BrandConfig.privacyURL) { openURL(url) }
                        }
                        .accessibilityIdentifier("hush.vpn-disclosure-privacy")

                        Button(lang.tr("terms.title")) {
                            if let url = URL(string: BrandConfig.termsURL) { openURL(url) }
                        }
                        .accessibilityIdentifier("hush.vpn-disclosure-terms")
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity)

                    Button(action: onAccept) {
                        Text(lang.tr("vpnDisclosure.accept"))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("hush.vpn-disclosure-accept")

                    Button(lang.tr("vpnDisclosure.decline"), role: .cancel, action: onDecline)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("hush.vpn-disclosure-decline")
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .accessibilityIdentifier("hush.vpn-disclosure")
        }
        .environment(\.layoutDirection, lang.layoutDirection)
    }

    private func disclosureRow(icon: String, key: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(lang.tr(key))
                .font(.callout)
        }
    }
}
