import Foundation
import XCTest

@objcMembers final class ApplePayResultHandlerTests: XCTestCase {
    func testSuccessWaitsForDismissalAndReleasesTheSessionBeforeResolving() {
        var activeSession: String? = "first"
        var events: [String] = []
        let handler = ApplePayResultHandler(onFinish: {
            activeSession = nil
            events.append("release")
        }, resolve: { result in
            XCTAssertNil(activeSession)
            XCTAssertEqual(result, ["nonce": "authorized"])
            activeSession = "follow-up"
            events.append("resolve")
        })

        handler.recordSuccess(["nonce": "authorized"])
        XCTAssertEqual(activeSession, "first")
        XCTAssertTrue(events.isEmpty)

        handler.finish(with: ["error": "cancelled"])
        XCTAssertEqual(activeSession, "follow-up")
        XCTAssertEqual(events, ["release", "resolve"])
    }

    func testFailureResolvesOnceAndIgnoresLateTokenizationCallbacks() {
        var releases = 0
        var results: [[String: String]] = []
        let handler = ApplePayResultHandler(onFinish: { releases += 1 }, resolve: { results.append($0) })

        handler.finish(with: ["error": "cancelled"])
        handler.recordSuccess(["nonce": "too-late"])
        handler.finish(with: ["error": "different"])

        XCTAssertEqual(releases, 1)
        XCTAssertEqual(results, [["error": "cancelled"]])
    }

    func testDismissalDuringTokenizationReportsAnInterruptedAttempt() {
        var results: [[String: String]] = []
        let handler = ApplePayResultHandler(onFinish: {}, resolve: { results.append($0) })
        handler.beginTokenization()
        handler.beginDismissal()
        XCTAssertFalse(handler.isActive)
        handler.recordSuccess(["nonce": "during-dismissal"])
        handler.finishAfterDismissal()
        handler.recordSuccess(["nonce": "too-late"])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0]["message"], ERROR_TYPES.APPLE_PAY_TOKENIZATION_ERROR.rawValue)
        XCTAssertNotEqual(results[0]["code"], EXCEPTION_TYPES.USER_CANCEL_EXCEPTION.rawValue)
    }

    func testDismissalWithoutAuthorizationIsStillCancellation() {
        var result: [String: String] = [:]
        let handler = ApplePayResultHandler(onFinish: {}, resolve: { result = $0 })
        handler.beginDismissal()
        handler.finishAfterDismissal()
        XCTAssertEqual(result["message"], ERROR_TYPES.APPLE_PAY_USER_CANCELLATION_ERROR.rawValue)
    }

    func testATokenizationRetryCanSucceedBeforeDismissal() {
        var result: [String: String] = [:]
        let handler = ApplePayResultHandler(onFinish: {}, resolve: { result = $0 })
        handler.beginTokenization()
        handler.recordFailure("First card failed")
        handler.beginTokenization()
        handler.recordSuccess(["nonce": "retry"])
        handler.beginDismissal()
        handler.finishAfterDismissal()
        XCTAssertEqual(result, ["nonce": "retry"])
    }

    func testLostDismissalCompletionStillSettlesAndReleasesTheSession() {
        var fallback: (() -> Void)?
        var completions: [[String: String]] = []
        var events: [String] = []
        let handler = ApplePayResultHandler(onFinish: { events.append("release") }, resolve: { completions.append($0); events.append("resolve") })
        handler.recordSuccess(["nonce": "authorized"])
        handler.dismiss(request: { _ in }, cleanup: { events.append("cleanup") }, scheduleFallback: { fallback = $0 })
        XCTAssertTrue(completions.isEmpty)
        fallback?()
        fallback?()
        XCTAssertEqual(completions, [["nonce": "authorized"]])
        XCTAssertEqual(events, ["cleanup", "release", "resolve"])
    }

    func testCompletionAndTimeoutCannotFinishTheSessionTwice() {
        var callback: (() -> Void)?
        var fallback: (() -> Void)?
        var count = 0
        let handler = ApplePayResultHandler(onFinish: {}, resolve: { _ in count += 1 })
        handler.dismiss(request: { callback = $0 }, cleanup: {}, scheduleFallback: { fallback = $0 })
        callback?()
        fallback?()
        callback?()
        XCTAssertEqual(count, 1)
    }

    func testTheFirstAuthorizedResultIsRetained() {
        var results: [[String: String]] = []
        let handler = ApplePayResultHandler(onFinish: {}, resolve: { results.append($0) })
        handler.recordSuccess(["nonce": "first"])
        handler.recordSuccess(["nonce": "second"])
        handler.finish(with: ["error": "cancelled"])
        XCTAssertEqual(results, [["nonce": "first"]])
    }
}
