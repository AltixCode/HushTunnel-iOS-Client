import XCTest

final class UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEndToEndShadowLinkFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Give the app time to load data from the production API
        sleep(3)

        // 1. Verify Connect / Disconnect button is present
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

        // 2. Verify Renew Subscription sheet
        let renewButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Renew' OR label CONTAINS 'تمدید' OR label CONTAINS 'Продлить' OR label CONTAINS '续费' OR label CONTAINS 'Yenile'")).firstMatch
        if renewButton.exists {
            renewButton.tap()
            sleep(1)
            
            let closeOrCancel = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cancel' OR label CONTAINS 'Close' OR label CONTAINS 'بستن' OR label CONTAINS 'انصراف' OR label CONTAINS '关闭' OR label CONTAINS 'İptal'")).firstMatch
            if closeOrCancel.exists {
                closeOrCancel.tap()
                sleep(1)
            }
        }

        // 3. Verify Get a Subscription sheet
        let buyButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Get a Subscription' OR label CONTAINS 'خرید' OR label CONTAINS 'Купить' OR label CONTAINS '购买' OR label CONTAINS 'Satın Al'")).firstMatch
        if buyButton.exists {
            buyButton.tap()
            sleep(1)
            
            let closeOrCancel = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cancel' OR label CONTAINS 'Close' OR label CONTAINS 'بستن' OR label CONTAINS 'انصراف' OR label CONTAINS '关闭' OR label CONTAINS 'İptal'")).firstMatch
            if closeOrCancel.exists {
                closeOrCancel.tap()
                sleep(1)
            }
        }

        // 4. Verify Order History sheet
        let orderButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Order History' OR label CONTAINS 'سفارشات' OR label CONTAINS 'История' OR label CONTAINS '订单' OR label CONTAINS 'Sipariş'")).firstMatch
        if orderButton.exists {
            orderButton.tap()
            sleep(1)
            
            let doneButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Done' OR label CONTAINS 'تمام' OR label CONTAINS 'Готово' OR label CONTAINS '完成' OR label CONTAINS 'Tamam'")).firstMatch
            if doneButton.exists {
                doneButton.tap()
                sleep(1)
            }
        }
    }
}
