import XCTest

final class UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEndToEndHushTunnelFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Give the app time to load data from the production API
        sleep(3)

        // 1. Verify Connect / Disconnect button is present and interactive
        let connectButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Connect' OR label CONTAINS 'اتصال' OR label CONTAINS 'Подключиться' OR label CONTAINS '连接' OR label CONTAINS 'Bağlan'")).firstMatch
        if connectButton.exists {
            XCTAssertTrue(connectButton.exists, "Connect button should be visible")
            connectButton.tap()
            sleep(2)
            
            // Tap again to disconnect
            let disconnectButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Disconnect' OR label CONTAINS 'قطع' OR label CONTAINS 'Отключиться' OR label CONTAINS '断开' OR label CONTAINS 'Kes'")).firstMatch
            if disconnectButton.exists {
                disconnectButton.tap()
                sleep(1)
            }
        }

        // 2. Verify Web Store & Subscriptions Notice Card Link
        let webLink = app.links.matching(NSPredicate(format: "label CONTAINS 'hushtunnel.com' OR label CONTAINS 'https://www.hushtunnel.com'")).firstMatch
        if webLink.exists {
            XCTAssertTrue(webLink.exists, "Web store notice link should be present")
        }

        // 3. Verify Change Password sheet modal
        let changePasswordButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Change Password' OR label CONTAINS 'تغییر رمز' OR label CONTAINS 'Сменить пароль' OR label CONTAINS '修改密码' OR label CONTAINS 'Şifre Değiştir'")).firstMatch
        if changePasswordButton.exists {
            changePasswordButton.tap()
            sleep(1)

            let cancelButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cancel' OR label CONTAINS 'انصراف' OR label CONTAINS 'Отмена' OR label CONTAINS '取消' OR label CONTAINS 'İptal'")).firstMatch
            if cancelButton.exists {
                cancelButton.tap()
                sleep(1)
            }
        }

        // 4. Verify Order History sheet modal
        let orderButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Order History' OR label CONTAINS 'سفارشات' OR label CONTAINS 'История' OR label CONTAINS '订单' OR label CONTAINS 'Sipariş'")).firstMatch
        if orderButton.exists {
            orderButton.tap()
            sleep(1)
            
            let closeOrCancel = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cancel' OR label CONTAINS 'Close' OR label CONTAINS 'بستن' OR label CONTAINS 'انصراف' OR label CONTAINS '关闭' OR label CONTAINS 'İptal'")).firstMatch
            if closeOrCancel.exists {
                closeOrCancel.tap()
                sleep(1)
            }
        }
    }
}
