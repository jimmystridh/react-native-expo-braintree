import Foundation
import PassKit
import XCTest

@objcMembers final class ApplePayAmountsTests: XCTestCase {
    func testAuthorizedAmountsUseCurrencyMinorUnitsWithoutRounding() throws {
        for (currency, input, expected) in [
            ("USD", "5.00", "5.00"), ("USD", "12.1", "12.10"),
            ("JPY", "100", "100"), ("KWD", "4.005", "4.005"),
            ("HUF", "12.50", "12.50"), ("CLF", "1.2345", "1.2345"),
        ] {
            XCTAssertEqual(try formattedApplePayAmount(NSDecimalNumber(string: input), currencyCode: currency), expected)
        }
    }

    func testExcessCurrencyPrecisionIsRejectedBeforeCheckingWallet() {
        for (currency, value) in [("USD", "4.005"), ("JPY", "100.5"), ("KWD", "1.0001")] {
            let request = PKPaymentRequest()
            request.merchantIdentifier = "merchant.example"
            request.countryCode = "US"
            request.currencyCode = currency
            request.supportedNetworks = [.visa]
            request.paymentSummaryItems = [PKPaymentSummaryItem(label: "Merchant", amount: NSDecimalNumber(string: value))]
            var checkedWallet = false
            let error = applePayPaymentRequestError(request) { _, _ in checkedWallet = true; return true }
            XCTAssertEqual(error?["message"], ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue)
            XCTAssertTrue(error?["nativeError"]?.contains("paymentSummaryItems[0]") == true)
            XCTAssertFalse(checkedWallet)
        }
    }

    func testShippingAmountsHaveTheSameCurrencyPrecisionRules() {
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.example"
        request.countryCode = "US"
        request.currencyCode = "JPY"
        request.supportedNetworks = [.visa]
        request.paymentSummaryItems = [PKPaymentSummaryItem(label: "Merchant", amount: 100)]
        request.shippingMethods = [PKShippingMethod(label: "Shipping", amount: NSDecimalNumber(string: "0.5"))]
        let error = applePayPaymentRequestError(request) { _, _ in XCTFail("Checked Wallet"); return true }
        XCTAssertTrue(error?["nativeError"]?.contains("shippingMethods[0]") == true)
    }

    func testLargeShippingSelectionsDoNotPerformDecimalArithmetic() throws {
        let initial = [["label": "Merchant", "amount": "4.00"]]
        let huge = NSDecimalNumber.maximum.stringValue
        let methods: [[String: Any]] = [
            ["identifier": "free", "label": "Free", "amount": "0", "paymentSummaryItems": initial],
            ["identifier": "huge", "label": "Huge", "amount": huge, "paymentSummaryItems": [["label": "Merchant", "amount": huge]]],
        ]
        let options = try prepareApplePayRequestOptions(options: [
            "paymentSummaryItems": String(data: JSONSerialization.data(withJSONObject: initial), encoding: .utf8)!,
            "shippingMethods": String(data: JSONSerialization.data(withJSONObject: methods), encoding: .utf8)!,
        ])
        XCTAssertEqual(try options.summaryItems(for: options.shippingMethods[1]).last?.amount, NSDecimalNumber.maximum)
    }
}
