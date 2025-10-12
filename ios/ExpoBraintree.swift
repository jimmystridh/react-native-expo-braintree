//
//  BTPayPalVaultRequest.swift
//  expo-braintree
//
//  Created by Maciej Sasinowski on 28/04/2024.
//

import Braintree
import Contacts
import Foundation
import PassKit
import React

enum EXCEPTION_TYPES: String {
  case SWIFT_EXCEPTION = "ReactNativeExpoBraintree:`SwiftException"
  case USER_CANCEL_EXCEPTION = "ReactNativeExpoBraintree:`UserCancelException"
  case TOKENIZE_EXCEPTION = "ReactNativeExpoBraintree:`TokenizeException"
  case PAYPAL_DISABLED_IN_CONFIGURATION =
    "ReactNativeExpoBraintree:`Paypal disabled in configuration"
  case VENMO_DISABLED_IN_CONFIGURATION =
    "ReactNativeExpoBraintree:`Venmo disabled in configuration"
}

enum ERROR_TYPES: String {
  case API_CLIENT_INITIALIZATION_ERROR = "API_CLIENT_INITIALIZATION_ERROR"
  case TOKENIZE_VAULT_PAYMENT_ERROR = "TOKENIZE_VAULT_PAYMENT_ERROR"
  case USER_CANCEL_TRANSACTION_ERROR = "USER_CANCEL_TRANSACTION_ERROR"
  case PAYPAL_DISABLED_IN_CONFIGURATION_ERROR = "PAYPAL_DISABLED_IN_CONFIGURATION_ERROR"
  case VENMO_DISABLED_IN_CONFIGURATION_ERROR = "VENMO_DISABLED_IN_CONFIGURATION_ERROR"
  case DATA_COLLECTOR_ERROR = "DATA_COLLECTOR_ERROR"
  case CARD_TOKENIZATION_ERROR = "CARD_TOKENIZATION_ERROR"
  case APPLE_PAY_NOT_AVAILABLE_ERROR = "APPLE_PAY_NOT_AVAILABLE_ERROR"
  case APPLE_PAY_CONFIGURATION_ERROR = "APPLE_PAY_CONFIGURATION_ERROR"
  case APPLE_PAY_PRESENTATION_ERROR = "APPLE_PAY_PRESENTATION_ERROR"
  case APPLE_PAY_TOKENIZATION_ERROR = "APPLE_PAY_TOKENIZATION_ERROR"
  case APPLE_PAY_USER_CANCELLATION_ERROR = "APPLE_PAY_USER_CANCELLATION_ERROR"
}

@objc(ExpoBraintree)
class ExpoBraintree: NSObject {

  private var applePayResolver: RCTPromiseResolveBlock?
  private var applePayRejecter: RCTPromiseRejectBlock?
  private var applePayController: PKPaymentAuthorizationController?
  private var applePayClient: BTApplePayClient?
  private var applePayDidSucceed = false

  private func stringOptions(from options: [String: Any]) -> [String: String] {
    var result: [String: String] = [:]
    for (key, value) in options {
      if let stringValue = value as? String {
        result[key] = stringValue
      }
    }
    return result
  }

  private func resetApplePayState() {
    applePayController = nil
    applePayClient = nil
    applePayResolver = nil
    applePayRejecter = nil
    applePayDidSucceed = false
  }

  private func rejectApplePay(
    code: EXCEPTION_TYPES,
    message: ERROR_TYPES,
    underlyingError: Error? = nil
  ) {
    let nsError: NSError
    if let error = underlyingError {
      nsError = error as NSError
    } else {
      nsError = NSError(domain: message.rawValue, code: -1)
    }
    applePayRejecter?(code.rawValue, message.rawValue, nsError)
    applePayResolver = nil
    applePayRejecter = nil
  }

