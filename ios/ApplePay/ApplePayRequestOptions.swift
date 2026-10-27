import Contacts
import Foundation
import PassKit

enum ApplePayConfigurationError: LocalizedError {
    case missingSummaryItems
    case invalidJSON(field: String, expected: String)
    case invalidArrayElement(field: String, index: Int)
    case invalidSummaryItem(index: Int)
    case invalidShippingMethod(index: Int)

    var errorDescription: String? {
        switch self {
        case .missingSummaryItems:
            return "paymentSummaryItems must contain at least one item"
        case let .invalidJSON(field, expected):
            return "\(field) must be a valid JSON \(expected)"
        case let .invalidArrayElement(field, index):
            return "\(field)[\(index)] is invalid"
        case let .invalidSummaryItem(index):
            return "paymentSummaryItems[\(index)] needs a non-empty label and a strict decimal amount string; the grand total must be positive"
        case let .invalidShippingMethod(index):
            return "shippingMethods[\(index)] needs a unique non-empty identifier, a non-empty label, and a non-negative strict decimal amount string"
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
    let billingContact: PKContact?
    let shippingContact: PKContact?
    let shippingType: PKShippingType?
    let applicationData: Data?

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
    let shipping = try mapShippingMethods(from: decodeArray(options["shippingMethods"], field: "shippingMethods"))
    return ApplePayRequestOptions(
        merchantIdentifier: nonEmpty(options["merchantIdentifier"]),
        countryCode: nonEmpty(options["countryCode"]),
        currencyCode: nonEmpty(options["currencyCode"]),
        supportedNetworks: try mapSupportedNetworks(from: decodeStrings(options["supportedNetworks"], field: "supportedNetworks")),
        paymentSummaryItems: try mapSummaryItems(from: decodeArray(options["paymentSummaryItems"], field: "paymentSummaryItems")),
        merchantCapabilities: mapMerchantCapabilities(from: try decodeStrings(options["merchantCapabilities"], field: "merchantCapabilities")),
        requiredBillingContactFields: mapContactFields(from: try decodeStrings(options["requiredBillingContactFields"], field: "requiredBillingContactFields")),
        requiredShippingContactFields: mapContactFields(from: try decodeStrings(options["requiredShippingContactFields"], field: "requiredShippingContactFields")),
        shippingMethods: shipping.methods,
        shippingMethodAmounts: shipping.amounts,
        billingContact: mapContact(from: try decodeObject(options["billingContact"], field: "billingContact")),
        shippingContact: mapContact(from: try decodeObject(options["shippingContact"], field: "shippingContact")),
        shippingType: mapShippingType(from: options["shippingType"]),
        applicationData: mapApplicationData(from: options["applicationData"])
    )
}

private func nonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    return value
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

private func mapMerchantCapabilities(from values: [String]) -> PKMerchantCapability {
    var capabilities: PKMerchantCapability = .threeDSecure
    for value in values {
        switch value.lowercased() {
        case "3ds": capabilities.insert(.threeDSecure)
        case "credit": capabilities.insert(.credit)
        case "debit": capabilities.insert(.debit)
        case "emv": capabilities.insert(.emv)
        default: continue
        }
    }
    return capabilities
}

private func mapSupportedNetworks(from values: [String]) throws -> [PKPaymentNetwork] {
    var seen = Set<PKPaymentNetwork>()
    return try values.enumerated().map { index, value in
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw ApplePayConfigurationError.invalidArrayElement(field: "supportedNetworks", index: index)
        }
        return applePayNetwork(named: normalized)
    }.filter { seen.insert($0).inserted }
}

private func mapContactFields(from values: [String]) -> Set<PKContactField> {
    var result = Set<PKContactField>()
    for value in values {
        switch value.lowercased() {
        case "email": result.insert(.emailAddress)
        case "name": result.insert(.name)
        case "phone": result.insert(.phoneNumber)
        case "postaladdress", "postal_address": result.insert(.postalAddress)
        case "phoneticname", "phonetic_name": result.insert(.phoneticName)
        default: continue
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

private func mapSummaryItems(from items: [Any]) throws -> [PKPaymentSummaryItem] {
    guard !items.isEmpty else {
        throw ApplePayConfigurationError.missingSummaryItems
    }
    return try items.enumerated().map { index, element in
        guard let item = element as? [String: Any] else {
            throw ApplePayConfigurationError.invalidArrayElement(field: "paymentSummaryItems", index: index)
        }
        guard
            let label = item["label"] as? String,
            !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let amount = decimalAmount(from: item["amount"]),
            let type = summaryItemType(from: item["type"]),
            index < items.count - 1 || amount.compare(NSDecimalNumber.zero) == .orderedDescending
        else {
            throw ApplePayConfigurationError.invalidSummaryItem(index: index)
        }
        return PKPaymentSummaryItem(label: label, amount: amount, type: type)
    }
}

private func mapShippingMethods(from items: [Any]) throws -> (methods: [PKShippingMethod], amounts: [String: String]) {
    var amounts: [String: String] = [:]
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
        let method = PKShippingMethod(label: label, amount: amount, type: type)
        method.identifier = identifier
        method.detail = item["detail"] as? String
        amounts[identifier] = item["amount"] as? String
        return method
    }
    return (methods, amounts)
}

private func mapShippingType(from value: String?) -> PKShippingType? {
    switch value?.lowercased() {
    case "shipping": return .shipping
    case "delivery": return .delivery
    case "storepickup", "store_pickup": return .storePickup
    case "servicepickup", "service_pickup": return .servicePickup
    default: return nil
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
