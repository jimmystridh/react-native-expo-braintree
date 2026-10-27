import Foundation
import PassKit

func applePayCredentialError(_ authorization: String) -> [String: String]? {
    if authorization.range(of: #"\A(sandbox|production|development)_[A-Za-z0-9]+_[A-Za-z0-9_]+\z"#, options: .regularExpression) != nil { return nil }
    let encoded = Data(base64Encoded: authorization)
    let data = encoded ?? Data(authorization.utf8)
    if let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
       let version = object["version"] as? Int,
       (version == 1 && encoded == nil) || ([2, 3].contains(version) && encoded != nil),
       let fingerprint = object["authorizationFingerprint"] as? String,
       !fingerprint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
       let configURL = object["configUrl"] as? String,
       let url = URL(string: configURL), let scheme = url.scheme,
       ["http", "https"].contains(scheme), url.host != nil {
        return nil
    }
    return applePayErrorResult(.APPLE_PAY_CONFIGURATION_ERROR, nativeError: "clientToken is missing or malformed. Obtain a valid client token or tokenization key from your server before retrying.")
}

private enum ApplePayGatewayFailureKind {
    case credentials
    case configuration
    case merchantDisabled
    case request
}

private func applePayGatewayFailureKind(_ error: NSError) -> ApplePayGatewayFailureKind {
    switch error.domain {
    case "com.braintreepayments.BTClientTokenErrorDomain":
        return .credentials
    case "com.braintreepayments.BTAPIClientErrorDomain":
        return [1, 3, 4].contains(error.code) ? .credentials : .request
    case "com.braintreepayments.BTApplePayErrorDomain":
        return error.code == 1 ? .merchantDisabled : .request
    case "com.braintreepayments.BTHTTPErrorDomain":
        if error.code == 10 { return .credentials }
        if let response = error.userInfo.values.compactMap({ $0 as? HTTPURLResponse }).first {
            if response.statusCode == 401 || response.statusCode == 403 { return .credentials }
            if response.statusCode == 429 || response.statusCode >= 500 { return .request }
        }
        return [2, 4, 8, 9, 10, 11].contains(error.code) ? .configuration : .request
    default:
        return .request
    }
}

func applePayGatewayFailure(_ error: Error?) -> [String: String] {
    guard let error = error as NSError? else {
        return applePayErrorResult(.APPLE_PAY_REQUEST_ERROR, nativeError: "Braintree could not create an Apple Pay payment request")
    }
    switch applePayGatewayFailureKind(error) {
    case .credentials:
        return applePayErrorResult(.APPLE_PAY_CONFIGURATION_ERROR, nativeError: "clientToken is invalid, expired, or unauthorized. Obtain a new client token from your server before retrying.")
    case .configuration, .merchantDisabled:
        return applePayErrorResult(.APPLE_PAY_CONFIGURATION_ERROR, nativeError: error.localizedDescription)
    case .request:
        return applePayErrorResult(.APPLE_PAY_REQUEST_ERROR, nativeError: error.localizedDescription)
    }
}

func applePayTokenizationFailure(_ error: Error?) -> [String: String] {
    if let error = error as NSError? {
        switch applePayGatewayFailureKind(error) {
        case .credentials, .merchantDisabled: return applePayGatewayFailure(error)
        default: break
        }
    }
    return applePayErrorResult(.APPLE_PAY_TOKENIZATION_ERROR, nativeError: error?.localizedDescription ?? "Braintree returned neither a nonce nor an error")
}

func applePayAuthorizationFailure() -> PKPaymentAuthorizationResult {
    let error = NSError(
        domain: PKPaymentErrorDomain,
        code: PKPaymentError.Code.unknownError.rawValue,
        userInfo: [NSLocalizedDescriptionKey: "Payment authorization failed. Please try again."]
    )
    return PKPaymentAuthorizationResult(status: .failure, errors: [error])
}
