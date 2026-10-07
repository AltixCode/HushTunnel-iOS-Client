// Vestigial sing-box template UI, unreachable from HushTunnel's real navigation (ApplicationLibrary/HushTunnel/Views/RootView.swift only ever shows AuthView/ResellerHomeView/UserHomeView/VpnDisclosureView). Libbox can no longer be linked into the iOS build (see Library/Network/HTTPClient.swift).
#if !os(iOS)
import Libbox
import Library
import SwiftUI

public struct ConnectionsCard: View {
    @EnvironmentObject private var commandClient: CommandClient

    public init() {}

    public var body: some View {
        DashboardCardView(title: "", isHalfWidth: true) {
            VStack(alignment: .leading, spacing: 8) {
                DashboardCardHeader(icon: "link.circle.fill", title: "Connections")
                if Variant.screenshotMode {
                    DashboardCardLine(String(localized: "Inbound"), "34")
                    DashboardCardLine(String(localized: "Outbound"), "28")
                } else if let message = commandClient.status {
                    DashboardCardLine(String(localized: "Inbound"), "\(message.connectionsIn)")
                    DashboardCardLine(String(localized: "Outbound"), "\(message.connectionsOut)")
                } else {
                    DashboardCardLine(String(localized: "Inbound"), "...")
                    DashboardCardLine(String(localized: "Outbound"), "...")
                }
            }
        }
    }
}
#endif
