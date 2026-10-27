import { Platform } from 'react-native';
import type { ExpoBraintree } from './ExpoBraintree.nitro';

import type {
  BTCardTokenizationNonceResult,
  BTPayPalAccountNonceResult,
  BTPayPalError,
  BTPayPalGetDeviceDataResult,
  BTVenmoError,
  BTVenmoNonceResult,
  RequestBillingAgreementOptions,
  RequestOneTimePaymentOptions,
  RequestVenmoNonceOptions,
  TokenizeCardOptions,
  BTCardTokenization3DSNonceResult,
  ThreeDSecureCheckOptions,
  BTThreeDError,
  RequestGooglePayOptions,
  BTGooglePayNonceResult,
  BTGooglePayError,
  BTDataCollectorError,
  RequestApplePayOptions,
  BTApplePayNonceResult,
  BTApplePayError,
} from './types';
import {
  APPLE_PAY_ERROR_TYPES,
  EXCEPTION_TYPES,
  GOOGLE_PAY_TOTAL_PRICE_STATUS,
} from './types';
import { catchError, handleResult, toNativeOptions } from './utils';

let expoBraintreeHybridObject: ExpoBraintree | undefined;
const getExpoBraintreeHybridObject = (): ExpoBraintree => {
  if (expoBraintreeHybridObject === undefined) {
    const {
      NitroModules,
    }: typeof import('react-native-nitro-modules') = require('react-native-nitro-modules');
    expoBraintreeHybridObject =
      NitroModules.createHybridObject<ExpoBraintree>('ExpoBraintree');
  }
  return expoBraintreeHybridObject;
};

export const requestBillingAgreement = async (
  options: RequestBillingAgreementOptions
): Promise<BTPayPalAccountNonceResult | BTPayPalError> => {
  try {
    const result = await getExpoBraintreeHybridObject().requestBillingAgreement(
      options as unknown as Record<string, string>
    );
    return handleResult<BTPayPalAccountNonceResult>(result, [
      'billingAddress',
      'shippingAddress',
    ]);
  } catch (ex: unknown) {
    return catchError(ex) as BTPayPalError;
  }
};

export const requestOneTimePayment = async (
  options: RequestOneTimePaymentOptions
): Promise<BTPayPalAccountNonceResult | BTPayPalError> => {
  try {
    const result = await getExpoBraintreeHybridObject().requestOneTimePayment(
      options as unknown as Record<string, string>
    );
    return handleResult<BTPayPalAccountNonceResult>(result, [
      'billingAddress',
      'shippingAddress',
    ]);
  } catch (ex: unknown) {
    return catchError(ex) as BTPayPalError;
  }
};

export const getDeviceDataFromDataCollector = async (
  clientToken: string,
  hasUserLocationConsent?: boolean,
  riskCorrelationId?: string
): Promise<BTPayPalGetDeviceDataResult | BTDataCollectorError> => {
  const options: Record<string, string> = { clientToken };
  if (hasUserLocationConsent !== undefined) {
    options.hasUserLocationConsent = String(hasUserLocationConsent);
  }
  if (riskCorrelationId !== undefined) {
    options.riskCorrelationId = riskCorrelationId;
  }
  try {
    const result =
      await getExpoBraintreeHybridObject().getDeviceDataFromDataCollector(
        options
      );
    handleResult(result);
    return (result.data || '') as BTPayPalGetDeviceDataResult;
  } catch (ex: unknown) {
    return catchError(ex) as BTDataCollectorError;
  }
};

export const tokenizeCardData = async (
  options: TokenizeCardOptions
): Promise<BTCardTokenizationNonceResult | BTPayPalError> => {
  try {
    const result = await getExpoBraintreeHybridObject().tokenizeCardData(
      options as unknown as Record<string, string>
    );
    return handleResult<BTCardTokenizationNonceResult>(result);
  } catch (ex: unknown) {
    return catchError(ex) as BTPayPalError;
  }
};

