import Foundation
#if !os(iOS)
    import Libbox
#endif

public enum Variant {
    #if os(macOS)
        public static var useSystemExtension = false
    #else
        public static let useSystemExtension = false
    #endif

    #if os(iOS)
        public static let applicationName = "HushTunnel"
    #elseif os(macOS)
        public static let applicationName = "SFM"
    #elseif os(tvOS)
        public static let applicationName = "SFT"
    #endif

    #if os(iOS)
        // iOS no longer runs sing-box/Libbox (see HTTPClient.swift) — this
        // app has its own version string (Bundle.application.versionNumber),
        // and "beta" has no meaning for HushTunnel's own release channel, so
        // this is simply false rather than reimplementing a check against
        // a value this platform no longer has.
        public static let isBeta = false
    #else
        public static let isBeta = LibboxVersion().contains("-")
    #endif

    #if DEBUG
        public static let inDebug = true
    #else
        public static let inDebug = false
    #endif

    #if os(iOS)
        public static var debugNoIOS26 = false
        public static var debugNoIOS18 = false
    #endif

    public static let screenshotMode = ProcessInfo.processInfo.arguments.contains("-FASTLANE_SNAPSHOT")
}
