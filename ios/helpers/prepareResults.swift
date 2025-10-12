//
//  prepareResults.swift
//  expo-braintree
//
//  Created by Maciej Sasinowski on 28/04/2024.
//

import Braintree
import Foundation

func prepareAddressResult(address: BTPostalAddress?) -> NSMutableDictionary {
  let addressResult = NSMutableDictionary()
  addressResult["recipientName"] = address?.recipientName
  addressResult["streetAddress"] = address?.streetAddress
  addressResult["extendedAddress"] = address?.extendedAddress
  addressResult["locality"] = address?.locality
  addressResult["countryCodeAlpha2"] = address?.countryCodeAlpha2
  addressResult["postalCode"] = address?.postalCode
  addressResult["region"] = address?.region
  return addressResult
}

func prepareBTPayPalAccountNonceResult(accountNonce: BTPayPalAccountNonce)
  -> NSDictionary
{
  let result = NSMutableDictionary()
  result["email"] = accountNonce.email ?? ""
  result["payerID"] = accountNonce.payerID ?? ""
  result["nonce"] = accountNonce.nonce
  result["phone"] = accountNonce.phone
  result["firstName"] = accountNonce.firstName ?? ""
  result["lastName"] = accountNonce.lastName ?? ""
  result["billingAddress"] = prepareAddressResult(address: accountNonce.billingAddress)
  result["shippingAddress"] = prepareAddressResult(address: accountNonce.shippingAddress)
  return result
}

func prepareBTVenmoAccountNonceResult(accountNonce: BTVenmoAccountNonce)
  -> NSDictionary
{
  let result = NSMutableDictionary()
  result["email"] = accountNonce.email ?? ""
  result["externalID"] = accountNonce.externalID ?? ""
  result["nonce"] = accountNonce.nonce
  result["phoneNumber"] = accountNonce.phoneNumber ?? ""
  result["firstName"] = accountNonce.firstName ?? ""
  result["lastName"] = accountNonce.lastName ?? ""
  result["username"] = accountNonce.username ?? ""
  result["billingAddress"] = prepareAddressResult(address: accountNonce.billingAddress)
  result["shippingAddress"] = prepareAddressResult(address: accountNonce.shippingAddress)
  return result
}

func prepareBTApplePayNonceResult(cardNonce: BTApplePayCardNonce) -> NSDictionary {
  let result = NSMutableDictionary()
  result["nonce"] = cardNonce.nonce
  result["type"] = cardNonce.type
  result["isDefault"] = cardNonce.isDefault
  result["isDeviceToken"] = cardNonce.isDeviceToken

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
