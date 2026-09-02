import Foundation

public enum BrandConfig {
    public static let appName = "HushTunnel"
    #if DEBUG
    public static let apiBaseURL = "http://localhost:3003"
    #else
    public static let apiBaseURL = "https://www.hushtunnel.com"
    #endif
    public static let appScheme = "hushtunnel"
    public static let supportURL = "https://www.hushtunnel.com"
    public static let appGroupID = "group.com.hushtunnel.vpn"
}