export const requestVenmoNonce = async (
  options: RequestVenmoNonceOptions
): Promise<BTVenmoNonceResult | BTVenmoError> => {
  try {
    const result = await getExpoBraintreeHybridObject().requestVenmoNonce(
      options as unknown as Record<string, string>
    );
    return handleResult<BTVenmoNonceResult>(result, [
      'billingAddress',
      'shippingAddress',
    ]);
  } catch (ex: unknown) {
    return catchError(ex) as BTVenmoError;
  }
};

export const request3DSecurePaymentCheck = async (
  options: ThreeDSecureCheckOptions
): Promise<BTCardTokenization3DSNonceResult | BTThreeDError> => {
  try {
    const result =
      await getExpoBraintreeHybridObject().request3DSecurePaymentCheck(
        options as unknown as Record<string, string>
      );
    return handleResult<BTCardTokenization3DSNonceResult>(result, [
      'threeDSecureInfo',
    ]);
  } catch (ex: unknown) {
    return catchError(ex) as BTThreeDError;
  }
};

export const requestGooglePayPayment = async (
  options: RequestGooglePayOptions
): Promise<BTGooglePayNonceResult | BTGooglePayError> => {
  try {
    if (Platform.OS !== 'android') {
      return {
        error: 'true',
        message: 'Google Pay is only supported on Android.',
      } as unknown as BTGooglePayError;
    }
    const nativeOptions: Record<string, string> = {
      clientToken: options.clientToken,
    };
    nativeOptions.totalPrice = options.totalPrice;
    nativeOptions.currencyCode = options.currencyCode;
    nativeOptions.totalPriceStatus = String(
      options.totalPriceStatus ?? GOOGLE_PAY_TOTAL_PRICE_STATUS.FINAL
    );
    if (options.googleMerchantName)
      nativeOptions.googleMerchantName = options.googleMerchantName;
    nativeOptions.billingAddressRequired = String(
      options.billingAddressRequired ?? false
    );
    nativeOptions.emailRequired = String(options.emailRequired ?? false);
    nativeOptions.phoneNumberRequired = String(
      options.phoneNumberRequired ?? false
    );
    nativeOptions.shippingAddressRequired = String(
      options.shippingAddressRequired ?? false
    );
    nativeOptions.allowPrepaidCards = String(options.allowPrepaidCards ?? true);
    const result =
      await getExpoBraintreeHybridObject().requestGooglePayPayment(
        nativeOptions
      );
    return handleResult<BTGooglePayNonceResult>(result, [
      'details',
      'billingAddress',
    ]);
  } catch (ex: unknown) {
    return catchError(ex) as BTGooglePayError;
  }
};

export const requestApplePayPayment = async (
  options: RequestApplePayOptions
): Promise<BTApplePayNonceResult | BTApplePayError> => {
  try {
    if (Platform.OS !== 'ios' && Platform.OS !== 'android') {
      return {
        error: 'true',
        code: EXCEPTION_TYPES.UNSUPPORTED_PLATFORM_EXCEPTION,
        message: APPLE_PAY_ERROR_TYPES.APPLE_PAY_NOT_AVAILABLE_ERROR,
        domain: APPLE_PAY_ERROR_TYPES.APPLE_PAY_NOT_AVAILABLE_ERROR,
        nativeError: 'Apple Pay is only supported on iOS.',
      };
    }
    const result = await getExpoBraintreeHybridObject().requestApplePayPayment(
      toNativeOptions(options)
    );
    return handleResult<BTApplePayNonceResult>(result, [
      'isDefault',
      'isDeviceToken',
      'binData',
      'billingContact',
      'shippingContact',
      'shippingMethod',
      'authorizedTotal',
    ]);
  } catch (ex: unknown) {
    return catchError(ex) as BTApplePayError;
  }
};

export * from './types';
