import XCTest

@MainActor
final class ConnectionReliabilityTests: XCTestCase {
    func testSelectedServerConnectionAndDiagnostic() throws {
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
                XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
                // A direct .tap() (not a coordinate tap) reliably gives the
                // field keyboard focus; coordinate taps occasionally land
                // before the keyboard/responder chain settles right after
                // the email field's own typeText, causing
                // "Neither element nor any descendant has keyboard focus".
                passwordField.tap()
                let hasFocus = NSPredicate(format: "hasKeyboardFocus == true")
                expectation(for: hasFocus, evaluatedWith: passwordField)
                waitForExpectations(timeout: 5)
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

        let testButton = app.buttons["hush.connection-test"]
        XCTAssertTrue(testButton.waitForExistence(timeout: 3))

        let wasConnected = testButton.isEnabled
        if !wasConnected {
            let connectReady = NSPredicate(format: "enabled == true")
            expectation(for: connectReady, evaluatedWith: connectButton)
            waitForExpectations(timeout: 25)
            connectButton.tap()
            let enabled = NSPredicate(format: "enabled == true")
            expectation(for: enabled, evaluatedWith: testButton)
            waitForExpectations(timeout: 30)
        }

        testButton.tap()
        let success = app.descendants(matching: .any)["hush.connection-test-result.success"]
        XCTAssertTrue(success.waitForExistence(timeout: 20), "Diagnostic should verify the selected server's tunnel IP")

        if !wasConnected {
            connectButton.tap()
        }
    }
}
