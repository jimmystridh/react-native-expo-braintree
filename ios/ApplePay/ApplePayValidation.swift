import Foundation
import PassKit

func applePayPaymentRequestError(
    _ paymentRequest: PKPaymentRequest,
    canMakePayments: ([PKPaymentNetwork], PKMerchantCapability) -> Bool = { networks, capabilities in
        PKPaymentAuthorizationController.canMakePayments(usingNetworks: networks, capabilities: capabilities)
    }
) -> [String: String]? {
    guard !paymentRequest.merchantIdentifier.isEmpty else {
        return applePayErrorResult(.APPLE_PAY_CONFIGURATION_ERROR, nativeError: "No merchantIdentifier was passed and none is configured for Apple Pay in the Braintree gateway")
    }
    guard !paymentRequest.supportedNetworks.isEmpty else {
        return applePayErrorResult(.APPLE_PAY_CONFIGURATION_ERROR, nativeError: "No supportedNetworks were passed and none are configured for Apple Pay in the Braintree gateway")
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
