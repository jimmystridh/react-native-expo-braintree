import Foundation
import PassKit

func validatedApplePayRegionCode(_ value: String?, field: String) throws -> String? {
    guard let value = value else { return nil }
    let isCountry = field == "countryCode"
    let pattern = isCountry ? #"\A[A-Z]{2}\z"# : #"\A[A-Z]{3}\z"#
    let codes = isCountry ? Locale.isoRegionCodes : Locale.isoCurrencyCodes
    guard value.range(of: pattern, options: .regularExpression) != nil, codes.contains(value) else {
        throw ApplePayConfigurationError.invalidValue(
            field: field,
            expected: isCountry ? "must be a two-letter uppercase ISO 3166 country code" : "must be a three-letter uppercase ISO 4217 currency code"
        )
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
        _ = try validatedApplePayRegionCode(paymentRequest.countryCode, field: "countryCode")
        _ = try validatedApplePayRegionCode(paymentRequest.currencyCode, field: "currencyCode")
    } catch {
        return applePayErrorResult(.APPLE_PAY_CONFIGURATION_ERROR, nativeError: error.localizedDescription)
    }
    guard canMakePayments(paymentRequest.supportedNetworks, paymentRequest.merchantCapabilities) else {
        return applePayErrorResult(.APPLE_PAY_NOT_AVAILABLE_ERROR, nativeError: "No card in Wallet matches the supported networks and merchant capabilities")
    }
    return nil
}

func applePayErrorResult(
    _ message: ERROR_TYPES,
    code: EXCEPTION_TYPES = .SWIFT_EXCEPTION,
    nativeError: String
) -> Dictionary<String, String> {
    return ["error": "true", "code": code.rawValue, "message": message.rawValue, "domain": message.rawValue, "nativeError": nativeError]
}
