import Contacts
import Foundation
import PassKit

func prepareApplePayPaymentDetails(
    _ payment: PKPayment,
    shippingMethodAmounts: [String: String] = [:],
    authorizedTotal: PKPaymentSummaryItem? = nil,
    currencyCode: String? = nil
) throws -> [String: Any] {
    var result: [String: Any] = [:]
    if let total = authorizedTotal, let currencyCode = currencyCode {
        result["authorizedTotal"] = ["amount": try formattedApplePayAmount(total.amount, currencyCode: currencyCode), "currencyCode": currencyCode]
    }
    if let billingContact = payment.billingContact {
        result["billingContact"] = prepareApplePayContact(billingContact)
    }
    if let shippingContact = payment.shippingContact {
        result["shippingContact"] = prepareApplePayContact(shippingContact)
    }
    if let shippingMethod = payment.shippingMethod {
        var method = [
            "label": shippingMethod.label,
            "amount": shippingMethod.identifier.flatMap { shippingMethodAmounts[$0] } ?? shippingMethod.amount.stringValue,
            "type": shippingMethod.type == .pending ? "pending" : "final",
        ]
        method["identifier"] = shippingMethod.identifier
        method["detail"] = shippingMethod.detail
        result["shippingMethod"] = method
    }
    return result
}

private func prepareApplePayContact(_ contact: PKContact) -> [String: Any] {
    var result: [String: Any] = [:]
    result["emailAddress"] = contact.emailAddress
    result["phoneNumber"] = contact.phoneNumber?.stringValue
    result["givenName"] = contact.name?.givenName
    result["familyName"] = contact.name?.familyName
    result["phoneticGivenName"] = contact.name?.phoneticRepresentation?.givenName
    result["phoneticFamilyName"] = contact.name?.phoneticRepresentation?.familyName
    if let address = contact.postalAddress {
        result["postalAddress"] = [
            "street": address.street,
            "city": address.city,
            "state": address.state,
            "postalCode": address.postalCode,
            "country": address.country,
            "countryCode": address.isoCountryCode,
            "subAdministrativeArea": address.subAdministrativeArea,
            "subLocality": address.subLocality,
        ]
    }
    return result
}
