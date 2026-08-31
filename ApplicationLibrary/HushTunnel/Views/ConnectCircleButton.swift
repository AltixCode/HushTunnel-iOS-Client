import Library
import SwiftUI

/// The branded big circular Connect/Disconnect button, wired to the real
/// `ExtensionProfile` (NetworkExtension) the same way `StartStopButton` is —
/// taking `profile` as a direct `@ObservedObject` (not via `@EnvironmentObject`)
/// so SwiftUI actually re-renders when `profile.status` changes. Reading
/// `environments.extensionProfile?.status` directly from a view that only
/// holds `environments` as an `@EnvironmentObject` would NOT do this: changes
/// to a `@Published` property on an object *held by* another `ObservableObject`
/// don't propagate through the outer object's `objectWillChange` on their own.
public struct ConnectCircleButton: View {
    @ObservedObject var profile: ExtensionProfile
    @State private var isStarting = false
    @State private var alert: AlertState?
    @ObservedObject var lang = LanguageManager.shared

    public init(profile: ExtensionProfile) {
        self.profile = profile
    }

    private var isConnected: Bool { profile.status == .connected || profile.status == .reasserting }
    private var isConnecting: Bool { isStarting || profile.status == .connecting }

    public var body: some View {
        Button(action: toggle) {
            ZStack {
                Circle()
                    .fill(isConnected ? Color.green : (isConnecting ? Color.orange : Color.accentColor))
                    .frame(width: 140, height: 140)
                    .shadow(color: (isConnected ? Color.green : Color.accentColor).opacity(0.35), radius: 20, x: 0, y: 10)

                VStack(spacing: 6) {
                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.4)
                    } else {
                        Image(systemName: isConnected ? "lock.shield.fill" : "power")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text(isConnecting ? lang.tr("vpn.connecting") : (isConnected ? lang.tr("vpn.disconnect") : lang.tr("vpn.connect")))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(!profile.status.isEnabled || isConnecting)
        .alert($alert)
    }

    private func toggle() {
        Task {
            do {
                if isConnected {
                    try await profile.stop()
                } else {
                    await MainActor.run { isStarting = true }
                    try await profile.start()
                }
            } catch {
                await MainActor.run {
                    alert = AlertState(action: isConnected ? "stop service" : "start service", error: error)
                }
            }
            await MainActor.run { isStarting = false }
        }
    }
}

/// Status dot + label matching the branded status row under the connect circle.
public struct ConnectStatusLabel: View {
    @ObservedObject var profile: ExtensionProfile
    @ObservedObject var lang = LanguageManager.shared

    public init(profile: ExtensionProfile) {
        self.profile = profile
    }

    private var isConnected: Bool { profile.status == .connected || profile.status == .reasserting }
    private var isConnecting: Bool { profile.status == .connecting }

    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isConnected ? Color.green : (isConnecting ? Color.orange : Color.gray))
                .frame(width: 10, height: 10)

            Text(isConnecting ? lang.tr("vpn.connecting") : (isConnected ? lang.tr("vpn.connected") : lang.tr("vpn.disconnected")))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}
