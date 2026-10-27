import Braintree
import Foundation
import NitroModules
import PassKit

final class ApplePayPaymentSession: NSObject, PKPaymentAuthorizationControllerDelegate {
    private let applePayClient: BTApplePayClient
    private let requestOptions: ApplePayRequestOptions
    private let resultHandler: ApplePayResultHandler
    private var controller: PKPaymentAuthorizationController?
    private var lastTokenizationError: String?

    init(
        clientToken: String,
        requestOptions: ApplePayRequestOptions,
        promise: Promise<Dictionary<String, String>>,
        onFinish: @escaping () -> Void
    ) {
        self.applePayClient = BTApplePayClient(authorization: clientToken)
        self.requestOptions = requestOptions
        self.resultHandler = ApplePayResultHandler(onFinish: onFinish) { result in
            promise.resolve(withResult: result)
        }
    }

    func start() {
        applePayClient.makePaymentRequest { paymentRequest, error in
            guard let paymentRequest = paymentRequest else {
                self.finish(with: applePayErrorResult(.APPLE_PAY_CONFIGURATION_ERROR, nativeError: error?.localizedDescription ?? "Braintree could not create an Apple Pay payment request"))
                return
            }
            self.requestOptions.apply(to: paymentRequest)
            self.present(paymentRequest)
        }
    }

    private func present(_ paymentRequest: PKPaymentRequest) {
        if let error = applePayPaymentRequestError(paymentRequest) {
            finish(with: error)
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

    private func finish(with result: Dictionary<String, String>) {
        controller?.delegate = nil
        controller = nil
        resultHandler.finish(with: result)
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
            if let cardNonce = cardNonce {
                self.lastTokenizationError = nil
                self.resultHandler.recordSuccess(prepareBTApplePayNonceResult(
                    cardNonce: cardNonce,
                    payment: payment,
                    shippingMethodAmounts: self.requestOptions.shippingMethodAmounts
                ).toSwiftDict())
                completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
            } else {
                self.lastTokenizationError = error?.localizedDescription ?? "Braintree returned neither a nonce nor an error"
                completion(PKPaymentAuthorizationResult(status: .failure, errors: error.map { [$0] }))
            }
        }
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss {
            if let tokenizationError = self.lastTokenizationError {
                self.finish(with: applePayErrorResult(.APPLE_PAY_TOKENIZATION_ERROR, nativeError: tokenizationError))
            } else {
                self.finish(with: applePayErrorResult(.APPLE_PAY_USER_CANCELLATION_ERROR, code: .USER_CANCEL_EXCEPTION, nativeError: "User closed the Apple Pay sheet"))
            }
        }
    }
}
