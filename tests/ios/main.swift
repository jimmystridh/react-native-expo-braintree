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

    func testShippingSelectionUpdatesTotalWithoutAccumulatingCharges() {
        let standard = shippingMethod("Standard", amount: "2.10")
        let express = shippingMethod("Express", amount: "7.25")
        let free = shippingMethod("Pickup", amount: "0.00")
        let items = [
            PKPaymentSummaryItem(label: "Goods", amount: NSDecimalNumber(string: "10.00")),
            PKPaymentSummaryItem(label: "Merchant", amount: NSDecimalNumber(string: "12.10")),
        ]

        for (method, expectedTotal) in [(express, "17.25"), (express, "17.25"), (free, "10.00"), (standard, "12.10")] {
            let updated = prepareApplePaySummaryItems(
                summaryItems: items, defaultShippingMethod: standard, selectedShippingMethod: method
            )
            XCTAssertEqual(updated.last?.amount, NSDecimalNumber(string: expectedTotal))
            XCTAssertEqual(updated.last?.label, "Merchant")
            XCTAssertEqual(updated.first?.amount, NSDecimalNumber(string: "10.00"))
        }
        XCTAssertEqual(items.last?.amount, NSDecimalNumber(string: "12.10"))
    }

    func testShippingSelectionReplacesItemizedShippingAndPreservesOtherItems() {
        let standard = shippingMethod("Standard", amount: "2.10")
        let express = shippingMethod("Express", amount: "7.25")
        let items = [
            PKPaymentSummaryItem(label: "Goods", amount: NSDecimalNumber(string: "10.00"), type: .pending),
            PKPaymentSummaryItem(label: "Standard", amount: standard.amount),
            PKPaymentSummaryItem(label: "Discount", amount: NSDecimalNumber(string: "-1.00")),
            PKPaymentSummaryItem(label: "Merchant", amount: NSDecimalNumber(string: "11.10")),
        ]
        let updated = prepareApplePaySummaryItems(
            summaryItems: items, defaultShippingMethod: standard, selectedShippingMethod: express
        )

        XCTAssertEqual(updated.map { $0.label }, ["Goods", "Express", "Discount", "Merchant"])
        XCTAssertEqual(updated[1].amount, express.amount)
        XCTAssertEqual(updated.last?.amount, NSDecimalNumber(string: "16.25"))
        XCTAssertEqual(updated[0].type, .pending)
        XCTAssertEqual(updated[2].amount, NSDecimalNumber(string: "-1.00"))
        XCTAssertEqual(items[1].amount, standard.amount)
    }

    func testShippingSelectionSupportsTotalOnlyAndNoConfiguredMethods() {
        let total = PKPaymentSummaryItem(label: "Merchant", amount: NSDecimalNumber(string: "12.10"))
        let standard = shippingMethod("Standard", amount: "2.10")
        let express = shippingMethod("Express", amount: "7.25")
        let updated = prepareApplePaySummaryItems(
            summaryItems: [total], defaultShippingMethod: standard, selectedShippingMethod: express
        )
        XCTAssertEqual(updated.count, 1)
        XCTAssertEqual(updated[0].amount, NSDecimalNumber(string: "17.25"))

        let unchanged = prepareApplePaySummaryItems(
            summaryItems: [total], defaultShippingMethod: nil, selectedShippingMethod: express
        )
        XCTAssertEqual(unchanged[0].amount, total.amount)
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

        let details = prepareApplePayPaymentDetails(payment)
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

    func testAbsentDetailsAreOmittedAndPendingShippingAmountRemainsAString() {
        let payment = AuthorizedPayment()
        XCTAssertTrue(prepareApplePayPaymentDetails(payment).isEmpty)

        let method = PKShippingMethod(label: "Pending", amount: NSDecimalNumber.zero, type: .pending)
        method.identifier = "pending"
        payment.selectedShippingMethod = method
        let details = prepareApplePayPaymentDetails(payment)
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
suite.run()
exit(suite.testRun?.hasSucceeded == true ? 0 : 1)
