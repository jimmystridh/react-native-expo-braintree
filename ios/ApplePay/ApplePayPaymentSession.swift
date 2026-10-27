import Braintree
import Foundation
import NitroModules
import PassKit

final class ApplePayPaymentSession: NSObject, PKPaymentAuthorizationControllerDelegate {
    private let applePayClient: BTApplePayClient
    private let requestOptions: ApplePayRequestOptions
    private let resultHandler: ApplePayResultHandler
    private var controller: PKPaymentAuthorizationController?
    private var summaryItems: [PKPaymentSummaryItem]
    private var currencyCode: String?

    init(
        clientToken: String,
        requestOptions: ApplePayRequestOptions,
        promise: Promise<Dictionary<String, String>>,
        onFinish: @escaping () -> Void
    ) {
        self.applePayClient = BTApplePayClient(authorization: clientToken)
        self.requestOptions = requestOptions
        self.summaryItems = requestOptions.paymentSummaryItems
        self.resultHandler = ApplePayResultHandler(onFinish: onFinish) { result in
            promise.resolve(withResult: result)
        }
    }

    func start() {
        applePayClient.makePaymentRequest { paymentRequest, error in
            guard let paymentRequest = paymentRequest else {
                let category: ERROR_TYPES = (error as? BTApplePayError) == .unsupported ? .APPLE_PAY_CONFIGURATION_ERROR : .APPLE_PAY_REQUEST_ERROR
                self.finish(with: applePayErrorResult(category, nativeError: error?.localizedDescription ?? "Braintree could not create an Apple Pay payment request"))
                return
            }
            self.requestOptions.apply(to: paymentRequest)
            do {
                try self.requestOptions.validateAmounts(currencyCode: paymentRequest.currencyCode)
                self.present(paymentRequest)
            } catch {
                self.finish(with: applePayErrorResult(.APPLE_PAY_CONFIGURATION_ERROR, nativeError: error.localizedDescription))
            }
        }
    }

    private func present(_ paymentRequest: PKPaymentRequest) {
        if let error = applePayPaymentRequestError(paymentRequest) {
            finish(with: error)
            return
        }
        currencyCode = paymentRequest.currencyCode
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
        do {
            summaryItems = try requestOptions.summaryItems(for: shippingMethod)
            completion(PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: summaryItems))
        } catch {
            let update = PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: summaryItems)
            update.status = .failure
            completion(update)
        }
    }

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        resultHandler.beginTokenization()
        let authorizedTotal = summaryItems.last
        applePayClient.tokenize(payment) { cardNonce, error in
            guard self.resultHandler.isActive else { return }
            if let cardNonce = cardNonce {
                do {
                    self.resultHandler.recordSuccess(try prepareBTApplePayNonceResult(
                        cardNonce: cardNonce,
                        payment: payment,
                        shippingMethodAmounts: self.requestOptions.shippingMethodAmounts,
                        authorizedTotal: authorizedTotal,
                        currencyCode: self.currencyCode
                    ).toSwiftDict())
                    completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
                } catch {
                    self.resultHandler.recordFailure(error.localizedDescription)
                    completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                }
            } else {
                self.resultHandler.recordFailure(error?.localizedDescription ?? "Braintree returned neither a nonce nor an error")
                completion(PKPaymentAuthorizationResult(status: .failure, errors: error.map { [$0] }))
            }
        }
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        resultHandler.beginDismissal()
        controller.dismiss {
            self.controller?.delegate = nil
            self.controller = nil
            self.resultHandler.finishAfterDismissal()
        }
    }
}
