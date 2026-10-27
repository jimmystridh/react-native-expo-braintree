import Foundation
import PassKit
import XCTest

@objcMembers final class ApplePayRequestOptionsTests: XCTestCase {
    private func request(_ overrides: [String: String] = [:]) throws -> ApplePayRequestOptions {
        var values = ["paymentSummaryItems": "[{\"label\":\"Merchant\",\"amount\":\"4.00\"}]"]
        values.merge(overrides) { _, value in value }
        return try prepareApplePayRequestOptions(options: values)
    }

    private func method(_ identifier: String, amount: String = "1.00", total: String = "4.00") -> [String: Any] {
        ["identifier": identifier, "label": identifier, "amount": amount, "paymentSummaryItems": [["label": "Merchant", "amount": total]]]
    }

    private func json(_ value: Any) throws -> String {
        String(data: try JSONSerialization.data(withJSONObject: value), encoding: .utf8)!
    }

    func testApplicationDataAlwaysUsesTheOriginalUTF8Bytes() throws {
        for text in ["order123", "test", "SGVsbG8=", "påse", ""] {
            XCTAssertEqual(try request(["applicationData": text]).applicationData, Data(text.utf8))
        }
        XCTAssertNil(try request().applicationData)
    }

    func testMerchantCapabilitiesAlwaysRetainThreeDSecure() throws {
        for capabilities in ["[]", "[\"debit\"]", "[\"credit\"]", "[\"emv\"]", "[\"credit\",\"debit\"]"] {
            let options = try request(["merchantCapabilities": capabilities])
            XCTAssertTrue(options.merchantCapabilities.contains(.threeDSecure), capabilities)
        }
        XCTAssertTrue(try request(["merchantCapabilities": "[\"debit\"]"]).merchantCapabilities.contains(.debit))
    }

    func testUnknownOptionValuesAreRejectedWithTheirField() {
        for (field, value, position) in [
            ("merchantCapabilities", "[\"debitCard\"]", "merchantCapabilities[0]"),
            ("requiredBillingContactFields", "[\"emailAddress\"]", "requiredBillingContactFields[0]"),
            ("requiredShippingContactFields", "[\"phoneNumber\"]", "requiredShippingContactFields[0]"),
            ("supportedNetworks", "[\"not-a-network\"]", "supportedNetworks[0]"),
            ("shippingType", "teleport", "shippingType"),
        ] {
            XCTAssertThrowsError(try request([field: value])) { error in
                XCTAssertTrue(error.localizedDescription.contains(position))
            }
        }
    }

    func testKnownContactFieldsCapabilitiesAndShippingTypesAreAccepted() throws {
        let options = try request([
            "merchantCapabilities": "[\"3ds\",\"credit\",\"debit\",\"emv\"]",
            "requiredShippingContactFields": "[\"email\",\"name\",\"phone\",\"postalAddress\",\"phoneticName\"]",
            "shippingType": "storePickup",
            "supportedNetworks": "[\"girocard\"]",
        ])
        XCTAssertEqual(options.requiredShippingContactFields, [.emailAddress, .name, .phoneNumber, .postalAddress, .phoneticName])
        XCTAssertTrue(options.merchantCapabilities.contains([.threeDSecure, .credit, .debit, .emv]))
        XCTAssertEqual(options.shippingType, .storePickup)
        XCTAssertEqual(options.supportedNetworks, [.girocard])
    }

    func testInvalidExplicitCountryAndCurrencyCodesAreRejected() {
        for (field, codes) in [
            ("countryCode", ["USA", "us", "ZZ", "U1"]),
            ("currencyCode", ["US", "usd", "ZZZ", "U1D"]),
        ] {
            for code in codes {
                XCTAssertThrowsError(try request([field: code]), code) { error in
                    XCTAssertTrue(error.localizedDescription.contains(field))
                }
            }
        }
    }

    func testBlankOverridesConsistentlyUseGatewayDefaults() throws {
        for value in ["", " ", "\t\n"] {
            let options = try request(["merchantIdentifier": value, "countryCode": value, "currencyCode": value])
            XCTAssertNil(options.merchantIdentifier)
            XCTAssertNil(options.countryCode)
            XCTAssertNil(options.currencyCode)
        }
    }

    func testMalformedAndNonpositiveTotalsAreRejected() {
        for amount in ["1,299.00", "4.00abc", "-3.00", "0", "0.00", "+4.00", "1e2", "NaN", "Infinity", " 4.00", "4.00\n", ".50", "4.", "12345678901234567890123456789012345678901234567890123456789.00"] {
            let items: [[String: Any]] = [["label": "Merchant", "amount": amount]]
            let json = String(data: try! JSONSerialization.data(withJSONObject: items), encoding: .utf8)!
            XCTAssertThrowsError(try request(["paymentSummaryItems": json]), amount)
        }
    }

    func testStrictDecimalsAndDiscountLineItemsAreAccepted() throws {
        let options = try request([
            "paymentSummaryItems": "[{\"label\":\"Discount\",\"amount\":\"-3.00\"},{\"label\":\"Merchant\",\"amount\":\"7.50\"}]",
        ])
        XCTAssertEqual(options.paymentSummaryItems[0].amount, NSDecimalNumber(string: "-3.00"))
        XCTAssertEqual(options.paymentSummaryItems[1].amount, NSDecimalNumber(string: "7.50"))
    }

