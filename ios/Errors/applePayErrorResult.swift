import Foundation

func applePayErrorResult(
    _ message: ERROR_TYPES,
    code: EXCEPTION_TYPES = .SWIFT_EXCEPTION,
    nativeError: String
) -> Dictionary<String, String> {
    return ["error": "true", "code": code.rawValue, "message": message.rawValue, "domain": message.rawValue, "nativeError": nativeError]
}
