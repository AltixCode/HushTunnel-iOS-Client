// Vestigial sing-box template UI, unreachable from HushTunnel's real navigation (ApplicationLibrary/HushTunnel/Views/RootView.swift only ever shows AuthView/ResellerHomeView/UserHomeView/VpnDisclosureView). Libbox can no longer be linked into the iOS build (see Library/Network/HTTPClient.swift).
#if !os(iOS)
import Libbox
import Library
import SwiftUI

public struct StatusCard: View {
    @EnvironmentObject private var commandClient: CommandClient

    public init() {}

    public var body: some View {
        DashboardCardView(title: "", isHalfWidth: true) {
            VStack(alignment: .leading, spacing: 8) {
                DashboardCardHeader(icon: "info.circle.fill", title: "Status")
                if Variant.screenshotMode {
                    DashboardCardLine(String(localized: "Memory"), "6.4 MB")
                    DashboardCardLine(String(localized: "Goroutines"), "89")
                } else if let message = commandClient.status {
                    DashboardCardLine(String(localized: "Memory"), LibboxFormatMemoryBytes(message.memory))
                    DashboardCardLine(String(localized: "Goroutines"), "\(message.goroutines)")
                } else {
                    DashboardCardLine(String(localized: "Memory"), "...")
                    DashboardCardLine(String(localized: "Goroutines"), "...")
                }
            }
        }
    }
}
#endif
