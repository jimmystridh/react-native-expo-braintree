import Contacts
import Foundation
import PassKit

enum ApplePayConfigurationError: LocalizedError {
    case missingSummaryItems(field: String)
    case invalidJSON(field: String, expected: String)
    case invalidArrayElement(field: String, index: Int)
    case invalidSummaryItem(field: String, index: Int)
    case invalidShippingMethod(index: Int)
    case invalidValue(field: String, expected: String)

    var errorDescription: String? {
        switch self {
        case let .missingSummaryItems(field):
            return "\(field) must contain at least one item"
        case let .invalidJSON(field, expected):
            return "\(field) must be a valid JSON \(expected)"
        case let .invalidArrayElement(field, index):
            return "\(field)[\(index)] is invalid"
        case let .invalidSummaryItem(field, index):
            return "\(field)[\(index)] needs a non-empty label and a strict decimal amount string; the grand total must be positive"
        case let .invalidShippingMethod(index):
            return "shippingMethods[\(index)] needs a unique non-empty identifier, a non-empty label, and a non-negative strict decimal amount string"
        case let .invalidValue(field, expected):
            return "\(field) \(expected)"
        }
    }
}

struct ApplePayRequestOptions {
    let merchantIdentifier: String?
    let countryCode: String?
    let currencyCode: String?
    let supportedNetworks: [PKPaymentNetwork]
    let paymentSummaryItems: [PKPaymentSummaryItem]
    let merchantCapabilities: PKMerchantCapability
    let requiredBillingContactFields: Set<PKContactField>
    let requiredShippingContactFields: Set<PKContactField>
    let shippingMethods: [PKShippingMethod]
    let shippingMethodAmounts: [String: String]
    let shippingSummaryItems: [String: [PKPaymentSummaryItem]]
    let billingContact: PKContact?
    let shippingContact: PKContact?
    let shippingType: PKShippingType?
    let applicationData: Data?

    func summaryItems(for shippingMethod: PKShippingMethod) throws -> [PKPaymentSummaryItem] {
        guard let identifier = shippingMethod.identifier, let items = shippingSummaryItems[identifier] else {
            throw ApplePayConfigurationError.invalidValue(field: "shippingMethods", expected: "does not contain the selected shipping method")
        }
        return items
    }

    func validateAmounts(currencyCode: String) throws {
        try validateApplePayAmounts(paymentSummaryItems, shippingMethods: shippingMethods, currencyCode: currencyCode)
        for (index, method) in shippingMethods.enumerated() {
            try validateApplePaySummaryAmounts(try summaryItems(for: method), currencyCode: currencyCode, field: "shippingMethods[\(index)].paymentSummaryItems")
        }
    }

    // Braintree prefills merchant ID, country, currency and networks from the gateway configuration.
    func apply(to paymentRequest: PKPaymentRequest) {
        if let merchantIdentifier = merchantIdentifier {
            paymentRequest.merchantIdentifier = merchantIdentifier
        }
        if let countryCode = countryCode {
            paymentRequest.countryCode = countryCode
        }
        if let currencyCode = currencyCode {
            paymentRequest.currencyCode = currencyCode
        }
        if !supportedNetworks.isEmpty {
            paymentRequest.supportedNetworks = supportedNetworks
        }
        paymentRequest.paymentSummaryItems = paymentSummaryItems
        paymentRequest.merchantCapabilities = merchantCapabilities
        paymentRequest.requiredBillingContactFields = requiredBillingContactFields
        paymentRequest.requiredShippingContactFields = requiredShippingContactFields
        if !shippingMethods.isEmpty {
            paymentRequest.shippingMethods = shippingMethods
        }
        if let billingContact = billingContact {
            paymentRequest.billingContact = billingContact
        }
        if let shippingContact = shippingContact {
            paymentRequest.shippingContact = shippingContact
        }
        if let shippingType = shippingType {
            paymentRequest.shippingType = shippingType
        }
        if let applicationData = applicationData {
            paymentRequest.applicationData = applicationData
        }
    }
}

