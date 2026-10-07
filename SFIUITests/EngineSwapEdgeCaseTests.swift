import XCTest

/// On-device edge-case tests for the xray-core + hev-socks5-tunnel engine
/// swap (replaces sing-box on iOS). These complement
/// `ConnectionReliabilityTests` (which covers the basic connect + IP-verify
/// path) with the specific scenarios that matter for a VPN: status accuracy
/// across app lifecycle transitions, clean teardown, and repeat-cycle
/// stability. Requires a real device (NetworkExtension packet tunnels are
/// not reliably testable on Simulator) and `HUSH_TEST_EMAIL`/
/// `HUSH_TEST_PASSWORD` for an account with an active subscription.
@MainActor
final class EngineSwapEdgeCaseTests: XCTestCase {
    private func launchAndLogIn() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()

        let emailField = app.textFields["hush.auth.email"]
        if emailField.waitForExistence(timeout: 5) {
            let environment = ProcessInfo.processInfo.environment
            guard let email = environment["HUSH_TEST_EMAIL"],
                  let password = environment["HUSH_TEST_PASSWORD"]
            else {
                throw XCTSkip("Login credentials were not supplied to the test runner")
            }
            emailField.tap()
            emailField.typeText(email)
            let passwordField = app.secureTextFields["hush.auth.password"]
            let submitButton = app.buttons["hush.auth.submit"]
            if !submitButton.isEnabled {
                passwordField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                passwordField.typeText(password)
            }
            submitButton.tap()
        }

        let connectButton = app.buttons["hush.connect-toggle"]
        if !connectButton.waitForExistence(timeout: 5) {
            app.ensureVpnTabVisible()
        }
        guard connectButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("An authenticated account with an active subscription is required")
        }
        return app
    }

    private func statusValue(_ app: XCUIApplication) -> String? {
        app.descendants(matching: .any)["hush.status-label"].value as? String
    }

    private func waitForStatus(_ app: XCUIApplication, _ expected: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if statusValue(app) == expected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        return false
    }

    private func ensureConnected(_ app: XCUIApplication) throws {
        let connectButton = app.buttons["hush.connect-toggle"]
        if statusValue(app) != "connected" {
            let connectReady = NSPredicate(format: "enabled == true")
            expectation(for: connectReady, evaluatedWith: connectButton)
            waitForExpectations(timeout: 25)
            connectButton.tap()
            XCTAssertTrue(waitForStatus(app, "connected", timeout: 30), "Expected status to become 'connected' after tapping connect")
        }
    }

    /// Scenario 2: disconnect cleanly.
    func testDisconnectCleanly() throws {
        let app = try launchAndLogIn()
        try ensureConnected(app)

        let connectButton = app.buttons["hush.connect-toggle"]
        connectButton.tap()

        XCTAssertTrue(waitForStatus(app, "disconnected", timeout: 15), "Expected status to become 'disconnected' after tapping disconnect")

        // The connection-test control should be disabled once disconnected —
        // if it's still enabled, the UI thinks we're connected when we're not.
        let testButton = app.buttons["hush.connection-test"]
        XCTAssertFalse(testButton.isEnabled, "Connection test should be disabled while disconnected")
    }

    /// Scenario 4: background the app while connected, foreground it again,
    /// verify the UI reflects the real current status (not a stale cached
    /// value from before backgrounding).
    func testStatusSurvivesBackgroundForeground() throws {
        let app = try launchAndLogIn()
        try ensureConnected(app)

        XCUIDevice.shared.press(.home)
        // Give the extension process time to keep running independently of
        // the host app while backgrounded.
        Thread.sleep(forTimeInterval: 5)

        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        // If status observation only happened via a one-shot read at launch
        // (rather than a live NEVPNStatusDidChange subscription), this would
        // still correctly show "connected" here since the tunnel never
        // actually dropped — the real regression this guards against is the
        // UI showing "disconnected"/blank while the extension is actually
        // still connected, which happens when status is read once on
        // appear and never updated.
        XCTAssertTrue(waitForStatus(app, "connected", timeout: 10), "Expected status to read 'connected' immediately after foregrounding")
    }

    /// Scenario 5: kill the app while connected, relaunch — NetworkExtension
    /// tunnels persist independently of the host app process, so the UI must
    /// reflect that the tunnel is still running, not reset to disconnected.
    func testStatusSurvivesKillAndRelaunch() throws {
        let app = try launchAndLogIn()
        try ensureConnected(app)

        app.terminate()
        Thread.sleep(forTimeInterval: 2)

        let relaunched = XCUIApplication()
        relaunched.launch()

        let connectButton = relaunched.buttons["hush.connect-toggle"]
        if !connectButton.waitForExistence(timeout: 5) {
            relaunched.ensureVpnTabVisible()
        }
        _ = connectButton.waitForExistence(timeout: 10)

        XCTAssertTrue(waitForStatus(relaunched, "connected", timeout: 15), "Expected status to read 'connected' on relaunch — the NetworkExtension tunnel should have kept running independently of the killed host app")
    }

    /// Scenario 7: repeat connect/disconnect cycles, watching for hangs,
    /// crashes, or a status that stops updating.
    func testRepeatConnectDisconnectCycles() throws {
        let app = try launchAndLogIn()
        let connectButton = app.buttons["hush.connect-toggle"]

        for cycle in 1...3 {
            if statusValue(app) != "connected" {
                let connectReady = NSPredicate(format: "enabled == true")
                expectation(for: connectReady, evaluatedWith: connectButton)
                waitForExpectations(timeout: 25)
                connectButton.tap()
            }
            XCTAssertTrue(waitForStatus(app, "connected", timeout: 30), "Cycle \(cycle): failed to reach 'connected'")

            connectButton.tap()
            XCTAssertTrue(waitForStatus(app, "disconnected", timeout: 15), "Cycle \(cycle): failed to reach 'disconnected'")
        }
    }
}