    func testInvalidShippingMethodsAreRejectedInsteadOfChangingTheDefault() throws {
        for (field, value) in [("identifier", ""), ("label", " "), ("amount", "4.00abc"), ("amount", "-3.00")] {
            var invalid = method("first")
            invalid[field] = value
            XCTAssertThrowsError(try request(["shippingMethods": json([invalid, method("second")])])) { error in
                XCTAssertTrue(error.localizedDescription.contains("shippingMethods[0]"))
            }
        }
        XCTAssertThrowsError(try request(["shippingMethods": json([NSNull(), method("second")])]))
    }

    func testEveryShippingChoiceNeedsAPositiveCompleteSummary() throws {
        for total in ["0.00", "-1.00"] {
            XCTAssertThrowsError(try request(["shippingMethods": json([method("first"), method("second", total: total)])])) { error in
                XCTAssertTrue(error.localizedDescription.contains("shippingMethods[1].paymentSummaryItems"))
            }
        }
        var incomplete = method("first")
        incomplete.removeValue(forKey: "paymentSummaryItems")
        XCTAssertThrowsError(try request(["shippingMethods": json([incomplete])]))
    }

    func testInitialSummaryMustMatchTheFirstShippingMethod() throws {
        XCTAssertThrowsError(try request(["shippingMethods": json([method("first", total: "5.00")])])) { error in
            XCTAssertTrue(error.localizedDescription.contains("must match the first shipping method"))
        }
    }

    func testGatewayCurrencyAlsoValidatesEveryShippingSummary() throws {
        let options = try request(["shippingMethods": json([method("first"), method("second", total: "4.005")])])
        XCTAssertThrowsError(try options.validateAmounts(currencyCode: "USD")) { error in
            XCTAssertTrue(error.localizedDescription.contains("shippingMethods[1].paymentSummaryItems[0]"))
        }
    }

    func testObsoleteShippingIndexIsRejectedWithMigrationInstructions() throws {
        XCTAssertThrowsError(try request(["shippingSummaryItemIndex": "0"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("supply paymentSummaryItems for each shipping method"))
        }
    }

    func testDuplicateShippingIdentifiersAreRejected() throws {
        XCTAssertThrowsError(try request(["shippingMethods": json([method("same"), method("same")])])) { error in
            XCTAssertTrue(error.localizedDescription.contains("shippingMethods[1]"))
        }
    }

    func testBadStringArrayElementsReportTheirPosition() {
        for (field, value) in [
            ("supportedNetworks", "[\"visa\",null]"),
            ("merchantCapabilities", "[\"debit\",null]"),
            ("requiredBillingContactFields", "[\"name\",null]"),
            ("requiredShippingContactFields", "[\"email\",null]"),
        ] {
            XCTAssertThrowsError(try request([field: value])) { error in
                XCTAssertTrue(error.localizedDescription.contains("\(field)[1]"))
            }
        }
    }

    func testBadSummaryElementIsNotReportedAsAnEmptyList() {
        let items = "[{\"label\":\"Merchant\",\"amount\":\"4.00\"},null]"
        XCTAssertThrowsError(try request(["paymentSummaryItems": items])) { error in
            XCTAssertTrue(error.localizedDescription.contains("paymentSummaryItems[1]"))
        }
    }

    func testMalformedJSONAndWrongArrayShapesAreRejected() {
        for field in ["paymentSummaryItems", "shippingMethods", "supportedNetworks", "merchantCapabilities"] {
            for value in ["not-json", "{}", "null"] {
                XCTAssertThrowsError(try request([field: value]), "\(field): \(value)")
            }
        }
    }

    func testShippingAmountFormattingSurvivesPassKitCopies() throws {
        for text in ["7.50", "0.00", "07.500"] {
            let options = try request(["shippingMethods": json([method("standard", amount: text)])])
            let returnedMethod = PKShippingMethod(label: "Shipping", amount: options.shippingMethods[0].amount)
            returnedMethod.identifier = "standard"
            let payment = AuthorizedPayment()
            payment.selectedShippingMethod = returnedMethod

            let details = try prepareApplePayPaymentDetails(payment, shippingMethodAmounts: options.shippingMethodAmounts)
            XCTAssertEqual((details["shippingMethod"] as? [String: String])?["amount"], text)
        }
    }

    func testCardNetworkNamesMatchExistingCardTokenization() {
        for (input, output) in [
            ("visa", "Visa"), ("masterCard", "MasterCard"), ("amex", "Amex"),
            ("jcb", "JCB"), ("maestro", "Maestro"), ("discover", "Discover"),
            ("chinaUnionPay", "UnionPay"), ("girocard", PKPaymentNetwork.girocard.rawValue),
        ] {
            XCTAssertEqual(applePayNetworkName(applePayNetwork(named: input)), output)
        }
        XCTAssertNil(applePayNetwork(named: "not-a-network"))
        XCTAssertNil(applePayNetworkName(nil))
        XCTAssertNil(applePayNetworkName(PKPaymentNetwork(rawValue: "")))
    }
}
