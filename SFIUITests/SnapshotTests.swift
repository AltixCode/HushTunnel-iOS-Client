import XCTest

@MainActor
final class SnapshotTests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        if let page = screenshotPage() {
            app.launchEnvironment["SCREENSHOT_PAGE"] = page
        } else {
            app.launchEnvironment["SCREENSHOT_PAGE"] = ""
        }
        setupSnapshot(app)
        app.launch()
    }

    private func screenshotPage() -> String? {
        let testName = name
        if testName.contains("test01Dashboard") {
            return "dashboard"
        }
        if testName.contains("test02Logs") {
            return "logs"
        }
        if testName.contains("test03Settings") {
            return "settings"
        }
        return nil
    }

    func test01Dashboard() {
        snapshot("01_Dashboard")
    }

    func test02Logs() {
        sleep(1)
        snapshot("02_Logs")
    }

    func test03Settings() {
        sleep(1)
        snapshot("03_Settings")
    }

    /// The native in-app purchase sheet.
    ///
    /// This exists because of a rejection. The live listing led with the home
    /// screen, which says subscriptions are managed on hushtunnel.com - so a
    /// reviewer saw an app steering purchases off-platform, while our review
    /// notes told Apple every plan is a native auto-renewable IAP. Both the
    /// sheet and the subscriptions are real; the listing simply never showed
    /// them. This frame is the evidence.
    ///
    /// It asserts rather than snapshotting whatever happens to be on screen:
    /// a screenshot of the home screen filed as "Plans" would restate the
    /// problem it was added to fix.
    func test04Plans() {
        let open = app.descendants(matching: .any)["hush.iap.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 30),
                      "hush.iap.open not found - cannot reach the purchase sheet")
        open.tap()

        let sheet = app.descendants(matching: .any)["hush.iap.sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 30),
                      "hush.iap.sheet never appeared - not capturing a substitute screen")

        sleep(2)
        snapshot("04_Plans")
    }
}
