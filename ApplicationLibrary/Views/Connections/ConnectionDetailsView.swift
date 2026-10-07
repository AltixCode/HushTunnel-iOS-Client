// Vestigial sing-box template UI, unreachable from HushTunnel's real navigation (ApplicationLibrary/HushTunnel/Views/RootView.swift only ever shows AuthView/ResellerHomeView/UserHomeView/VpnDisclosureView). Libbox can no longer be linked into the iOS build (see Library/Network/HTTPClient.swift).
#if !os(iOS)
import Foundation
import Libbox
import SwiftUI

public struct ConnectionDetailsView: View {
    private let connection: Connection
    public init(_ connection: Connection) {
        self.connection = connection
    }

    public var body: some View {
        FormView {
            if connection.closedAt != nil {
                FormTextItem("State", "Closed")
                FormTextItem("Created At", connection.createdAt.myFormat)
            } else {
                FormTextItem("State", "Active")
                FormTextItem("Created At", connection.createdAt.myFormat)
            }
            if let closedAt = connection.closedAt {
                FormTextItem("Closed At", closedAt.myFormat)
            }
            FormTextItem("Uplink", LibboxFormatBytes(connection.uploadTotal))
            FormTextItem("Downlink", LibboxFormatBytes(connection.downloadTotal))
            Section("Metadata") {
                FormTextItem("Inbound", connection.inbound)
                FormTextItem("Inbound Type", connection.inboundType)
                FormTextItem("IP Version", "\(connection.ipVersion)")
                FormTextItem("Network", connection.network.uppercased())
                FormTextItem("Source", connection.source)
                FormTextItem("Destination", connection.destination)
                if !connection.domain.isEmpty {
                    FormTextItem("Domain", connection.domain)
                }
                if !connection.protocolName.isEmpty {
                    FormTextItem("Protocol", connection.protocolName)
                }
                if !connection.user.isEmpty {
                    FormTextItem("User", connection.user)
                }
                if !connection.fromOutbound.isEmpty {
                    FormTextItem("From Outbound", connection.fromOutbound)
                }
                if !connection.rule.isEmpty {
                    FormTextItem("Match Rule", connection.rule)
                }
                FormTextItem("Outbound", connection.outbound)
                FormTextItem("Outbound Type", connection.outboundType)
                if connection.chain.count > 1 {
                    FormTextItem("Chain", connection.chain.reversed().joined(separator: "/"))
                }
            }
        }
        .navigationTitle("Connection")
    }
}
#endif
