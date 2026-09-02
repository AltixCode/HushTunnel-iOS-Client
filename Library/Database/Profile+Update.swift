import Foundation
import GRDB
import Libbox

public extension Profile {
    nonisolated func updateRemoteProfile(
        content suppliedContent: String? = nil,
        reloadIfSelected: Bool = true
    ) async throws {
        if type != .remote {
            return
        }
        let remoteContent: String
        if let suppliedContent {
            remoteContent = suppliedContent
        } else {
            remoteContent = try await HTTPClient.getStringAsync(remoteURL)
        }
        try await BlockingIO.run {
            var error: NSError?
            LibboxCheckConfig(remoteContent, &error)
            if let error {
                throw error
            }
        }
        await MainActor.run {
            lastUpdated = Date()
        }
        try await ProfileManager.update(self)
        do {
            let oldContent = try await readAsync()
            if oldContent == remoteContent {
                return
            }
        } catch {}
        try await writeAsync(remoteContent)
        if reloadIfSelected {
            try await onProfileUpdated()
        }
    }

    nonisolated func onProfileUpdated() async throws {
        if await SharedPreferences.selectedProfileID.get() == id {
            if let profile = try? await ExtensionProfile.load() {
                if await profile.status == .connected {
                    try await profile.reloadService()
                }
            }
        }
    }
}
