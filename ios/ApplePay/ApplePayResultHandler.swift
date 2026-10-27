import Foundation

final class ApplePayResultHandler {
    private enum State {
        case ready
        case tokenizing
        case failed([String: String])
        case authorized([String: String])
        case dismissing([String: String])
        case finished
    }

    private let onFinish: () -> Void
    private let resolve: ([String: String]) -> Void
    private var state: State = .ready

    var isActive: Bool {
        switch state {
        case .dismissing, .finished: return false
        default: return true
        }
    }

    init(onFinish: @escaping () -> Void, resolve: @escaping ([String: String]) -> Void) {
        self.onFinish = onFinish
        self.resolve = resolve
    }

    func recordSuccess(_ result: [String: String]) {
        switch state {
        case .ready, .tokenizing, .failed: state = .authorized(result)
        default: return
        }
    }

    @discardableResult func beginTokenization() -> Bool {
        switch state {
        case .ready, .failed: state = .tokenizing; return true
        default: return false
        }
    }

    func recordFailure(_ message: String) {
        recordFailure(applePayErrorResult(.APPLE_PAY_TOKENIZATION_ERROR, nativeError: message))
    }

    func recordFailure(_ result: [String: String]) {
        switch state {
        case .ready, .tokenizing, .failed: state = .failed(result)
        default: return
        }
    }

    @discardableResult func beginDismissal() -> Bool {
        let result: [String: String]
        switch state {
        case .authorized(let success): result = success
        case .tokenizing:
            result = applePayErrorResult(.APPLE_PAY_TOKENIZATION_ERROR, nativeError: "The Apple Pay sheet closed before tokenization completed")
        case .failed(let failure): result = failure
        case .ready:
            result = applePayErrorResult(.APPLE_PAY_USER_CANCELLATION_ERROR, code: .USER_CANCEL_EXCEPTION, nativeError: "User closed the Apple Pay sheet")
        case .dismissing, .finished: return false
        }
        state = .dismissing(result)
        return true
    }

    func dismiss(
        request: (@escaping () -> Void) -> Void,
        cleanup: @escaping () -> Void,
        scheduleFallback: (@escaping () -> Void) -> Void = { completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: completion)
        }
    ) {
        guard beginDismissal() else { return }
        let complete = { [weak self] in
            guard let self = self, case .dismissing = self.state else { return }
            cleanup()
            self.finishAfterDismissal()
        }
        scheduleFallback(complete)
        request(complete)
    }

    func finishAfterDismissal() {
        guard case .dismissing(let result) = state else { return }
        finish(with: result)
    }

    func finish(with fallback: [String: String]) {
        let result: [String: String]
        switch state {
        case .finished: return
        case .authorized(let success), .dismissing(let success): result = success
        default: result = fallback
        }
        state = .finished
        onFinish()
        resolve(result)
    }
}