  @objc(requestBillingAgreement:withResolver:withRejecter:)
  func requestBillingAgreement(
    options: [String: Any], resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    let mappedOptions = stringOptions(from: options)
    let clientToken = mappedOptions["clientToken"] ?? ""
    // Step 1: Initialize Braintree API Client
    let apiClientOptional = BTAPIClient(authorization: clientToken)
    guard let apiClient = apiClientOptional else {
      return reject(
        EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
        ERROR_TYPES.API_CLIENT_INITIALIZATION_ERROR.rawValue,
        NSError(domain: ERROR_TYPES.API_CLIENT_INITIALIZATION_ERROR.rawValue, code: -1))
    }
    // Step 2: Initialize BPayPal API Client
    let payPalClient = BTPayPalClient(apiClient: apiClient)
    let vaultRequest = prepareBTPayPalVaultRequest(options: mappedOptions)
    payPalClient.tokenize(vaultRequest) {
      (accountNonce, error) -> Void in
      if let accountNonce = accountNonce {
        // Step 3: Handle Success: Paypal Nonce Created resolved
        return resolve(
          prepareBTPayPalAccountNonceResult(
            accountNonce: accountNonce
          ))
      } else if let error = error as? BTPayPalError {
        // Step 3: Handle Error: Tokenize error
        switch error.errorCode {
        case BTPayPalError.disabled.errorCode:
          return reject(
            EXCEPTION_TYPES.PAYPAL_DISABLED_IN_CONFIGURATION.rawValue,
            ERROR_TYPES.USER_CANCEL_TRANSACTION_ERROR.rawValue,
            NSError(
              domain: ERROR_TYPES.PAYPAL_DISABLED_IN_CONFIGURATION_ERROR.rawValue,
              code: BTPayPalError.disabled.errorCode)
          )
        case BTPayPalError.canceled.errorCode:
          return reject(
            EXCEPTION_TYPES.USER_CANCEL_EXCEPTION.rawValue,
            ERROR_TYPES.USER_CANCEL_TRANSACTION_ERROR.rawValue,
            NSError(
              domain: ERROR_TYPES.USER_CANCEL_TRANSACTION_ERROR.rawValue,
              code: BTPayPalError.canceled.errorCode)
          )
        default:
          return reject(
            EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
            ERROR_TYPES.TOKENIZE_VAULT_PAYMENT_ERROR.rawValue,
            NSError(
              domain: error.localizedDescription,
              code: -1
            )
          )
        }
      }
    }
  }

  @objc(requestOneTimePayment:withResolver:withRejecter:)
  func requestOneTimePayment(
    options: [String: Any], resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    let mappedOptions = stringOptions(from: options)
    let clientToken = mappedOptions["clientToken"] ?? ""
    // Step 1: Initialize Braintree API Client
    let apiClientOptional = BTAPIClient(authorization: clientToken)
    guard let apiClient = apiClientOptional else {
      return reject(
        EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
        ERROR_TYPES.API_CLIENT_INITIALIZATION_ERROR.rawValue,
        NSError(domain: ERROR_TYPES.API_CLIENT_INITIALIZATION_ERROR.rawValue, code: -1))
    }
    // Step 2: Initialize BPayPal API Client
    let payPalClient = BTPayPalClient(apiClient: apiClient)
    let checkoutRequest = prepareBTPayPalCheckoutRequest(options: mappedOptions)
    payPalClient.tokenize(checkoutRequest) {
      (accountNonce, error) -> Void in
      if let accountNonce = accountNonce {
        // Step 3: Handle Success: Paypal Nonce Created resolved
        return resolve(
          prepareBTPayPalAccountNonceResult(
            accountNonce: accountNonce
          ))
      } else if let error = error as? BTPayPalError {
        // Step 3: Handle Error: Tokenize error
        switch error.errorCode {
        case BTPayPalError.disabled.errorCode:
          return reject(
            EXCEPTION_TYPES.PAYPAL_DISABLED_IN_CONFIGURATION.rawValue,
            ERROR_TYPES.USER_CANCEL_TRANSACTION_ERROR.rawValue,
            NSError(
              domain: ERROR_TYPES.PAYPAL_DISABLED_IN_CONFIGURATION_ERROR.rawValue,
              code: BTPayPalError.disabled.errorCode)
          )
        case BTPayPalError.canceled.errorCode:
          return reject(
            EXCEPTION_TYPES.USER_CANCEL_EXCEPTION.rawValue,
            ERROR_TYPES.USER_CANCEL_TRANSACTION_ERROR.rawValue,
            NSError(
              domain: ERROR_TYPES.USER_CANCEL_TRANSACTION_ERROR.rawValue,
              code: BTPayPalError.canceled.errorCode)
          )
        default:
          return reject(
            EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
            ERROR_TYPES.TOKENIZE_VAULT_PAYMENT_ERROR.rawValue,
            NSError(
              domain: error.localizedDescription,
              code: -1
            )
          )
        }
      }
    }
  }

