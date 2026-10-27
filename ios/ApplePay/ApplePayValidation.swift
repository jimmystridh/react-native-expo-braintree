import Foundation
import PassKit

func validatedApplePayCountryCode(_ value: String?) throws -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    guard value.range(of: #"\A[A-Z]{2}\z"#, options: .regularExpression) != nil, Locale.isoRegionCodes.contains(value) else {
        throw ApplePayConfigurationError.invalidValue(field: "countryCode", expected: "must be a two-letter uppercase ISO 3166 country code")
    }
    return value
}

func validatedApplePayCurrencyCode(_ value: String?) throws -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    guard applePayCurrencyScale(value) != nil else {
        throw ApplePayConfigurationError.invalidValue(field: "currencyCode", expected: "must be an uppercase ISO 4217 currency code with a defined minor unit")
    }
    return value
}

func applePayPaymentRequestError(
    _ paymentRequest: PKPaymentRequest,
    canMakePayments: ([PKPaymentNetwork], PKMerchantCapability) -> Bool = { networks, capabilities in
        PKPaymentAuthorizationController.canMakePayments(usingNetworks: networks, capabilities: capabilities)
    }
) -> [String: String]? {
    guard !paymentRequest.merchantIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return applePayErrorResult(.APPLE_PAY_CONFIGURATION_ERROR, nativeError: "No merchantIdentifier was passed and none is configured for Apple Pay in the Braintree gateway")
    }
    guard !paymentRequest.supportedNetworks.isEmpty else {
        return applePayErrorResult(.APPLE_PAY_CONFIGURATION_ERROR, nativeError: "No supportedNetworks were passed and none are configured for Apple Pay in the Braintree gateway")
    }
    do {
        guard try validatedApplePayCountryCode(paymentRequest.countryCode) == paymentRequest.countryCode else {
            throw ApplePayConfigurationError.invalidValue(field: "countryCode", expected: "must resolve to a canonical uppercase ISO country code")
        }
        guard try validatedApplePayCurrencyCode(paymentRequest.currencyCode) == paymentRequest.currencyCode else {
            throw ApplePayConfigurationError.invalidValue(field: "currencyCode", expected: "must resolve to a canonical uppercase ISO currency code")
        }
        try validateApplePayAmounts(paymentRequest.paymentSummaryItems, shippingMethods: paymentRequest.shippingMethods ?? [], currencyCode: paymentRequest.currencyCode)
    } catch {
        return applePayErrorResult(.APPLE_PAY_CONFIGURATION_ERROR, nativeError: error.localizedDescription)
    }
    guard canMakePayments(paymentRequest.supportedNetworks, paymentRequest.merchantCapabilities) else {
        return applePayErrorResult(.APPLE_PAY_NOT_AVAILABLE_ERROR, nativeError: "No card in Wallet matches the supported networks and merchant capabilities")
    }
    return nil
}
