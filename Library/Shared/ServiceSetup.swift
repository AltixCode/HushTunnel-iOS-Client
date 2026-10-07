import Foundation
#if !os(iOS)
    import Libbox
#endif

public enum ServiceSetup {
    public static func apply(crashReportSource: String) throws {
        #if os(iOS)
            // iOS no longer runs sing-box (see HTTPClient.swift for why
            // Libbox can't be linked into the iOS build at all anymore).
            // This only ever configured sing-box/Libbox's own internal
            // base/working/temp paths and crash-report metadata — nothing
            // downstream on iOS reads that state anymore, so there is
            // nothing to replace it with; this is intentionally a no-op.
            _ = crashReportSource
        #else
            let options = LibboxSetupOptions()
            options.basePath = FilePath.sharedDirectory.relativePath
            options.workingPath = FilePath.workingDirectory.relativePath
            options.tempPath = FilePath.cacheDirectory.relativePath
            options.crashReportSource = crashReportSource
            options.appVersion = Bundle.application.versionNumber
            options.appMarketingVersion = Bundle.application.version
            var error: NSError?
            LibboxSetup(options, &error)
            if let error {
                throw error
            }
        #endif
    }
}