func prepareApplePayRequestOptions(options: [String: String]) throws -> ApplePayRequestOptions {
    let countryCode = try validatedApplePayCountryCode(options["countryCode"])
    let currencyCode = try validatedApplePayCurrencyCode(options["currencyCode"])
    let shipping = try mapShippingMethods(from: decodeArray(options["shippingMethods"], field: "shippingMethods"))
    let summaryItems = try mapSummaryItems(from: decodeArray(options["paymentSummaryItems"], field: "paymentSummaryItems"))
    if let currencyCode = currencyCode {
        try validateApplePayAmounts(summaryItems, shippingMethods: shipping.methods, currencyCode: currencyCode)
    }
    if options["shippingSummaryItemIndex"] != nil {
        throw ApplePayConfigurationError.invalidValue(field: "shippingSummaryItemIndex", expected: "is no longer supported; supply paymentSummaryItems for each shipping method")
    }
    if let first = shipping.methods.first, let identifier = first.identifier,
       let initialItems = shipping.summaries[identifier], !sameApplePaySummaryItems(summaryItems, initialItems) {
        throw ApplePayConfigurationError.invalidValue(field: "paymentSummaryItems", expected: "must match the first shipping method's paymentSummaryItems")
    }
    if let currencyCode = currencyCode {
        for (index, method) in shipping.methods.enumerated() {
            guard let identifier = method.identifier, let items = shipping.summaries[identifier] else {
                throw ApplePayConfigurationError.invalidShippingMethod(index: index)
            }
            try validateApplePaySummaryAmounts(items, currencyCode: currencyCode, field: "shippingMethods[\(index)].paymentSummaryItems")
        }
    }
    return ApplePayRequestOptions(
        merchantIdentifier: nonEmpty(options["merchantIdentifier"]),
        countryCode: countryCode,
        currencyCode: currencyCode,
        supportedNetworks: try mapSupportedNetworks(from: decodeStrings(options["supportedNetworks"], field: "supportedNetworks")),
        paymentSummaryItems: summaryItems,
        merchantCapabilities: try mapMerchantCapabilities(from: decodeStrings(options["merchantCapabilities"], field: "merchantCapabilities")),
        requiredBillingContactFields: try mapContactFields(from: decodeStrings(options["requiredBillingContactFields"], field: "requiredBillingContactFields"), field: "requiredBillingContactFields"),
        requiredShippingContactFields: try mapContactFields(from: decodeStrings(options["requiredShippingContactFields"], field: "requiredShippingContactFields"), field: "requiredShippingContactFields"),
        shippingMethods: shipping.methods,
        shippingMethodAmounts: shipping.amounts,
        shippingSummaryItems: shipping.summaries,
        billingContact: mapContact(from: try decodeObject(options["billingContact"], field: "billingContact")),
        shippingContact: mapContact(from: try decodeObject(options["shippingContact"], field: "shippingContact")),
        shippingType: try mapShippingType(from: options["shippingType"]),
        applicationData: mapApplicationData(from: options["applicationData"])
    )
}

private func nonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    return value
}

private func sameApplePaySummaryItems(_ left: [PKPaymentSummaryItem], _ right: [PKPaymentSummaryItem]) -> Bool {
    left.count == right.count && zip(left, right).allSatisfy { $0.label == $1.label && $0.amount == $1.amount && $0.type == $1.type }
}

private func decodeArray(_ value: String?, field: String) throws -> [Any] {
    guard let value = value else { return [] }
    guard let data = value.data(using: .utf8),
          let array = (try? JSONSerialization.jsonObject(with: data)) as? [Any] else {
        throw ApplePayConfigurationError.invalidJSON(field: field, expected: "array")
    }
    return array
}

private func decodeStrings(_ value: String?, field: String) throws -> [String] {
    return try decodeArray(value, field: field).enumerated().map { index, element in
        guard let string = element as? String else {
            throw ApplePayConfigurationError.invalidArrayElement(field: field, index: index)
        }
        return string
    }
}

private func decodeObject(_ value: String?, field: String) throws -> [String: Any]? {
    guard let value = value else { return nil }
    guard let data = value.data(using: .utf8),
          let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
        throw ApplePayConfigurationError.invalidJSON(field: field, expected: "object")
    }
    return object
}

private func mapMerchantCapabilities(from values: [String]) throws -> PKMerchantCapability {
    var capabilities: PKMerchantCapability = .threeDSecure
    for (index, value) in values.enumerated() {
        switch value.lowercased() {
        case "3ds": capabilities.insert(.threeDSecure)
        case "credit": capabilities.insert(.credit)
        case "debit": capabilities.insert(.debit)
        case "emv": capabilities.insert(.emv)
        default: throw ApplePayConfigurationError.invalidArrayElement(field: "merchantCapabilities", index: index)
        }
    }
    return capabilities
}