  @objc(requestApplePayNonce:withResolver:withRejecter:)
  func requestApplePayNonce(
    options: [String: Any], resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    if applePayResolver != nil {
      return reject(
        EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
        ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue,
        NSError(domain: ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue, code: -1)
      )
    }

    guard PKPaymentAuthorizationController.canMakePayments() else {
      return reject(
        EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
        ERROR_TYPES.APPLE_PAY_NOT_AVAILABLE_ERROR.rawValue,
        NSError(domain: ERROR_TYPES.APPLE_PAY_NOT_AVAILABLE_ERROR.rawValue, code: -1)
      )
    }

    guard
      let clientToken = options["clientToken"] as? String,
      !clientToken.isEmpty
    else {
      return reject(
        EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
        ERROR_TYPES.API_CLIENT_INITIALIZATION_ERROR.rawValue,
        NSError(domain: ERROR_TYPES.API_CLIENT_INITIALIZATION_ERROR.rawValue, code: -1)
      )
    }

    guard
      let merchantIdentifier = options["merchantIdentifier"] as? String,
      !merchantIdentifier.isEmpty,
      let countryCode = options["countryCode"] as? String,
      !countryCode.isEmpty,
      let currencyCode = options["currencyCode"] as? String,
      !currencyCode.isEmpty
    else {
      return reject(
        EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
        ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue,
        NSError(domain: ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue, code: -1)
      )
    }

    let supportedNetworkStrings = options["supportedNetworks"] as? [String] ?? []
    let supportedNetworks = mapSupportedNetworks(from: supportedNetworkStrings)

    guard !supportedNetworks.isEmpty else {
      return reject(
        EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
        ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue,
        NSError(domain: ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue, code: -1)
      )
    }

    guard PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks) else {
      return reject(
        EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
        ERROR_TYPES.APPLE_PAY_NOT_AVAILABLE_ERROR.rawValue,
        NSError(domain: ERROR_TYPES.APPLE_PAY_NOT_AVAILABLE_ERROR.rawValue, code: -1)
      )
    }

    let summaryItemDictionaries = (options["paymentSummaryItems"] as? [Any] ?? [])
      .compactMap { $0 as? [String: Any] }

