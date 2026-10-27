import Contacts
import Foundation
import PassKit

func prepareApplePaySummaryItems(
    summaryItems: [PKPaymentSummaryItem],
    defaultShippingMethod: PKShippingMethod?,
    selectedShippingMethod: PKShippingMethod
) -> [PKPaymentSummaryItem] {
    guard let total = summaryItems.last, let defaultShippingMethod = defaultShippingMethod else {
        return summaryItems
    }

    var updatedItems = Array(summaryItems.dropLast())
    if let shippingIndex = updatedItems.lastIndex(where: {
        $0.label == defaultShippingMethod.label && $0.amount == defaultShippingMethod.amount
    }) {
        updatedItems[shippingIndex] = PKPaymentSummaryItem(
            label: selectedShippingMethod.label,
            amount: selectedShippingMethod.amount,
            type: selectedShippingMethod.type
        )
    }
    let updatedTotal = total.amount.subtracting(defaultShippingMethod.amount).adding(selectedShippingMethod.amount)
    updatedItems.append(PKPaymentSummaryItem(label: total.label, amount: updatedTotal, type: total.type))
    return updatedItems
}

func prepareApplePayPaymentDetails(_ payment: PKPayment, shippingMethodAmounts: [String: String] = [:]) -> [String: Any] {
    var result: [String: Any] = [:]
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
