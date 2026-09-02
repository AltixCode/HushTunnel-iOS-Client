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
    var isProvisioning: Bool
    var prepareForConnect: (() async throws -> Void)?
    @State private var isStarting = false
    @State private var alert: AlertState?
    @ObservedObject var lang = LanguageManager.shared

    public init(
        profile: ExtensionProfile,
        isProvisioning: Bool = false,
        prepareForConnect: (() async throws -> Void)? = nil
    ) {
        self.profile = profile
        self.isProvisioning = isProvisioning
        self.prepareForConnect = prepareForConnect
    }

    private var isConnected: Bool { profile.status == .connected || profile.status == .reasserting }
    private var isConnecting: Bool { isStarting || profile.status == .connecting || isProvisioning }

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

                    Text(isProvisioning ? lang.tr("vpn.preparing") : (isConnecting ? lang.tr("vpn.connecting") : (isConnected ? lang.tr("vpn.disconnect") : lang.tr("vpn.connect"))))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(!profile.status.isEnabled || isConnecting)
        .accessibilityIdentifier("hush.connect-toggle")
        .alert($alert)
    }

    private func toggle() {
        Task {
            do {
                if isConnected {
                    try await profile.stop()
                } else {
                    await MainActor.run { isStarting = true }
                    try await prepareForConnect?()
                    if await SharedPreferences.selectedProfileID.get() == 0 {
                        if let activeProfile = try await ProfileManager.get(by: ProvisionHelper.profileName) {
                            await SharedPreferences.selectedProfileID.set(activeProfile.mustID)
                        }
                    }
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

public struct ConnectionTestView: View {
    @ObservedObject var profile: ExtensionProfile
    let expectedHost: String
    @ObservedObject var lang = LanguageManager.shared
    @State private var isTesting = false
    @State private var result: ResultState?

    private struct ResultState {
        enum Status { case success, warning, error }
        let status: Status
        let message: String
    }

    private var isConnected: Bool {
        profile.status == .connected || profile.status == .reasserting
    }

    public init(profile: ExtensionProfile, expectedHost: String) {
        self.profile = profile
        self.expectedHost = expectedHost
    }

    public var body: some View {
        VStack(spacing: 8) {
            Button {
                runTest()
            } label: {
                HStack(spacing: 6) {
                    if isTesting {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "bolt.horizontal.circle.fill")
                            .font(.system(size: 14))
                    }
                    Text(isTesting ? lang.tr("vpn.testing") : lang.tr("vpn.testConnection"))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.12))
                .foregroundColor(.accentColor)
                .cornerRadius(20)
            }
            .disabled(isTesting || !isConnected)
            .opacity(isConnected ? 1 : 0.55)
            .accessibilityIdentifier("hush.connection-test")

            if let result {
                HStack(spacing: 6) {
                    Image(systemName: result.status == .success ? "checkmark.shield.fill" : (result.status == .warning ? "exclamationmark.shield.fill" : "xmark.octagon.fill"))
                        .font(.caption)
                    Text(result.message)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(result.status == .success ? .green : (result.status == .warning ? .orange : .red))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((result.status == .success ? Color.green : (result.status == .warning ? Color.orange : Color.red)).opacity(0.1))
                .cornerRadius(10)
                .accessibilityIdentifier(
                    result.status == .success
                        ? "hush.connection-test-result.success"
                        : (result.status == .warning
                            ? "hush.connection-test-result.warning"
                            : "hush.connection-test-result.error")
                )
            }
        }
        .onChange(of: expectedHost) { _, _ in result = nil }
        .onChange(of: profile.status) { _, status in
            if status != .connected && status != .reasserting { result = nil }
        }
    }

    private func runTest() {
        guard !isTesting, isConnected else { return }
        isTesting = true
        result = nil

        Task {
            let start = DispatchTime.now()
            let sessionConfiguration = URLSessionConfiguration.ephemeral
            sessionConfiguration.urlCache = nil
            sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            sessionConfiguration.timeoutIntervalForRequest = 8
            sessionConfiguration.timeoutIntervalForResource = 10
            let session = URLSession(configuration: sessionConfiguration)

            do {
                let nonce = UUID().uuidString
                var request = URLRequest(url: URL(string: "https://api.ipify.org?format=json&nonce=\(nonce)")!)
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                let (data, response) = try await session.data(for: request)
                let latency = Int(Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let rawIP = json["ip"] as? String
                else {
                    throw NSError(domain: "ConnectionTest", code: 1)
                }

                var dataRequest = URLRequest(url: URL(string: "https://www.apple.com/?hush_test=\(nonce)")!)
                dataRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                let (_, dataResponse) = try await session.data(for: dataRequest)
                guard let httpDataResponse = dataResponse as? HTTPURLResponse,
                      (200...399).contains(httpDataResponse.statusCode)
                else {
                    throw NSError(domain: "ConnectionTest", code: 2)
                }

                let ip = rawIP.trimmingCharacters(in: .whitespacesAndNewlines)
                let matches = ip.caseInsensitiveCompare(expectedHost.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
                await MainActor.run {
                    result = ResultState(
                        status: matches ? .success : .warning,
                        message: matches
                            ? String(format: lang.tr("vpn.testSuccess"), latency, ip)
                            : String(format: lang.tr("vpn.testIpMismatch"), ip)
                    )
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    result = ResultState(status: .error, message: lang.tr("vpn.testFailed"))
                    isTesting = false
                }
            }
            session.invalidateAndCancel()
        }
    }
}

/// Status dot + label matching the branded status row under the connect circle.
public struct ConnectStatusLabel: View {
    @ObservedObject var profile: ExtensionProfile
    var isProvisioning: Bool
    @ObservedObject var lang = LanguageManager.shared

    public init(profile: ExtensionProfile, isProvisioning: Bool = false) {
        self.profile = profile
        self.isProvisioning = isProvisioning
    }

    private var isConnected: Bool { profile.status == .connected || profile.status == .reasserting }
    private var isConnecting: Bool { profile.status == .connecting || isProvisioning }

    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isConnected ? Color.green : (isConnecting ? Color.orange : Color.gray))
                .frame(width: 10, height: 10)

            Text(isProvisioning ? lang.tr("vpn.preparing") : (isConnecting ? lang.tr("vpn.connecting") : (isConnected ? lang.tr("vpn.connected") : lang.tr("vpn.disconnected"))))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}