    do {
      let paymentSummaryItems = try mapSummaryItems(from: summaryItemDictionaries)
      let merchantCapabilities = mapMerchantCapabilities(
        from: options["merchantCapabilities"] as? [String]
      )
      let requiredBillingFields = mapContactFields(
        from: options["requiredBillingContactFields"] as? [String]
      )
      let requiredShippingFields = mapContactFields(
        from: options["requiredShippingContactFields"] as? [String]
      )
      let shippingMethodDictionaries = (options["shippingMethods"] as? [Any] ?? [])
        .compactMap { $0 as? [String: Any] }
      let shippingMethods = mapShippingMethods(from: shippingMethodDictionaries)
      let billingContact = mapContact(from: options["billingContact"] as? [String: Any])
      let shippingContact = mapContact(from: options["shippingContact"] as? [String: Any])
      let shippingType = mapShippingType(from: options["shippingType"] as? String)
      let applicationData = mapApplePayApplicationData(
        from: options["applicationData"] as? String
      )

      applePayResolver = resolve
      applePayRejecter = reject

      guard let apiClient = BTAPIClient(authorization: clientToken) else {
        applePayResolver = nil
        applePayRejecter = nil
        return reject(
          EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
          ERROR_TYPES.API_CLIENT_INITIALIZATION_ERROR.rawValue,
          NSError(domain: ERROR_TYPES.API_CLIENT_INITIALIZATION_ERROR.rawValue, code: -1)
        )
      }

      let applePayClient = BTApplePayClient(apiClient: apiClient)
      self.applePayClient = applePayClient
      applePayClient.makePaymentRequest { [weak self] request, error in
        guard let self = self else { return }
        guard let paymentRequest = request, error == nil else {
          self.rejectApplePay(
            code: .SWIFT_EXCEPTION,
            message: .APPLE_PAY_CONFIGURATION_ERROR,
            underlyingError: error
          )
          self.resetApplePayState()
          return
        }

        paymentRequest.merchantIdentifier = merchantIdentifier
        paymentRequest.countryCode = countryCode
        paymentRequest.currencyCode = currencyCode
        paymentRequest.supportedNetworks = supportedNetworks
        paymentRequest.merchantCapabilities = merchantCapabilities
        paymentRequest.paymentSummaryItems = paymentSummaryItems

        if !requiredBillingFields.isEmpty {
          paymentRequest.requiredBillingContactFields = requiredBillingFields
        }

        if !requiredShippingFields.isEmpty {
          paymentRequest.requiredShippingContactFields = requiredShippingFields
        }

        if !shippingMethods.isEmpty {
          paymentRequest.shippingMethods = shippingMethods
        }

        if let billingContact = billingContact {
          paymentRequest.billingContact = billingContact
        }

        if let shippingContact = shippingContact {
          paymentRequest.shippingContact = shippingContact
        }

        if let shippingType = shippingType {
          paymentRequest.shippingType = shippingType
        }

        if let applicationData = applicationData {
          paymentRequest.applicationData = applicationData
        }

        DispatchQueue.main.async {
          let controller = PKPaymentAuthorizationController(paymentRequest: paymentRequest)
          controller.delegate = self
          self.applePayController = controller
          self.applePayDidSucceed = false
          controller.present { presented in
            if !presented {
              controller.delegate = nil
              self.rejectApplePay(
                code: .SWIFT_EXCEPTION,
                message: .APPLE_PAY_PRESENTATION_ERROR
              )
              self.resetApplePayState()
            }
          }
        }
      }
    } catch {
      return reject(
        EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
        ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue,
        NSError(domain: ERROR_TYPES.APPLE_PAY_CONFIGURATION_ERROR.rawValue, code: -1)
      )
    }
  }

  @objc(getDeviceDataFromDataCollector:withResolver:withRejecter:)
  func getDeviceDataFromDataCollector(
    options: [String: Any], resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    // Step 1: Initialize Braintree API Client
    let mappedOptions = stringOptions(from: options)
    let clientToken = mappedOptions["clientToken"] ?? ""
    let apiClientOptional = BTAPIClient(authorization: clientToken)
    guard let apiClient = apiClientOptional else {
      return reject(
        EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
        ERROR_TYPES.API_CLIENT_INITIALIZATION_ERROR.rawValue,
        NSError(domain: ERROR_TYPES.API_CLIENT_INITIALIZATION_ERROR.rawValue, code: -1))
    }
    // Step 2: Initialize DataCollerctor
    let dataCollector = BTDataCollector(apiClient: apiClient)
    // Step 3: Try To Collect Device Data and make a corelation Id if that is possible
    dataCollector.collectDeviceData { corelationId, dataCollectorError in
      if let corelationId = corelationId {
        // Step 4: Return corelation id
        return resolve(corelationId)
      } else if let dataCollectorError = dataCollectorError {
        // Step 4: Handle Error: DataCollector error
        return reject(
          EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
          ERROR_TYPES.DATA_COLLECTOR_ERROR.rawValue,
          NSError(
            domain: ERROR_TYPES.DATA_COLLECTOR_ERROR.rawValue,
            code: -1)
        )
      }
    }
  }

  @objc(tokenizeCardData:withResolver:withRejecter:)
  func tokenizeCardData(
    options: [String: Any], resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    let mappedOptions = stringOptions(from: options)
    let clientToken = mappedOptions["clientToken"] ?? ""
    // Step 1: Initialize Braintree API Client
    let apiClientOptional = BTAPIClient(authorization: clientToken)
    guard let apiClient = apiClientOptional else {
      return reject(
        EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
        ERROR_TYPES.API_CLIENT_INITIALIZATION_ERROR.rawValue,
        NSError(domain: ERROR_TYPES.API_CLIENT_INITIALIZATION_ERROR.rawValue, code: -1))
    }
    // Step 2: Initialize DataCollerctor
    let cardClient = BTCardClient(apiClient: apiClient)
    let card = prepareCardData(options: mappedOptions)
    // Step 3: Try To Collect Device Data and make a corelation Id if that is possible
    cardClient.tokenize(card) {
      (cardNonce, error) -> Void in
      if let cardNonce = cardNonce {
        // Step 4: Return corelation id
        return resolve(prepareBTCardNonceResult(cardNonce: cardNonce))
      } else if let error = error {
        // Step 4: Handle Error: DataCollector error
        return reject(
          EXCEPTION_TYPES.TOKENIZE_EXCEPTION.rawValue,
          ERROR_TYPES.CARD_TOKENIZATION_ERROR.rawValue,
          NSError(
            domain: ERROR_TYPES.CARD_TOKENIZATION_ERROR.rawValue,
            code: -1)
        )
      }
    }
  }

  @objc(requestVenmoNonce:withResolver:withRejecter:)
  func requestVenmoNonce(
    options: [String: Any], resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    let mappedOptions = stringOptions(from: options)
    let clientToken = mappedOptions["clientToken"] ?? ""

    // Step 1: Initialize Braintree API Client
    let apiClientOptional = BTAPIClient(authorization: clientToken)
    guard let apiClient = apiClientOptional else {
      return reject(
        EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
        ERROR_TYPES.API_CLIENT_INITIALIZATION_ERROR.rawValue,
        NSError(domain: ERROR_TYPES.API_CLIENT_INITIALIZATION_ERROR.rawValue, code: -1))
    }

    // Step 2: Initialize BTVenmoClient API Client
    let venmoClient = BTVenmoClient(apiClient: apiClient)
    let vaultRequest = prepareBTVenmoRequest(options: mappedOptions)

    venmoClient.tokenize(vaultRequest) {
      (accountNonce, error) -> Void in
      if let accountNonce = accountNonce {

        // Step 3: Handle Success: Venmo Nonce Created resolved
        return resolve(
          prepareBTVenmoAccountNonceResult(
            accountNonce: accountNonce
          ))
      } else if let error = error as? BTVenmoError {
        // Step 3: Handle Error: Tokenize error
        switch error.errorCode {
        case BTVenmoError.disabled.errorCode:
          return reject(
            EXCEPTION_TYPES.VENMO_DISABLED_IN_CONFIGURATION.rawValue,
            ERROR_TYPES.USER_CANCEL_TRANSACTION_ERROR.rawValue,
            NSError(
              domain: ERROR_TYPES.VENMO_DISABLED_IN_CONFIGURATION_ERROR.rawValue,
              code: BTPayPalError.disabled.errorCode)
          )
        case BTVenmoError.canceled.errorCode:
          return reject(
            EXCEPTION_TYPES.USER_CANCEL_EXCEPTION.rawValue,
            ERROR_TYPES.USER_CANCEL_TRANSACTION_ERROR.rawValue,
            NSError(
              domain: ERROR_TYPES.USER_CANCEL_TRANSACTION_ERROR.rawValue,
              code: BTPayPalError.canceled.errorCode)
          )
        default:
          return reject(
            EXCEPTION_TYPES.SWIFT_EXCEPTION.rawValue,
            ERROR_TYPES.TOKENIZE_VAULT_PAYMENT_ERROR.rawValue,
            NSError(
              domain: error.localizedDescription,
              code: -1
            )
          )
        }
      }
    }
  }

}

