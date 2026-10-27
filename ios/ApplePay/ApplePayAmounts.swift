import Foundation
import PassKit

// ISO 4217 List One, published 2026-09-17 by SIX (the maintenance agency).
// https://www.six-group.com/en/products-services/financial-information/market-reference-data/data-standards.html
private let applePayCurrencyScales: [String: Int] = {
    var result: [String: Int] = [:]
    for code in """
    BIF CLP DJF GNF ISK JPY KMF KRW PYG RWF UGX UYI VND VUV XAF XOF
    XPF
    """.split(whereSeparator: { $0.isWhitespace }) { result[String(code)] = 0 }
    for code in """
    AED AFN ALL AMD AOA ARS AUD AWG AZN BAM BBD BDT BMD BND BOB BOV
    BRL BSD BTN BWP BYN BZD CAD CDF CHE CHF CHW CNY COP COU CRC CUP
    CVE CZK DKK DOP DZD EGP ERN ETB EUR FJD FKP GBP GEL GHS GIP GMD
    GTQ GYD HKD HNL HTG HUF IDR ILS INR IRR JMD KES KGS KHR KPW KYD
    KZT LAK LBP LKR LRD LSL MAD MDL MGA MKD MMK MNT MOP MRU MUR MVR
    MWK MXN MXV MYR MZN NAD NGN NIO NOK NPR NZD PAB PEN PGK PHP PKR
    PLN QAR RON RSD RUB SAR SBD SCR SDG SEK SGD SHP SLE SOS SRD SSP
    STN SVC SYP SZL THB TJS TMT TOP TRY TTD TWD TZS UAH USD USN UYU
    UZS VED VES WST XAD XCD XCG YER ZAR ZMW ZWG
    """.split(whereSeparator: { $0.isWhitespace }) { result[String(code)] = 2 }
    for code in """
    BHD IQD JOD KWD LYD OMR TND
    """.split(whereSeparator: { $0.isWhitespace }) { result[String(code)] = 3 }
    for code in """
    CLF UYW
    """.split(whereSeparator: { $0.isWhitespace }) { result[String(code)] = 4 }
    return result
}()

func applePayCurrencyScale(_ code: String) -> Int? { applePayCurrencyScales[code] }

func validateApplePayAmount(_ amount: NSDecimalNumber, currencyCode: String, field: String) throws {
    guard let scale = applePayCurrencyScale(currencyCode) else {
        throw ApplePayConfigurationError.invalidValue(field: "currencyCode", expected: "must have a defined ISO 4217 minor unit")
    }
    var value = amount.decimalValue
    var rounded = Decimal()
    guard !NSDecimalIsNotANumber(&value) else {
        throw ApplePayConfigurationError.invalidValue(field: field, expected: "must be a finite decimal amount")
    }
    NSDecimalRound(&rounded, &value, scale, .plain)
    guard NSDecimalCompare(&value, &rounded) == .orderedSame else {
        throw ApplePayConfigurationError.invalidValue(field: field, expected: "must be exact to \(scale) decimal places for \(currencyCode)")
    }
}

func validateApplePayAmounts(_ items: [PKPaymentSummaryItem], shippingMethods: [PKShippingMethod], currencyCode: String) throws {
    try validateApplePaySummaryAmounts(items, currencyCode: currencyCode, field: "paymentSummaryItems")
    for (index, method) in shippingMethods.enumerated() {
        try validateApplePayAmount(method.amount, currencyCode: currencyCode, field: "shippingMethods[\(index)]")
    }
}

func validateApplePaySummaryAmounts(_ items: [PKPaymentSummaryItem], currencyCode: String, field: String) throws {
    for (index, item) in items.enumerated() {
        try validateApplePayAmount(item.amount, currencyCode: currencyCode, field: "\(field)[\(index)]")
    }
}

func formattedApplePayAmount(_ amount: NSDecimalNumber, currencyCode: String) throws -> String {
    try validateApplePayAmount(amount, currencyCode: currencyCode, field: "authorizedTotal.amount")
    guard let scale = applePayCurrencyScale(currencyCode) else {
        throw ApplePayConfigurationError.invalidValue(field: "currencyCode", expected: "has no defined minor unit")
    }
    let parts = amount.stringValue.components(separatedBy: ".")
    guard scale > 0 else { return parts[0] }
    let fraction = parts.count > 1 ? parts[1] : ""
    return parts[0] + "." + String(fraction.prefix(scale)) + String(repeating: "0", count: max(0, scale - fraction.count))
}
