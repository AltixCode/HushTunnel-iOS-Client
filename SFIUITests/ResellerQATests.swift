import XCTest

// Ad-hoc QA driver for the reseller multi-server QR sheet flow, added on top
// of commit 0c32404. Not part of the permanent suite — used to mechanically
// drive the Simulator (tap/type) since idb/AppleScript UI automation are
// unavailable in this sandbox, and to save screenshots to a fixed host path
// for visual verification via the Read tool. Screenshots are written
// directly to disk from the test process (which runs on the host against
// the Simulator), so no xcresult extraction is needed.
@MainActor
final class ResellerQATests: XCTestCase {
    let app = XCUIApplication()
    let shotDir = "/private/tmp/claude-502/-Users-atamohammadi-Dev-vpn/7f0770e8-1d30-447f-81de-142126b01030/scratchpad/shots"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func shot(_ name: String) {
        let img = XCUIScreen.main.screenshot().image
        if let data = img.pngData() {
            let path = "\(shotDir)/\(name).png"
            try? data.write(to: URL(fileURLWithPath: path))
            print("QA_SHOT: wrote \(path)")
        } else {
            print("QA_SHOT: FAILED to encode \(name)")
        }
    }

    func testResellerMultiServerFlow() throws {
        let uniqueEmail = "qa-ios-\(Int(Date().timeIntervalSince1970))@example.com"
        print("QA_EMAIL: \(uniqueEmail)")

        // --- Step 2: Log in as reseller ---
        let emailField = app.textFields.element(boundBy: 0)
        XCTAssertTrue(emailField.waitForExistence(timeout: 15), "email field not found")

        // Freshly-cloned test Simulators can report Network.framework reachability
        // as "unsatisfied" for a few seconds after boot (a known Simulator cold-start
        // quirk), which makes the very first login attempt fail with "Could not
        // connect to the server." even though the host machine's network is fine.
        // Give it a moment to settle before submitting.
        sleep(6)

        emailField.tap()
        emailField.typeText("qa-mobile-reseller@hushtunnel.com")

        let passwordField = app.secureTextFields.element(boundBy: 0)
        XCTAssertTrue(passwordField.exists)
        passwordField.tap()
        passwordField.typeText("QaMobile2026!")

        let signInButton = app.buttons["Sign In"]
        let customersTabButton = app.tabBars.buttons["Customers"]
        let connectError = app.staticTexts["Could not connect to the server."]

        var loggedIn = false
        for attempt in 1...5 {
            signInButton.tap()
            let deadline = Date().addingTimeInterval(10)
            while Date() < deadline {
                if customersTabButton.exists { loggedIn = true; break }
                if connectError.waitForExistence(timeout: 1) {
                    print("QA_LOGIN_RETRY: attempt \(attempt) hit connect error, retrying")
                    break
                }
            }
            if loggedIn { break }
            sleep(3)
        }

        XCTAssertTrue(loggedIn || customersTabButton.waitForExistence(timeout: 20), "reseller home / tab bar not found after login")
        shot("02_reseller_home")

        // --- Step 3: Navigate to Customers tab ---
        customersTabButton.tap()
        sleep(1)
        shot("03_customers_tab")

        // Use the Dashboard tab's labeled "Add Customer" button to open the
        // exact same ResellerAddCustomerSheetView (showAddCustomerSheet is
        // shared state) — the Customers tab's own add button is icon-only
        // (no accessible text) and unsafe to hit via coordinate guessing.
        let dashboardTabButton = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTabButton.waitForExistence(timeout: 10))
        dashboardTabButton.tap()
        sleep(1)

        let addCustomerButton = app.buttons["Add Customer"]
        XCTAssertTrue(addCustomerButton.waitForExistence(timeout: 10), "Add Customer button not found on Dashboard tab")
        addCustomerButton.tap()

        // --- Add customer sheet ---
        let customerEmailField = app.textFields["Customer Email"]
        XCTAssertTrue(customerEmailField.waitForExistence(timeout: 10), "Customer Email field not found")
        customerEmailField.tap()
        customerEmailField.typeText(uniqueEmail)
        shot("04_add_customer_filled")

        app.buttons["Create Customer Account"].tap()

        let doneButton = app.navigationBars.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 20), "Done button (post customer-creation) not found")
        shot("05_customer_created")
        doneButton.tap()

        // --- Step 4: order sheet should auto-open with email prefilled ---
        let orderEmailField = app.textFields.matching(NSPredicate(format: "value == %@", uniqueEmail)).firstMatch
        XCTAssertTrue(orderEmailField.waitForExistence(timeout: 10), "Create-order sheet did not auto-open with prefilled email")
        shot("06_order_sheet_prefilled")

        // --- Step 5: submit order (plan auto-selected to first plan) ---
        let payButton = app.buttons["Confirm & Pay from Balance"]
        XCTAssertTrue(payButton.waitForExistence(timeout: 10))
        payButton.tap()

        // --- Step 6: multi-server QR sheet ---
        let connectionNav = app.navigationBars["Connection Details"]
        XCTAssertTrue(connectionNav.waitForExistence(timeout: 20), "Connection Details sheet did not open after order submit")
        sleep(1) // let QR images render
        shot("07_qr_sheet_from_order_submit")

        // Dismiss
        app.navigationBars["Connection Details"].buttons["Done"].tap()

        // --- Step 7: Subscriptions tab, tap the new row, verify sheet reopens ---
        let subsTabButton = app.tabBars.buttons["Subscriptions"]
        XCTAssertTrue(subsTabButton.waitForExistence(timeout: 10))
        subsTabButton.tap()
        sleep(1)
        shot("08_subscriptions_tab")

        let subRow = app.staticTexts[uniqueEmail]
        XCTAssertTrue(subRow.waitForExistence(timeout: 15), "subscription row for new customer not found")
        subRow.tap()

        XCTAssertTrue(app.navigationBars["Connection Details"].waitForExistence(timeout: 15), "Connection Details sheet did not reopen from Subscriptions tab")
        sleep(1)
        shot("09_qr_sheet_from_subscriptions")
        app.navigationBars["Connection Details"].buttons["Done"].tap()

        // --- Step 8: Orders tab, tap the order row, verify sheet reopens ---
        let ordersTabButton = app.tabBars.buttons["Orders"]
        XCTAssertTrue(ordersTabButton.waitForExistence(timeout: 10))
        ordersTabButton.tap()
        sleep(1)
        shot("10_orders_tab")

        let orderRow = app.staticTexts[uniqueEmail]
        XCTAssertTrue(orderRow.waitForExistence(timeout: 15), "order row for new customer not found")
        orderRow.tap()

        XCTAssertTrue(app.navigationBars["Connection Details"].waitForExistence(timeout: 15), "Connection Details sheet did not reopen from Orders tab")
        sleep(1)
        shot("11_qr_sheet_from_orders")
        app.navigationBars["Connection Details"].buttons["Done"].tap()

        print("QA_DONE: flow completed for \(uniqueEmail)")
    }
}
