import Contacts
import Foundation
import PassKit
import XCTest

final class AuthorizedPayment: PKPayment {
    var selectedBillingContact: PKContact?
    var selectedShippingContact: PKContact?
    var selectedShippingMethod: PKShippingMethod?

    override var billingContact: PKContact? { selectedBillingContact }
    override var shippingContact: PKContact? { selectedShippingContact }
    override var shippingMethod: PKShippingMethod? { selectedShippingMethod }
}

@objcMembers final class ApplePayPaymentDetailsTests: XCTestCase {
    private func shippingMethod(_ identifier: String, amount: String) -> PKShippingMethod {
        let method = PKShippingMethod(label: identifier, amount: NSDecimalNumber(string: amount))
        method.identifier = identifier
        return method
    }

    private func shippingOptions() throws -> ApplePayRequestOptions {
        let initial = [["label": "Goods", "amount": "10.00"], ["label": "Shipping", "amount": "2.10"], ["label": "Merchant", "amount": "12.10"]]
        let express = [["label": "Goods", "amount": "10.00"], ["label": "Postage", "amount": "7.25"], ["label": "Merchant", "amount": "17.25"]]
        let methods: [[String: Any]] = [
            ["identifier": "standard", "label": "Standard", "amount": "2.10", "paymentSummaryItems": initial],
            ["identifier": "express", "label": "Express", "amount": "7.25", "paymentSummaryItems": express],
        ]
        return try prepareApplePayRequestOptions(options: [
            "paymentSummaryItems": String(data: JSONSerialization.data(withJSONObject: initial), encoding: .utf8)!,
            "shippingMethods": String(data: JSONSerialization.data(withJSONObject: methods), encoding: .utf8)!,
        ])
    }

    func testShippingSelectionUsesCompleteSummariesWithoutAccumulatingCharges() throws {
        let options = try shippingOptions()
        for (index, expected) in [(1, "17.25"), (1, "17.25"), (0, "12.10")] {
            let selected = try options.summaryItems(for: options.shippingMethods[index])
            XCTAssertEqual(selected.last?.amount, NSDecimalNumber(string: expected))
            XCTAssertEqual(selected[1].label, index == 0 ? "Shipping" : "Postage")
        }
        XCTAssertEqual(options.paymentSummaryItems.last?.amount, NSDecimalNumber(string: "12.10"))
    }

    func testUnknownShippingSelectionIsRejected() throws {
        XCTAssertThrowsError(try shippingOptions().summaryItems(for: shippingMethod("unknown", amount: "0.00")))
    }

    func testAuthorizedTotalUsesTheFinalShippingSelectionAndCurrency() throws {
        let options = try shippingOptions()
        let items = try options.summaryItems(for: options.shippingMethods[1])
        let details = try prepareApplePayPaymentDetails(AuthorizedPayment(), authorizedTotal: items.last, currencyCode: "USD")
        XCTAssertEqual(details["authorizedTotal"] as? [String: String], ["amount": "17.25", "currencyCode": "USD"])
    }

    func testAuthorizedPaymentDetailsSerializeAllContactFields() throws {
        let contact = PKContact()
        contact.emailAddress = "ada@example.com"
        contact.phoneNumber = CNPhoneNumber(stringValue: "+44 20 1234 5678")
        var name = PersonNameComponents()
        name.givenName = "Ada"
        name.familyName = "Lovelace"
        var phoneticName = PersonNameComponents()
        phoneticName.givenName = "Ay-duh"
        phoneticName.familyName = "Luv-lays"
        name.phoneticRepresentation = phoneticName
        contact.name = name
        let address = CNMutablePostalAddress()
        address.street = "2 Shipping Street\nFlat 3"
        address.city = "London"
        address.state = "London"
        address.postalCode = "SW1A 1AA"
        address.country = "United Kingdom"
        address.isoCountryCode = "GB"
        address.subAdministrativeArea = "Westminster"
        address.subLocality = "St James’s"
        contact.postalAddress = address
        let method = shippingMethod("Express", amount: "7.25")
        method.detail = "Next day"
        let payment = AuthorizedPayment()
        payment.selectedBillingContact = PKContact()
        payment.selectedShippingContact = contact
        payment.selectedShippingMethod = method

        let details = try prepareApplePayPaymentDetails(payment)
        let encoded = try JSONSerialization.data(withJSONObject: details)
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let serializedContact = try XCTUnwrap(decoded["shippingContact"] as? [String: Any])
        XCTAssertEqual(serializedContact["emailAddress"] as? String, contact.emailAddress)
        XCTAssertEqual(serializedContact["phoneNumber"] as? String, contact.phoneNumber?.stringValue)
        XCTAssertEqual(serializedContact["givenName"] as? String, "Ada")
        XCTAssertEqual(serializedContact["familyName"] as? String, "Lovelace")
        XCTAssertEqual(serializedContact["phoneticGivenName"] as? String, "Ay-duh")
        XCTAssertEqual(serializedContact["phoneticFamilyName"] as? String, "Luv-lays")
        XCTAssertEqual(serializedContact["postalAddress"] as? [String: String], [
            "street": address.street, "city": address.city, "state": address.state,
            "postalCode": address.postalCode, "country": address.country,
            "countryCode": address.isoCountryCode, "subAdministrativeArea": address.subAdministrativeArea,
            "subLocality": address.subLocality,
        ])
        XCTAssertEqual(decoded["billingContact"] as? [String: String], [:])
        XCTAssertEqual(decoded["shippingMethod"] as? [String: String], [
            "identifier": "Express", "label": "Express", "amount": "7.25", "type": "final", "detail": "Next day",
        ])
    }

