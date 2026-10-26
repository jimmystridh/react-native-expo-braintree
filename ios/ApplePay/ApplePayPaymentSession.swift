import Braintree
import Foundation
import NitroModules
import PassKit

final class ApplePayPaymentSession: NSObject, PKPaymentAuthorizationControllerDelegate {
    private let applePayClient: BTApplePayClient
    private let requestOptions: ApplePayRequestOptions
    private let promise: Promise<Dictionary<String, String>>
    private let onFinish: () -> Void
    private var controller: PKPaymentAuthorizationController?
    private var lastTokenizationError: String?
    private var isSettled = false

    init(
        clientToken: String,
        requestOptions: ApplePayRequestOptions,
        promise: Promise<Dictionary<String, String>>,
        onFinish: @escaping () -> Void
    ) {
        self.applePayClient = BTApplePayClient(authorization: clientToken)
        self.requestOptions = requestOptions
        self.promise = promise
        self.onFinish = onFinish
    }

    func start() {
        applePayClient.makePaymentRequest { paymentRequest, error in
            DispatchQueue.main.async {
                guard let paymentRequest = paymentRequest else {
                    self.finish(with: applePayErrorResult(.APPLE_PAY_CONFIGURATION_ERROR, nativeError: error?.localizedDescription ?? "Braintree could not create an Apple Pay payment request"))
                    return
                }
                self.requestOptions.apply(to: paymentRequest)
                self.present(paymentRequest)
            }
        }
    }

    private func present(_ paymentRequest: PKPaymentRequest) {
        guard !paymentRequest.merchantIdentifier.isEmpty else {
            finish(with: applePayErrorResult(.APPLE_PAY_CONFIGURATION_ERROR, nativeError: "No merchantIdentifier was passed and none is configured for Apple Pay in the Braintree gateway"))
            return
        }
        guard PKPaymentAuthorizationController.canMakePayments(usingNetworks: paymentRequest.supportedNetworks) else {
            finish(with: applePayErrorResult(.APPLE_PAY_NOT_AVAILABLE_ERROR, nativeError: "No card in Wallet matches the supported networks"))
            return
        }
        let controller = PKPaymentAuthorizationController(paymentRequest: paymentRequest)
        controller.delegate = self
        self.controller = controller
        controller.present { presented in
            if !presented {
                self.finish(with: applePayErrorResult(.APPLE_PAY_PRESENTATION_ERROR, nativeError: "The Apple Pay sheet could not be presented"))
            }
        }
    }

    private func settle(with result: Dictionary<String, String>) {
        guard !isSettled else { return }
        isSettled = true
        promise.resolve(withResult: result)
    }

    private func finish(with result: Dictionary<String, String>) {
        settle(with: result)
        controller?.delegate = nil
        controller = nil
        onFinish()
    }

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didSelectShippingMethod shippingMethod: PKShippingMethod,
        handler completion: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void
    ) {
        let summaryItems = prepareApplePaySummaryItems(
            summaryItems: requestOptions.paymentSummaryItems,
            defaultShippingMethod: requestOptions.shippingMethods.first,
            selectedShippingMethod: shippingMethod
        )
        completion(PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: summaryItems))
    }

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        applePayClient.tokenize(payment) { cardNonce, error in
            DispatchQueue.main.async {
                if let cardNonce = cardNonce {
                    self.settle(with: prepareBTApplePayNonceResult(cardNonce: cardNonce, payment: payment).toSwiftDict())
                    completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
                } else {
                    self.lastTokenizationError = error?.localizedDescription ?? "Braintree returned neither a nonce nor an error"
                    completion(PKPaymentAuthorizationResult(status: .failure, errors: error.map { [$0] }))
                }
            }
        }
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss {
            DispatchQueue.main.async {
                if let tokenizationError = self.lastTokenizationError {
                    self.finish(with: applePayErrorResult(.APPLE_PAY_TOKENIZATION_ERROR, nativeError: tokenizationError))
                } else {
                    self.finish(with: applePayErrorResult(.APPLE_PAY_USER_CANCELLATION_ERROR, code: .USER_CANCEL_EXCEPTION, nativeError: "User closed the Apple Pay sheet"))
                }
            }
        }
    }
}