private func mapSupportedNetworks(from values: [String]) throws -> [PKPaymentNetwork] {
    var seen = Set<PKPaymentNetwork>()
    return try values.enumerated().map { index, value in
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let network = applePayNetwork(named: normalized) else {
            throw ApplePayConfigurationError.invalidArrayElement(field: "supportedNetworks", index: index)
        }
        return network
    }.filter { seen.insert($0).inserted }
}

private func mapContactFields(from values: [String], field: String) throws -> Set<PKContactField> {
    var result = Set<PKContactField>()
    for (index, value) in values.enumerated() {
        switch value.lowercased() {
        case "email": result.insert(.emailAddress)
        case "name": result.insert(.name)
        case "phone": result.insert(.phoneNumber)
        case "postaladdress", "postal_address": result.insert(.postalAddress)
        case "phoneticname", "phonetic_name": result.insert(.phoneticName)
        default: throw ApplePayConfigurationError.invalidArrayElement(field: field, index: index)
        }
    }
    return result
}

private func summaryItemType(from value: Any?) -> PKPaymentSummaryItemType? {
    guard let value = value else { return .final }
    switch (value as? String)?.lowercased() {
    case "final": return .final
    case "pending": return .pending
    default: return nil
    }
}

private func decimalAmount(from value: Any?) -> NSDecimalNumber? {
    guard let amountString = value as? String,
          amountString.range(of: #"\A-?[0-9]+(?:\.[0-9]+)?\z"#, options: .regularExpression) != nil else {
        return nil
    }
    let amount = NSDecimalNumber(string: amountString, locale: Locale(identifier: "en_US_POSIX"))
    guard amount != .notANumber,
          canonicalDecimal(amountString) == canonicalDecimal(amount.stringValue) else { return nil }
    return amount
}

private func canonicalDecimal(_ value: String) -> String {
    let negative = value.hasPrefix("-")
    let parts = (negative ? String(value.dropFirst()) : value).components(separatedBy: ".")
    let integer = String(parts[0].drop(while: { $0 == "0" }))
    let fraction = parts.count == 2 ? String(parts[1].reversed().drop(while: { $0 == "0" }).reversed()) : ""
    let magnitude = (integer.isEmpty ? "0" : integer) + (fraction.isEmpty ? "" : "." + fraction)
    return negative && magnitude != "0" ? "-" + magnitude : magnitude
}

private func mapSummaryItems(from items: [Any], field: String = "paymentSummaryItems") throws -> [PKPaymentSummaryItem] {
    guard !items.isEmpty else {
        throw ApplePayConfigurationError.missingSummaryItems(field: field)
    }
    return try items.enumerated().map { index, element in
        guard let item = element as? [String: Any] else {
            throw ApplePayConfigurationError.invalidArrayElement(field: field, index: index)
        }
        guard
            let label = item["label"] as? String,
            !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let amount = decimalAmount(from: item["amount"]),
            let type = summaryItemType(from: item["type"]),
            index < items.count - 1 || amount.compare(NSDecimalNumber.zero) == .orderedDescending
        else {
            throw ApplePayConfigurationError.invalidSummaryItem(field: field, index: index)
        }
        return PKPaymentSummaryItem(label: label, amount: amount, type: type)
    }
}

private func mapShippingMethods(from items: [Any]) throws -> (methods: [PKShippingMethod], amounts: [String: String], summaries: [String: [PKPaymentSummaryItem]]) {
    var amounts: [String: String] = [:]
    var summaries: [String: [PKPaymentSummaryItem]] = [:]
    let methods = try items.enumerated().map { index, element -> PKShippingMethod in
        guard let item = element as? [String: Any] else {
            throw ApplePayConfigurationError.invalidArrayElement(field: "shippingMethods", index: index)
        }
        guard
            let identifier = item["identifier"] as? String, nonEmpty(identifier) != nil, amounts[identifier] == nil,
            let label = item["label"] as? String, nonEmpty(label) != nil,
            let amount = decimalAmount(from: item["amount"]), amount.compare(NSDecimalNumber.zero) != .orderedAscending,
            let type = summaryItemType(from: item["type"]),
            item["detail"] == nil || item["detail"] is String
        else {
            throw ApplePayConfigurationError.invalidShippingMethod(index: index)
        }
        guard let items = item["paymentSummaryItems"] as? [Any] else {
            throw ApplePayConfigurationError.invalidJSON(field: "shippingMethods[\(index)].paymentSummaryItems", expected: "array")
        }
        summaries[identifier] = try mapSummaryItems(from: items, field: "shippingMethods[\(index)].paymentSummaryItems")
        let method = PKShippingMethod(label: label, amount: amount, type: type)
        method.identifier = identifier
        method.detail = item["detail"] as? String
        amounts[identifier] = item["amount"] as? String
        return method
    }
    return (methods, amounts, summaries)
}

