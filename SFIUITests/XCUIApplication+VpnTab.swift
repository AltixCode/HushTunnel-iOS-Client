import XCTest

extension XCUIApplication {
    /// Reseller accounts open on the Overview (Dashboard) tab, not Personal
    /// VPN. SwiftUI's TabView keeps every tab's content mounted, so
    /// `hush.connect-toggle` is findable in the accessibility tree even
    /// while a different tab is on screen — a plain existence check (or an
    /// untracked single tap on the tab bar) can't tell whether the VPN tab
    /// is actually frontmost, and a synthesized `.tap()` on a button that
    /// isn't really on screen silently hits whatever IS on screen instead
    /// (this is why connect taps were silently no-ops for reseller
    /// accounts). Taps the VPN tab by its own identifier and retries until
    /// it reports `isSelected`, so later taps are guaranteed to land on the
    /// visible tab. A no-op for non-reseller accounts, which have no tab
    /// bar at all.
    func ensureVpnTabVisible(timeout: TimeInterval = 10) {
        let vpnTab = buttons["hush.tab.vpn"]
        guard vpnTab.waitForExistence(timeout: 5) else { return }
        let deadline = Date().addingTimeInterval(timeout)
        while !vpnTab.isSelected, Date() < deadline {
            vpnTab.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }
    }
}
