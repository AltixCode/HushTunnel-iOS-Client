import Foundation

public enum BrandConfig {
    public static let appName = "HushTunnel"
    public static var apiBaseURL: String {
        if let override = ProcessInfo.processInfo.environment["HUSH_API_BASE_URL"], !override.isEmpty {
            return override
        }
        return "https://www.hushtunnel.com"
    }
    public static let appScheme = "hushtunnel"
    public static let supportURL = "https://www.hushtunnel.com"
    public static let privacyURL = "https://www.hushtunnel.com/privacy"
    public static let termsURL = "https://www.hushtunnel.com/terms"
    public static let appGroupID = "group.com.hushtunnel.vpn"
}
