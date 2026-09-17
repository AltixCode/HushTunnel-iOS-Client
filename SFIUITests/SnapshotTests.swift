import XCTest

/// The App Store screenshots.
///
/// Every frame here signs in first and asserts what is on screen before it
/// shoots. That is not ceremony. The previous version of this file did neither:
/// it set a `SCREENSHOT_PAGE` environment variable and called `snapshot(...)`
/// on whatever happened to be in front of it.
///
/// Both halves of that were broken.
///
/// `SCREENSHOT_PAGE` is read in `SFI/MainView.swift`, which is the upstream
/// sing-box tab interface — dashboard, logs, settings, tools, the profile
/// editor. HushTunnel does not show it. `SFI/Application.swift` roots the app
/// on `RootView`, so the variable selected a page in a view that never appears,
/// and `02_Logs` and `03_Settings` named screens this app does not have.
///
/// Nothing logged in, either. With no session `RootView` shows `AuthView`, so
/// an unasserted `snapshot("01_Dashboard")` photographs the **login screen** —
/// which is exactly the 2.3.3 rejection this app has already had once, for a
/// listing whose first frame was a login form. A capture pipeline that can
/// reproduce a past rejection on a green run is worse than no pipeline.
///
/// So: sign in, clear the VPN disclosure, wait for the real home screen, and
/// assert the target of each frame exists before capturing it. A test that
/// cannot reach its screen must fail loudly rather than hand back a picture of
/// something else.
///
/// Credentials come from the runner's environment, never from source:
///
///     HUSH_TEST_EMAIL=... HUSH_TEST_PASSWORD=... fastlane snapshot
///
/// Without them the tests skip, because a screenshot taken from a logged-out
/// app is not a screenshot worth keeping.
@MainActor
final class SnapshotTests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Start from no session at all. Without this the app opens on whatever
        // account was signed in last, and a capture run here photographed the
        // RESELLER dashboard -- prepaid balance, "Add wallet funds", "Add
        // Customer", "Add Sub-Reseller". Those frames on a listing would show a
        // distribution business a reviewer was never meant to see.
        app.launchArguments += ["--reset-session", "--reset-vpn-disclosure", "-app_language", "en"]
        setupSnapshot(app)
        app.launch()

        try signIn()
        acceptDisclosureIfPresent()

        // `hush.connect-toggle` is NOT enough: the reseller home carries one too,
        // behind its "My VPN" tab, so waiting on it would pass on the wrong
        // account's screen. `hush.iap.open` exists only in UserHomeView -- the
        // reseller equivalent is `hush.iap.open-subscriptions` -- so it is the
        // element that actually distinguishes the two.
        let userHome = app.descendants(matching: .any)["hush.iap.open"]
        XCTAssertTrue(
            userHome.waitForExistence(timeout: 40),
            "never reached the USER home screen — refusing to photograph another account's interface"
        )
    }

    private func signIn() throws {
        // Not "if needed". `--reset-session` guarantees the auth screen, so its
        // absence is a failure, not a shortcut: silently skipping login is how
        // the previous run ended up capturing a leftover account.
        let emailField = app.textFields["hush.auth.email"]
        XCTAssertTrue(
            emailField.waitForExistence(timeout: 20),
            "auth screen never appeared despite --reset-session — a session leaked in from somewhere"
        )
        let environment = ProcessInfo.processInfo.environment
        guard let email = environment["HUSH_TEST_EMAIL"],
              let password = environment["HUSH_TEST_PASSWORD"]
        else {
            throw XCTSkip(
                "HUSH_TEST_EMAIL / HUSH_TEST_PASSWORD were not supplied to the runner"
            )
        }
        emailField.tap()
        emailField.typeText(email)
        let passwordField = app.secureTextFields["hush.auth.password"]
        passwordField.tap()
        passwordField.typeText(password)
        app.buttons["hush.auth.submit"].tap()
    }

    private func acceptDisclosureIfPresent() {
        let disclosure = app.descendants(matching: .any)["hush.vpn-disclosure"]
        guard disclosure.waitForExistence(timeout: 20) else { return }
        let accept = app.buttons["hush.vpn-disclosure-accept"]
        // The disclosure is long enough to need scrolling on a phone, and an
        // element that exists but is not hittable cannot be tapped.
        for _ in 0 ..< 4 where !accept.isHittable {
            disclosure.swipeUp()
        }
        if accept.isHittable {
            accept.tap()
        }
    }

    /// The home screen, signed in, with a real plan and a real server.
    func test01Dashboard() {
        sleep(2)
        snapshot("01_Dashboard")
    }

    /// The native in-app purchase sheet.
    ///
    /// This exists because of a rejection. The live listing led with the home
    /// screen, which says subscriptions are managed on hushtunnel.com — so a
    /// reviewer saw an app steering purchases off-platform, while our review
    /// notes told Apple every plan is a native auto-renewable IAP. Both the
    /// sheet and the subscriptions are real; the listing simply never showed
    /// them. This frame is the evidence.
    func test02Plans() {
        let open = app.descendants(matching: .any)["hush.iap.open"]
        XCTAssertTrue(
            open.waitForExistence(timeout: 30),
            "hush.iap.open not found — cannot reach the purchase sheet"
        )
        open.tap()

        let sheet = app.descendants(matching: .any)["hush.iap.sheet"]
        XCTAssertTrue(
            sheet.waitForExistence(timeout: 30),
            "hush.iap.sheet never appeared — not capturing a substitute screen"
        )

        sleep(2)
        snapshot("02_Plans")
    }

    /// Account settings: the privacy links, App Store subscription management
    /// and permanent account deletion. This is the screen the review notes
    /// point at for 5.1.1(v), so it is worth a frame of its own.
    func test03Account() {
        let button = app.descendants(matching: .any)["hush.account.settings-button"]
        XCTAssertTrue(
            button.waitForExistence(timeout: 30),
            "hush.account.settings-button not found — cannot reach account settings"
        )
        button.tap()

        let settings = app.descendants(matching: .any)["hush.account.settings"]
        XCTAssertTrue(
            settings.waitForExistence(timeout: 30),
            "hush.account.settings never appeared — not capturing a substitute screen"
        )

        sleep(2)
        snapshot("03_Account")
    }
}
