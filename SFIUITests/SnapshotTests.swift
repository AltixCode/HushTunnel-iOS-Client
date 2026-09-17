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
        setupSnapshot(app)
        app.launch()

        try signInIfNeeded()
        acceptDisclosureIfPresent()

        // The connect button is the home screen's defining element. Waiting on
        // it is what separates "the app is up" from "something is up".
        let home = app.descendants(matching: .any)["hush.connect-toggle"]
        XCTAssertTrue(
            home.waitForExistence(timeout: 40),
            "never reached the home screen — refusing to photograph whatever is there instead"
        )
    }

    private func signInIfNeeded() throws {
        let emailField = app.textFields["hush.auth.email"]
        guard emailField.waitForExistence(timeout: 15) else {
            return // already signed in from a previous test in the same run
        }
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
