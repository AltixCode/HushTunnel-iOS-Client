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
        connectionDetails.buttons["Done"].tap()
    }
}
