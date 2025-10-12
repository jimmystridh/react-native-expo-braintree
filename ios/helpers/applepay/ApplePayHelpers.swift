import Contacts
import Foundation
import PassKit

enum ApplePayConfigurationError: Error {
  case missingSummaryItems
  case invalidSummaryItem
}

func mapMerchantCapabilities(from values: [String]?) -> PKMerchantCapability {
  guard let values = values, !values.isEmpty else {
    if #available(iOS 14.0, *) {
      return [.threeDSecure]
    } else {
      return [.capability3DS]
    }
  }
  var capabilities: PKMerchantCapability = []
  for value in values {
    switch value.lowercased() {
    case "3ds":
      if #available(iOS 14.0, *) {
        capabilities.insert(.threeDSecure)
      } else {
        capabilities.insert(.capability3DS)
      }
    case "credit":
      if #available(iOS 14.0, *) {
        capabilities.insert(.credit)
      } else {
        capabilities.insert(.capabilityCredit)
      }
    case "debit":
      if #available(iOS 14.0, *) {
        capabilities.insert(.debit)
      } else {
        capabilities.insert(.capabilityDebit)
      }
    case "emv":
      if #available(iOS 14.0, *) {
        capabilities.insert(.emv)
      } else {
        capabilities.insert(.capabilityEMV)
      }
    default:
      continue
    }
  }
  if capabilities.isEmpty {
    if #available(iOS 14.0, *) {
      capabilities.insert(.threeDSecure)
    } else {
      capabilities.insert(.capability3DS)
    }
  }
  return capabilities
}

func mapSupportedNetworks(from values: [String]) -> [PKPaymentNetwork] {
  var networks: [PKPaymentNetwork] = []
  for value in values {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized.isEmpty {
      continue
    }
    switch normalized.lowercased() {
    case "visa":
      networks.append(.visa)
    case "mastercard", "master_card":
      networks.append(.masterCard)
    case "amex", "americanexpress":
      networks.append(.amex)
    case "discover":
      networks.append(.discover)
    case "chinaunionpay", "china_union_pay":
      networks.append(.chinaUnionPay)
    case "interac":
      if #available(iOS 9.2, *) {
        networks.append(.interac)
      }
    case "jcb":
      if #available(iOS 10.1, *) {
        networks.append(.JCB)
      }
    case "maestro":
      if #available(iOS 12.0, *) {
        networks.append(.maestro)
      }
    case "electron":
      if #available(iOS 12.0, *) {
        networks.append(.electron)
      }
    case "eftpos":
      if #available(iOS 11.2, *) {
        networks.append(.eftpos)
      }
    case "cartesbancaires":
      if #available(iOS 11.2, *) {
        networks.append(.cartesBancaires)
      }
    case "idcredit":
      if #available(iOS 10.3, *) {
        networks.append(.idCredit)
      }
    case "quicpay":
      if #available(iOS 10.3, *) {
        networks.append(.quicPay)
      }
    case "suica":
      if #available(iOS 10.1, *) {
        networks.append(.suica)
      }
    case "mada":
      if #available(iOS 12.1.1, *) {
        networks.append(.mada)
      }
    case "elo":
      if #available(iOS 12.1.1, *) {
        networks.append(.elo)
      }
    case "privatelabel", "private_label":
      networks.append(.privateLabel)
    default:
      if !normalized.isEmpty {
        networks.append(PKPaymentNetwork(rawValue: normalized))
      }
    }
  }
  return Array(Set(networks))
}

func mapContactFields(from values: [String]?) -> Set<PKContactField> {
  guard let values = values else {
    return []
  }
  var result = Set<PKContactField>()
  for value in values {
    switch value.lowercased() {
    case "email":
      result.insert(.emailAddress)
    case "name":
      result.insert(.name)
    case "phone":
      result.insert(.phoneNumber)
    case "postaladdress", "postal_address":
      result.insert(.postalAddress)
    case "phoneticname", "phonetic_name":
      if #available(iOS 11.0, *) {
        result.insert(.phoneticName)
      }
    default:
      continue
    }
  }
  return result
}

private func summaryItemType(from value: String?) -> PKPaymentSummaryItemType {
  guard let value = value?.lowercased() else {
    return .final
  }
  switch value {
  case "pending":
    return .pending
  default:
    return .final
  }
}

func mapSummaryItems(from items: [[String: Any]]) throws -> [PKPaymentSummaryItem] {
  guard !items.isEmpty else {
    throw ApplePayConfigurationError.missingSummaryItems
  }

  return try items.map { item in
    guard
      let label = item["label"] as? String,
      !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let amountString = item["amount"] as? String
    else {
      throw ApplePayConfigurationError.invalidSummaryItem
    }

    let amount = NSDecimalNumber(string: amountString)
    if amount == NSDecimalNumber.notANumber {
      throw ApplePayConfigurationError.invalidSummaryItem
    }

    let summaryItem = PKPaymentSummaryItem()
    summaryItem.label = label
    summaryItem.amount = amount
    if #available(iOS 11.0, *) {
      summaryItem.type = summaryItemType(from: item["type"] as? String)
    }
    return summaryItem
  }
}

func mapShippingMethods(from items: [[String: Any]]) -> [PKShippingMethod] {
  guard !items.isEmpty else {
    return []
  }

  var methods: [PKShippingMethod] = []
  for item in items {
    guard
      let identifier = item["identifier"] as? String,
      !identifier.isEmpty,
      let label = item["label"] as? String,
      !label.isEmpty,
      let amountString = item["amount"] as? String
    else {
      continue
    }

    let amount = NSDecimalNumber(string: amountString)
    if amount == NSDecimalNumber.notANumber {
      continue
    }

    let method = PKShippingMethod()
    method.identifier = identifier
    method.label = label
    method.amount = amount
    if let detail = item["detail"] as? String {
      method.detail = detail
    }
    if #available(iOS 11.0, *) {
      method.type = summaryItemType(from: item["type"] as? String)
    }
    methods.append(method)
  }

  return methods
}

func mapShippingType(from value: String?) -> PKShippingType? {
  guard let value = value?.lowercased() else {
    return nil
  }
  switch value {
  case "shipping":
    return .shipping
  case "delivery":
    return .delivery
  case "storepickup", "store_pickup":
    return .storePickup
  case "servicepickup", "service_pickup":
    return .servicePickup
  default:
    return nil
  }
}

func mapContact(from options: [String: Any]?) -> PKContact? {
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
      let line1 = postalAddressDict["line1"] as? String
      let line2 = postalAddressDict["line2"] as? String
      let joinedStreet = [line1, line2]
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

func mapApplePayApplicationData(from value: String?) -> Data? {
  guard let value = value, !value.isEmpty else {
    return nil
  }
  if let base64Data = Data(base64Encoded: value) {
    return base64Data
  }
  return value.data(using: .utf8)
}
