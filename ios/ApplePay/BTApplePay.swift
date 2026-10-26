import Braintree
import Contacts
import Foundation
import PassKit

enum ApplePayConfigurationError: LocalizedError {
    case missingSummaryItems
    case invalidSummaryItem

    var errorDescription: String? {
        switch self {
        case .missingSummaryItems:
            return "paymentSummaryItems must contain at least one item"
        case .invalidSummaryItem:
            return "Every payment summary item needs a non-empty label and a decimal amount string"
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
    return ApplePayRequestOptions(
        merchantIdentifier: nonEmpty(options["merchantIdentifier"]),
        countryCode: nonEmpty(options["countryCode"]),
        currencyCode: nonEmpty(options["currencyCode"]),
        supportedNetworks: mapSupportedNetworks(from: decodeJSON(options["supportedNetworks"]) ?? []),
        paymentSummaryItems: try mapSummaryItems(from: decodeJSON(options["paymentSummaryItems"]) ?? []),
        merchantCapabilities: mapMerchantCapabilities(from: decodeJSON(options["merchantCapabilities"]) ?? []),
        requiredBillingContactFields: mapContactFields(from: decodeJSON(options["requiredBillingContactFields"]) ?? []),
        requiredShippingContactFields: mapContactFields(from: decodeJSON(options["requiredShippingContactFields"]) ?? []),
        shippingMethods: mapShippingMethods(from: decodeJSON(options["shippingMethods"]) ?? []),
        billingContact: mapContact(from: decodeJSON(options["billingContact"])),
        shippingContact: mapContact(from: decodeJSON(options["shippingContact"])),
        shippingType: mapShippingType(from: options["shippingType"]),
        applicationData: mapApplicationData(from: options["applicationData"])
    )
}

func prepareBTApplePayNonceResult(cardNonce: BTApplePayCardNonce, payment: PKPayment) -> NSDictionary {
    let result = NSMutableDictionary()
    result["nonce"] = cardNonce.nonce
    result["type"] = cardNonce.type
    result["isDefault"] = cardNonce.isDefault
    result["isDeviceToken"] = cardNonce.isDeviceToken
    result["cardNetwork"] = payment.token.paymentMethod.network?.rawValue ?? ""
    result.addEntries(from: prepareApplePayPaymentDetails(payment))

    let binData = NSMutableDictionary()
    binData["prepaid"] = cardNonce.binData.prepaid
    binData["healthcare"] = cardNonce.binData.healthcare
    binData["debit"] = cardNonce.binData.debit
    binData["durbinRegulated"] = cardNonce.binData.durbinRegulated
    binData["commercial"] = cardNonce.binData.commercial
    binData["payroll"] = cardNonce.binData.payroll
    binData["issuingBank"] = cardNonce.binData.issuingBank
    binData["countryOfIssuance"] = cardNonce.binData.countryOfIssuance
    binData["productID"] = cardNonce.binData.productID
    result["binData"] = binData
    return result
}

private func nonEmpty(_ value: String?) -> String? {
    guard let value = value, !value.isEmpty else { return nil }
    return value
}

private func decodeJSON<T>(_ value: String?) -> T? {
    guard let data = value?.data(using: .utf8) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? T
}

private func mapMerchantCapabilities(from values: [String]) -> PKMerchantCapability {
    var capabilities: PKMerchantCapability = []
    for value in values {
        switch value.lowercased() {
        case "3ds": capabilities.insert(.threeDSecure)
        case "credit": capabilities.insert(.credit)
        case "debit": capabilities.insert(.debit)
        case "emv": capabilities.insert(.emv)
        default: continue
        }
    }
    return capabilities.isEmpty ? .threeDSecure : capabilities
}

private func mapSupportedNetworks(from values: [String]) -> [PKPaymentNetwork] {
    var seen = Set<PKPaymentNetwork>()
    return values.compactMap { value -> PKPaymentNetwork? in
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch normalized.lowercased() {
        case "": return nil
        case "visa": return .visa
        case "mastercard", "master_card": return .masterCard
        case "amex", "americanexpress": return .amex
        case "discover": return .discover
        case "chinaunionpay", "china_union_pay": return .chinaUnionPay
        case "interac": return .interac
        case "jcb": return .JCB
        case "maestro": return .maestro
        case "electron": return .electron
        case "eftpos": return .eftpos
        case "cartesbancaires": return .cartesBancaires
        case "idcredit": return .idCredit
        case "quicpay": return .quicPay
        case "suica": return .suica
        case "mada": return .mada
        case "elo": return .elo
        case "privatelabel", "private_label": return .privateLabel
        default: return PKPaymentNetwork(rawValue: normalized)
        }
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

private func summaryItemType(from value: Any?) -> PKPaymentSummaryItemType {
    return (value as? String)?.lowercased() == "pending" ? .pending : .final
}

private func decimalAmount(from value: Any?) -> NSDecimalNumber? {
    guard let amountString = value as? String else { return nil }
    let amount = NSDecimalNumber(string: amountString)
    return amount == NSDecimalNumber.notANumber ? nil : amount
}

private func mapSummaryItems(from items: [[String: Any]]) throws -> [PKPaymentSummaryItem] {
    guard !items.isEmpty else {
        throw ApplePayConfigurationError.missingSummaryItems
    }
    return try items.map { item in
        guard
            let label = item["label"] as? String,
            !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let amount = decimalAmount(from: item["amount"])
        else {
            throw ApplePayConfigurationError.invalidSummaryItem
        }
        return PKPaymentSummaryItem(label: label, amount: amount, type: summaryItemType(from: item["type"]))
    }
}

private func mapShippingMethods(from items: [[String: Any]]) -> [PKShippingMethod] {
    return items.compactMap { item in
        guard
            let identifier = item["identifier"] as? String, !identifier.isEmpty,
            let label = item["label"] as? String, !label.isEmpty,
            let amount = decimalAmount(from: item["amount"])
        else {
            return nil
        }
        let method = PKShippingMethod(label: label, amount: amount, type: summaryItemType(from: item["type"]))
        method.identifier = identifier
        method.detail = item["detail"] as? String
        return method
    }
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
    guard let value = value, !value.isEmpty else {
        return nil
    }
    return Data(base64Encoded: value) ?? value.data(using: .utf8)
}
