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

    func testTheFirstAuthorizedResultIsRetained() {
        var results: [[String: String]] = []
        let handler = ApplePayResultHandler(onFinish: {}, resolve: { results.append($0) })
        handler.recordSuccess(["nonce": "first"])
        handler.recordSuccess(["nonce": "second"])
        handler.finish(with: ["error": "cancelled"])
        XCTAssertEqual(results, [["nonce": "first"]])
    }
}