private func mapShippingType(from value: String?) throws -> PKShippingType? {
    guard let value = value else { return nil }
    switch value.lowercased() {
    case "shipping": return .shipping
    case "delivery": return .delivery
    case "storepickup", "store_pickup": return .storePickup
    case "servicepickup", "service_pickup": return .servicePickup
    default: throw ApplePayConfigurationError.invalidValue(field: "shippingType", expected: "must be shipping, delivery, storePickup, or servicePickup")
    }
}

private func mapContact(from options: [String: Any]?) -> PKContact? {
    guard let options = options, !options.isEmpty else {
        return nil
    }

    let contact = PKContact()
    if let email = options["emailAddress"] as? String, !email.isEmpty {
        contact.emailAddress = email
    }
    if let phone = options["phoneNumber"] as? String, !phone.isEmpty {
        contact.phoneNumber = CNPhoneNumber(stringValue: phone)
    }

    var nameComponents = PersonNameComponents()
    var hasNameComponent = false
    if let givenName = options["givenName"] as? String, !givenName.isEmpty {
        nameComponents.givenName = givenName
        hasNameComponent = true
    }
    if let familyName = options["familyName"] as? String, !familyName.isEmpty {
        nameComponents.familyName = familyName
        hasNameComponent = true
    }
    var phoneticComponents = PersonNameComponents()
    var hasPhoneticComponent = false
    if let phoneticGivenName = options["phoneticGivenName"] as? String, !phoneticGivenName.isEmpty {
        phoneticComponents.givenName = phoneticGivenName
        hasPhoneticComponent = true
    }
    if let phoneticFamilyName = options["phoneticFamilyName"] as? String, !phoneticFamilyName.isEmpty {
        phoneticComponents.familyName = phoneticFamilyName
        hasPhoneticComponent = true
    }
    if hasPhoneticComponent {
        nameComponents.phoneticRepresentation = phoneticComponents
        hasNameComponent = true
    }
    if hasNameComponent {
        contact.name = nameComponents
    }

    if let postalAddressDict = options["postalAddress"] as? [String: Any], !postalAddressDict.isEmpty {
        let postalAddress = CNMutablePostalAddress()
        if let street = postalAddressDict["street"] as? String, !street.isEmpty {
            postalAddress.street = street
        } else {
            let joinedStreet = [postalAddressDict["line1"] as? String, postalAddressDict["line2"] as? String]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            if !joinedStreet.isEmpty {
                postalAddress.street = joinedStreet
            }
        }
        if let city = postalAddressDict["city"] as? String {
            postalAddress.city = city
        }
        if let state = postalAddressDict["state"] as? String {
            postalAddress.state = state
        }
        if let postalCode = postalAddressDict["postalCode"] as? String {
            postalAddress.postalCode = postalCode
        }
        if let country = postalAddressDict["country"] as? String {
            postalAddress.country = country
        }
        if let countryCode = postalAddressDict["countryCode"] as? String {
            postalAddress.isoCountryCode = countryCode
        }
        if let subAdministrativeArea = postalAddressDict["subAdministrativeArea"] as? String {
            postalAddress.subAdministrativeArea = subAdministrativeArea
        }
        if let subLocality = postalAddressDict["subLocality"] as? String {
            postalAddress.subLocality = subLocality
        }
        contact.postalAddress = postalAddress
    }

    if contact.emailAddress == nil,
       contact.phoneNumber == nil,
       contact.name == nil,
       contact.postalAddress == nil {
        return nil
    }
    return contact
}

private func mapApplicationData(from value: String?) -> Data? {
    return value?.data(using: .utf8)
}
