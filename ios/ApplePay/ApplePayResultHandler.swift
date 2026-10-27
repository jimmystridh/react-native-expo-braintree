import Foundation

final class ApplePayResultHandler {
    private let onFinish: () -> Void
    private let resolve: ([String: String]) -> Void
    private var success: [String: String]?
    private var isFinished = false

    init(onFinish: @escaping () -> Void, resolve: @escaping ([String: String]) -> Void) {
        self.onFinish = onFinish
        self.resolve = resolve
    }

    func recordSuccess(_ result: [String: String]) {
        guard !isFinished, success == nil else { return }
        success = result
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
