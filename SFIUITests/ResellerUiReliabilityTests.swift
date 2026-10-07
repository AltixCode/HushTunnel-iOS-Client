import XCTest

@MainActor
final class ResellerUiReliabilityTests: XCTestCase {
    func testRuntimeDirectionDetailsAndQrPresentation() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-app_language", "en"]
        app.launch()

        let customersTab = app.tabBars.buttons["Customers"]
        guard customersTab.waitForExistence(timeout: 8) else {
            throw XCTSkip("An authenticated reseller account is required")
        }

        let languageButton = app.buttons["hush.language-picker"]
        XCTAssertTrue(languageButton.waitForExistence(timeout: 3))
        languageButton.tap()
        XCTAssertTrue(app.buttons["فارسی (Persian)"].waitForExistence(timeout: 3))
        app.buttons["فارسی (Persian)"].tap()
        XCTAssertTrue(app.tabBars.buttons["مشتریان"].waitForExistence(timeout: 5))

        languageButton.tap()
        XCTAssertTrue(app.buttons["English"].waitForExistence(timeout: 3))
        app.buttons["English"].tap()
        XCTAssertTrue(customersTab.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Subscriptions"].exists)

        app.tabBars.buttons["Dashboard"].tap()
        app.buttons["New Order for Customer"].tap()
        XCTAssertTrue(app.textFields["hush.reseller.order-customer-search"].waitForExistence(timeout: 5))
        app.navigationBars["Buy Plan for Customer"].buttons["Cancel"].tap()

        customersTab.tap()
        let customerRow = app.buttons["hush.reseller.customer-row"].firstMatch
        guard customerRow.waitForExistence(timeout: 5) else {
            throw XCTSkip("The reseller test account has no customers")
        }
        customerRow.tap()
        let customerDetails = app.navigationBars["Customer Details"]
        XCTAssertTrue(customerDetails.waitForExistence(timeout: 8))
        customerDetails.buttons["Done"].tap()

        app.tabBars.buttons["Subscriptions"].tap()
        let subscriptionRow = app.buttons["hush.reseller.subscription-row"].firstMatch
        guard subscriptionRow.waitForExistence(timeout: 5) else {
            throw XCTSkip("The reseller test account has no subscriptions")
        }
        subscriptionRow.tap()
        let connectionDetails = app.navigationBars["Connection Details"]
        XCTAssertTrue(connectionDetails.waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.descendants(matching: .any)["hush.reseller.sub-qr-code"].firstMatch.waitForExistence(timeout: 8),
            "A subscription must render its subscription URL QR code instead of an empty white card"
        )

        // Regression coverage for the manage-subscription actions: they used to
        // sit as small buttons directly on the list row, right next to the
        // row's own tap target, which made it easy to misclick "Revoke" while
        // meaning to open this sheet. They now only live here, below the QR
        // code, each with its own description. Tapping the row itself (above)
        // must never surface a destructive confirmation on its own — only
        // explicitly tapping "Revoke" below should.
        XCTAssertTrue(app.staticTexts["Manage Subscription"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Extend Days"].exists)
        XCTAssertTrue(app.buttons["Disable"].exists || app.buttons["Enable"].exists)
        XCTAssertTrue(app.buttons["Reset UUID"].exists)
        let revokeButton = app.buttons["Revoke"]
        XCTAssertTrue(revokeButton.exists)

        revokeButton.tap()
        let revokeAlert = app.alerts["Revoke subscription?"]
        XCTAssertTrue(revokeAlert.waitForExistence(timeout: 3), "Revoke must ask for confirmation before it fires")
        revokeAlert.buttons["Cancel"].tap()

        connectionDetails.buttons["Done"].tap()
    }
}
