import XCTest

@MainActor
final class StoreComplianceTests: XCTestCase {
    func testNativePurchaseAndPermanentDeletionSurfaces() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mock-session", "--reset-vpn-disclosure", "-app_language", "en"]
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
            passwordField.tap()
            passwordField.typeText(password)
            app.buttons["hush.auth.submit"].tap()
        }

        let disclosure = app.descendants(matching: .any)["hush.vpn-disclosure"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["HushTunnel needs VPN access"].exists)
        XCTAssertTrue(app.buttons["hush.vpn-disclosure-privacy"].exists)
        XCTAssertTrue(app.buttons["hush.vpn-disclosure-terms"].exists)
        XCTAssertTrue(app.buttons["hush.vpn-disclosure-decline"].exists)
        let disclosureAccept = app.buttons["hush.vpn-disclosure-accept"]
        for _ in 0..<4 where !disclosureAccept.isHittable {
            disclosure.swipeUp()
        }
        XCTAssertTrue(disclosureAccept.isHittable)
        disclosureAccept.tap()

        let settingsButton = app.buttons["hush.account.settings-button"]
        guard settingsButton.waitForExistence(timeout: 12) else {
            throw XCTSkip("An authenticated user or reseller account is required")
        }
        settingsButton.tap()
        let settingsScreen = app.descendants(matching: .any)["hush.account.settings"]
        XCTAssertTrue(settingsScreen.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No browsing or activity logs"].exists)
        XCTAssertTrue(app.staticTexts["Deleting your HushTunnel account does not cancel an Apple subscription. Cancel it here first to prevent future charges."].exists)

        let deletionButton = app.buttons["hush.account.delete-button"]
        for _ in 0..<4 where !deletionButton.exists {
            settingsScreen.swipeUp()
        }
        XCTAssertTrue(deletionButton.waitForExistence(timeout: 3))
        XCTAssertFalse(deletionButton.isEnabled)
        let deletionPassword = app.secureTextFields["hush.account.delete-password"]
        deletionPassword.tap()
        deletionPassword.typeText("not-the-real-password")
        let deletionConfirmation = app.textFields["hush.account.delete-confirmation"]
        deletionConfirmation.tap()
        deletionConfirmation.typeText("DELETE")
        XCTAssertTrue(deletionButton.isEnabled, "Explicit password and DELETE confirmation should enable the final guarded action")
        app.navigationBars["Account Settings"].buttons["Close"].tap()

        let userPurchaseButton = app.buttons["hush.iap.open"]
        let resellerPurchaseButton = app.buttons["hush.iap.open-subscriptions"]
        if userPurchaseButton.waitForExistence(timeout: 4) {
            userPurchaseButton.tap()
        } else if resellerPurchaseButton.waitForExistence(timeout: 4) {
            resellerPurchaseButton.tap()
        } else {
            throw XCTSkip("A native-purchase entry point was not visible for this test account")
        }
        XCTAssertTrue(app.descendants(matching: .any)["hush.iap.sheet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["hush.iap.restore"].exists)
    }
}
