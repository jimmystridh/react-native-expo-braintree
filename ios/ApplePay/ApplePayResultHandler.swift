import Foundation

final class ApplePayResultHandler {
    private let onFinish: () -> Void
    private let resolve: ([String: String]) -> Void
    private var success: [String: String]?
    private var isFinished = false
    private var isTokenizing = false
    private var tokenizationError: String?
    private var isDismissing = false

    var isActive: Bool { !isFinished && !isDismissing }

    init(onFinish: @escaping () -> Void, resolve: @escaping ([String: String]) -> Void) {
        self.onFinish = onFinish
        self.resolve = resolve
    }

    func recordSuccess(_ result: [String: String]) {
        guard isActive, success == nil else { return }
        success = result
        isTokenizing = false
        tokenizationError = nil
    }

    func beginTokenization() {
        guard isActive else { return }
        isTokenizing = true
        tokenizationError = nil
    }

    func recordFailure(_ message: String) {
        guard isActive else { return }
        isTokenizing = false
        tokenizationError = message
    }

    func beginDismissal() {
        isDismissing = true
    }

    func finishAfterDismissal() {
        beginDismissal()
        if isTokenizing || tokenizationError != nil {
            finish(with: applePayErrorResult(.APPLE_PAY_TOKENIZATION_ERROR, nativeError: tokenizationError ?? "The Apple Pay sheet closed before tokenization completed"))
        } else {
            finish(with: applePayErrorResult(.APPLE_PAY_USER_CANCELLATION_ERROR, code: .USER_CANCEL_EXCEPTION, nativeError: "User closed the Apple Pay sheet"))
        }
    }

    func finish(with fallback: [String: String]) {
        guard !isFinished else { return }
        isFinished = true
        let result = success ?? fallback
        success = nil
        onFinish()
        resolve(result)
    }
}
