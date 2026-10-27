import Foundation
import PassKit
import XCTest

@objcMembers final class ApplePayRequestOptionsTests: XCTestCase {
    private func request(_ overrides: [String: String] = [:]) throws -> ApplePayRequestOptions {
        var values = ["paymentSummaryItems": "[{\"label\":\"Merchant\",\"amount\":\"4.00\"}]"]
        values.merge(overrides) { _, value in value }
        return try prepareApplePayRequestOptions(options: values)
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
            ("countryCode", ["", " ", "USA", "us", "ZZ", "U1"]),
            ("currencyCode", ["", " ", "US", "usd", "ZZZ", "U1D"]),
        ] {
            for code in codes {
                XCTAssertThrowsError(try request([field: code]), code) { error in
                    XCTAssertTrue(error.localizedDescription.contains(field))
                }
            }
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

    func testInvalidShippingMethodsAreRejectedInsteadOfChangingTheDefault() {
        for badMethod in [
            "{\"identifier\":\"\",\"label\":\"Invalid\",\"amount\":\"1.00\"}",
            "{\"identifier\":\"first\",\"label\":\" \",\"amount\":\"1.00\"}",
            "{\"identifier\":\"first\",\"label\":\"Invalid\",\"amount\":\"4.00abc\"}",
            "{\"identifier\":\"first\",\"label\":\"Invalid\",\"amount\":\"-3.00\"}",
            "null",
        ] {
            let methods = "[\(badMethod),{\"identifier\":\"second\",\"label\":\"Valid\",\"amount\":\"7.50\"}]"
            XCTAssertThrowsError(try request(["shippingMethods": methods])) { error in
                XCTAssertTrue(error.localizedDescription.contains("shippingMethods[0]"))
            }
        }
    }

    func testShippingOptionsThatCanInvalidateTheTotalAreRejectedBeforePresentation() {
        XCTAssertThrowsError(try request([
            "shippingMethods": "[{\"identifier\":\"standard\",\"label\":\"Standard\",\"amount\":\"4.00\"},{\"identifier\":\"free\",\"label\":\"Pickup\",\"amount\":\"0.00\"}]",
        ])) { error in
            XCTAssertTrue(error.localizedDescription.contains("shippingMethods[1]"))
        }
    }

    func testShippingSummaryIndexMustIdentifyTheInitialShippingAmount() throws {
        let base = [
            "paymentSummaryItems": "[{\"label\":\"Shipping\",\"amount\":\"2.10\"},{\"label\":\"Merchant\",\"amount\":\"12.10\"}]",
            "shippingMethods": "[{\"identifier\":\"standard\",\"label\":\"Standard\",\"amount\":\"2.10\"}]",
        ]
        for index in ["-1", "1", "2", "0.5", "null"] {
            var options = base
            options["shippingSummaryItemIndex"] = index
            XCTAssertThrowsError(try request(options), index)
        }
        var valid = base
        valid["shippingSummaryItemIndex"] = "0"
        XCTAssertEqual(try request(valid).shippingSummaryItemIndex, 0)
        valid["shippingMethods"] = "[]"
        XCTAssertThrowsError(try request(valid))
        valid["shippingMethods"] = "[{\"identifier\":\"standard\",\"label\":\"Standard\",\"amount\":\"1.00\"}]"
        XCTAssertThrowsError(try request(valid))
    }

    func testDuplicateShippingIdentifiersAreRejected() {
        let methods = "[{\"identifier\":\"same\",\"label\":\"First\",\"amount\":\"1.00\"},{\"identifier\":\"same\",\"label\":\"Second\",\"amount\":\"7.50\"}]"
        XCTAssertThrowsError(try request(["shippingMethods": methods]))
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
            let options = try request([
                "shippingMethods": "[{\"identifier\":\"standard\",\"label\":\"Shipping\",\"amount\":\"\(text)\"}]",
            ])
            let returnedMethod = PKShippingMethod(label: "Shipping", amount: options.shippingMethods[0].amount)
            returnedMethod.identifier = "standard"
            let payment = AuthorizedPayment()
            payment.selectedShippingMethod = returnedMethod

            let details = prepareApplePayPaymentDetails(payment, shippingMethodAmounts: options.shippingMethodAmounts)
            XCTAssertEqual((details["shippingMethod"] as? [String: String])?["amount"], text)
        }
    }

    func testCardNetworkNamesMatchTheSupportedNetworkInputs() {
        for name in ["amex", "cartesBancaires", "chinaUnionPay", "discover", "eftpos", "electron", "elo", "idCredit", "interac", "jcb", "mada", "maestro", "masterCard", "privateLabel", "quicPay", "suica", "visa"] {
            XCTAssertEqual(applePayNetworkName(applePayNetwork(named: name)), name)
        }
        XCTAssertEqual(applePayNetworkName(.amex), "amex")
        XCTAssertEqual(applePayNetworkName(.masterCard), "masterCard")
        XCTAssertNil(applePayNetworkName(nil))
        XCTAssertNil(applePayNetworkName(PKPaymentNetwork(rawValue: "")))
    }
}
