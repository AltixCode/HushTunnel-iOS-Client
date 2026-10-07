// Vestigial sing-box template UI, unreachable from HushTunnel's real navigation (ApplicationLibrary/HushTunnel/Views/RootView.swift only ever shows AuthView/ResellerHomeView/UserHomeView/VpnDisclosureView). Libbox can no longer be linked into the iOS build (see Library/Network/HTTPClient.swift).
#if !os(iOS)
import Foundation
import Library

@MainActor
public struct ButtonVisibilityState: Equatable {
    public var showGroupsButton = false
    public var showConnectionsButton = false
    public var groupsCount = 0
    public var connectionsCount = 0

    public init() {}

    public mutating func update(
        profile: ExtensionProfile?,
        commandClient: CommandClient
    ) {
        guard let profile else {
            reset()
            return
        }

        let actualGroupsCount = commandClient.groups?.count ?? 0
        let screenshotFallbackGroupsCount = 2
        groupsCount = Variant.screenshotMode && actualGroupsCount == 0
            ? screenshotFallbackGroupsCount
            : actualGroupsCount
        connectionsCount = Int(commandClient.status?.connectionsIn ?? 0)

        let isConnected = Variant.screenshotMode || profile.status.isConnectedStrict

        let hasGroups = Variant.screenshotMode || (commandClient.groups?.isEmpty == false)

        showConnectionsButton = isConnected
        showGroupsButton = isConnected && hasGroups
    }

    public mutating func update(remoteClient commandClient: CommandClient) {
        groupsCount = commandClient.groups?.count ?? 0
        connectionsCount = Int(commandClient.status?.connectionsIn ?? 0)
        showConnectionsButton = commandClient.isConnected
        showGroupsButton = commandClient.isConnected && groupsCount > 0
    }

    private mutating func reset() {
        showGroupsButton = false
        showConnectionsButton = false
        groupsCount = 0
        connectionsCount = 0
    }
}
#endif