extension ExpoBraintree: PKPaymentAuthorizationControllerDelegate {
  func paymentAuthorizationControllerDidFinish(
    _ controller: PKPaymentAuthorizationController
  ) {
    controller.dismiss {
      controller.delegate = nil
      if !self.applePayDidSucceed && self.applePayRejecter != nil {
        self.rejectApplePay(
          code: .USER_CANCEL_EXCEPTION,
          message: .APPLE_PAY_USER_CANCELLATION_ERROR
        )
      }
      self.resetApplePayState()
    }
  }

  func paymentAuthorizationController(
    _ controller: PKPaymentAuthorizationController,
    didAuthorizePayment payment: PKPayment,
    handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
  ) {
    guard let applePayClient = applePayClient else {
      completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
      rejectApplePay(
        code: .SWIFT_EXCEPTION,
        message: .APPLE_PAY_CONFIGURATION_ERROR
      )
      return
    }

    applePayClient.tokenize(payment) { [weak self] cardNonce, error in
      guard let self = self else {
        completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
        return
      }

      if let cardNonce = cardNonce {
        self.applePayDidSucceed = true
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        let result = prepareBTApplePayNonceResult(cardNonce: cardNonce)
        self.applePayResolver?(result)
        self.applePayResolver = nil
        self.applePayRejecter = nil
      } else if let error = error {
        let nsError = error as NSError
        completion(
          PKPaymentAuthorizationResult(status: .failure, errors: [nsError])
        )
        self.rejectApplePay(
          code: .SWIFT_EXCEPTION,
          message: .APPLE_PAY_TOKENIZATION_ERROR,
          underlyingError: error
        )
      } else {
        completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
        self.rejectApplePay(
          code: .SWIFT_EXCEPTION,
          message: .APPLE_PAY_TOKENIZATION_ERROR
        )
      }
    }
  }
}
