import Braintree
import Foundation
import PassKit

func prepareBTApplePayNonceResult(
    cardNonce: BTApplePayCardNonce,
    payment: PKPayment,
    shippingMethodAmounts: [String: String],
    authorizedTotal: PKPaymentSummaryItem?,
    currencyCode: String?
) throws -> NSDictionary {
    let result = NSMutableDictionary()
    result["nonce"] = cardNonce.nonce
    result["type"] = cardNonce.type
    result["isDefault"] = cardNonce.isDefault
    result["isDeviceToken"] = cardNonce.isDeviceToken
    if let network = applePayNetworkName(payment.token.paymentMethod.network) {
        result["cardNetwork"] = network
    }
    result.addEntries(from: try prepareApplePayPaymentDetails(
        payment, shippingMethodAmounts: shippingMethodAmounts,
        authorizedTotal: authorizedTotal, currencyCode: currencyCode
    ))

    let binData = NSMutableDictionary()
    binData["prepaid"] = cardNonce.binData.prepaid
    binData["healthcare"] = cardNonce.binData.healthcare
    binData["debit"] = cardNonce.binData.debit
    binData["durbinRegulated"] = cardNonce.binData.durbinRegulated
    binData["commercial"] = cardNonce.binData.commercial
    binData["payroll"] = cardNonce.binData.payroll
    binData["issuingBank"] = cardNonce.binData.issuingBank
    binData["countryOfIssuance"] = cardNonce.binData.countryOfIssuance
    binData["productID"] = cardNonce.binData.productID
    result["binData"] = binData
    return result
}