    func testAuthorizationFailuresUseThePassKitErrorDomain() {
        let result = applePayAuthorizationFailure()
        XCTAssertEqual(result.status, .failure)
        XCTAssertEqual((result.errors?.first as NSError?)?.domain, PKPaymentErrorDomain)
        XCTAssertEqual((result.errors?.first as NSError?)?.code, PKPaymentError.Code.unknownError.rawValue)
    }

    func testAbsentDetailsAreOmittedAndPendingShippingAmountRemainsAString() throws {
        let payment = AuthorizedPayment()
        XCTAssertTrue(try prepareApplePayPaymentDetails(payment).isEmpty)

        let method = PKShippingMethod(label: "Pending", amount: NSDecimalNumber.zero, type: .pending)
        method.identifier = "pending"
        payment.selectedShippingMethod = method
        let details = try prepareApplePayPaymentDetails(payment)
        XCTAssertNil(details["billingContact"])
        XCTAssertNil(details["shippingContact"])
        XCTAssertEqual(details["shippingMethod"] as? [String: String], [
            "identifier": "pending", "label": "Pending", "amount": "0", "type": "pending",
        ])
    }
}

@objcMembers final class ApplePayValidationTests: XCTestCase {
    private func paymentRequest() -> PKPaymentRequest {
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.example"
        request.supportedNetworks = [.visa, .masterCard]
        request.merchantCapabilities = [.threeDSecure, .debit]
        request.countryCode = "US"
        request.currencyCode = "USD"
        request.paymentSummaryItems = [PKPaymentSummaryItem(label: "Merchant", amount: 10)]
        return request
    }

    func testMissingNetworksAreAConfigurationErrorBeforeCheckingWallet() {
        let request = paymentRequest()
        request.supportedNetworks = []
        var didCheckWallet = false

        let error = applePayPaymentRequestError(request) { _, _ in
            didCheckWallet = true
            return false
        }

        XCTAssertEqual(error?["message"], ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue)
        XCTAssertTrue(error?["nativeError"]?.contains("supportedNetworks") == true)
        XCTAssertFalse(didCheckWallet)
    }

    func testMissingMerchantIsAConfigurationErrorBeforeCheckingWallet() {
        let request = paymentRequest()
        request.merchantIdentifier = ""
        var didCheckWallet = false

        let error = applePayPaymentRequestError(request) { _, _ in
            didCheckWallet = true
            return false
        }

        XCTAssertEqual(error?["message"], ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue)
        XCTAssertFalse(didCheckWallet)
    }

    func testInvalidGatewayRegionCodesAreRejectedBeforeCheckingWallet() {
        for (field, codes) in [
            ("countryCode", ["", "USA", "us", "ZZ", " US "]),
            ("currencyCode", ["", "US", "usd", "ZZZ", " USD "]),
        ] {
            for code in codes {
                let request = paymentRequest()
                if field == "countryCode" { request.countryCode = code }
                else { request.currencyCode = code }
                var checkedWallet = false
                let error = applePayPaymentRequestError(request) { _, _ in
                    checkedWallet = true
                    return true
                }
                XCTAssertEqual(error?["message"], ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue)
                XCTAssertTrue(error?["nativeError"]?.contains(field) == true)
                XCTAssertFalse(checkedWallet)
            }
        }
    }

    func testWalletCheckIncludesNetworksAndMerchantCapabilities() {
        let request = paymentRequest()
        var checkedNetworks: [PKPaymentNetwork] = []
        var checkedCapabilities: PKMerchantCapability = []

        let error = applePayPaymentRequestError(request) { networks, capabilities in
            checkedNetworks = networks
            checkedCapabilities = capabilities
            return true
        }

        XCTAssertNil(error)
        XCTAssertEqual(checkedNetworks, request.supportedNetworks)
        XCTAssertEqual(checkedCapabilities, request.merchantCapabilities)
    }

    func testNoMatchingCardIsAnAvailabilityError() {
        let request = paymentRequest()

        let error = applePayPaymentRequestError(request) { _, _ in false }

        XCTAssertEqual(error?["message"], ERROR_TYPES.APPLE_PAY_NOT_AVAILABLE_ERROR.rawValue)
        XCTAssertTrue(error?["nativeError"]?.contains("merchant capabilities") == true)
    }
}

let suite = XCTestSuite(name: "Apple Pay")
suite.addTest(XCTestSuite(forTestCaseClass: ApplePayPaymentDetailsTests.self))
suite.addTest(XCTestSuite(forTestCaseClass: ApplePayValidationTests.self))
suite.addTest(XCTestSuite(forTestCaseClass: ApplePayRequestOptionsTests.self))
suite.addTest(XCTestSuite(forTestCaseClass: ApplePayResultHandlerTests.self))
suite.addTest(XCTestSuite(forTestCaseClass: ApplePayAmountsTests.self))
suite.addTest(XCTestSuite(forTestCaseClass: ApplePayGatewayFailureTests.self))
suite.run()
exit(suite.testRun?.hasSucceeded == true ? 0 : 1)
