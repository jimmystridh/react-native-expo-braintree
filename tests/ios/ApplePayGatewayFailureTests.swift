import Foundation
import XCTest

@objcMembers final class ApplePayGatewayFailureTests: XCTestCase {
    func testCredentialFormatsMatchThePinnedSDK() throws {
        for version in [1, 2, 3] {
            let data = try JSONSerialization.data(withJSONObject: ["version": version, "authorizationFingerprint": "fingerprint", "configUrl": "https://example.com/config"])
            let token = version == 1 ? String(data: data, encoding: .utf8)! : data.base64EncodedString()
            XCTAssertNil(applePayCredentialError(token))
        }
        XCTAssertNil(applePayCredentialError("sandbox_public_merchant"))
        XCTAssertNil(applePayCredentialError("production_public_merchant"))
        for value in ["", " ", "test", "order123", "not-a-token", "{}"] {
            XCTAssertEqual(applePayCredentialError(value)?["message"], ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue)
        }
    }

    func testMalformedCredentialsAreConfigurationErrorsAndDoNotEchoTheToken() {
        for (domain, code) in [
            ("com.braintreepayments.BTAPIClientErrorDomain", 4),
            ("com.braintreepayments.BTAPIClientErrorDomain", 1),
            ("com.braintreepayments.BTClientTokenErrorDomain", 0),
        ] {
            let result = applePayGatewayFailure(NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: "Invalid authorization: secret-token"]))
            XCTAssertEqual(result["message"], ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue)
            XCTAssertTrue(result["nativeError"]?.contains("clientToken") == true)
            XCTAssertFalse(result["nativeError"]?.contains("secret-token") == true)
        }
    }

    func testExpiredCredentialsAndForbiddenRequestsRequireNewAuthorization() {
        for status in [401, 403] {
            let response = HTTPURLResponse(url: URL(string: "https://example.com/config")!, statusCode: status, httpVersion: nil, headerFields: nil)!
            let result = applePayGatewayFailure(NSError(domain: "com.braintreepayments.BTHTTPErrorDomain", code: 2, userInfo: ["com.braintreepayments.BTHTTPURLResponseKey": response]))
            XCTAssertEqual(result["message"], ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue)
            XCTAssertTrue(result["nativeError"]?.contains("clientToken") == true)
        }
    }

    func testCredentialsThatExpireDuringTokenizationKeepTheirConfigurationError() {
        var result: [String: String] = [:]
        let handler = ApplePayResultHandler(onFinish: {}, resolve: { result = $0 })
        handler.beginTokenization()
        handler.recordFailure(applePayTokenizationFailure(NSError(domain: "com.braintreepayments.BTAPIClientErrorDomain", code: 4)))
        handler.beginDismissal()
        handler.finishAfterDismissal()
        XCTAssertEqual(result["message"], ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue)
        XCTAssertTrue(result["nativeError"]?.contains("clientToken") == true)
        XCTAssertEqual(applePayTokenizationFailure(NSError(domain: "com.braintreepayments.BTHTTPErrorDomain", code: 2))["message"], ERROR_TYPES.APPLE_PAY_TOKENIZATION_ERROR.rawValue)
    }

    func testOfflineRateLimitAndServerErrorsRemainRequestErrors() {
        for error in [
            NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet),
            NSError(domain: "com.braintreepayments.BTHTTPErrorDomain", code: 5),
            NSError(domain: "com.braintreepayments.BTHTTPErrorDomain", code: 3),
            NSError(domain: "com.braintreepayments.BTHTTPErrorDomain", code: 2, userInfo: ["com.braintreepayments.BTHTTPURLResponseKey": HTTPURLResponse(url: URL(string: "https://example.com/config")!, statusCode: 500, httpVersion: nil, headerFields: nil)!]),
        ] {
            XCTAssertEqual(applePayGatewayFailure(error)["message"], ERROR_TYPES.APPLE_PAY_REQUEST_ERROR.rawValue)
        }
    }
}
