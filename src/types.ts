export enum EXCEPTION_TYPES {
  SWIFT_EXCEPTION = 'ExpoBraintree:`SwiftException',
  USER_CANCEL_EXCEPTION = 'ExpoBraintree:`UserCancelException',
  TOKENIZE_EXCEPTION = 'ExpoBraintree:`TokenizeException',
}

export enum PAYPAL_EXCEPTION_TYPES {
  PAYPAL_DISABLED_IN_CONFIGURATION = 'ExpoBraintree:`Paypal disabled in configuration',
}

export enum VENMO_EXCEPTION_TYPES {
  VENMO_DISABLED_IN_CONFIGURATION = 'ExpoBraintree:`VENMO disabled in configuration',
}

export enum ERROR_TYPES {
  API_CLIENT_INITIALIZATION_ERROR = 'API_CLIENT_INITIALIZATION_ERROR',
  TOKENIZE_VAULT_PAYMENT_ERROR = 'TOKENIZE_VAULT_PAYMENT_ERROR',
  USER_CANCEL_TRANSACTION_ERROR = 'USER_CANCEL_TRANSACTION_ERROR',
  DATA_COLLECTOR_ERROR = 'DATA_COLLECTOR_ERROR',
  CARD_TOKENIZATION_ERROR = 'CARD_TOKENIZATION_ERROR',
  APPLE_PAY_NOT_AVAILABLE_ERROR = 'APPLE_PAY_NOT_AVAILABLE_ERROR',
  APPLE_PAY_CONFIGURATION_ERROR = 'APPLE_PAY_CONFIGURATION_ERROR',
  APPLE_PAY_PRESENTATION_ERROR = 'APPLE_PAY_PRESENTATION_ERROR',
  APPLE_PAY_TOKENIZATION_ERROR = 'APPLE_PAY_TOKENIZATION_ERROR',
  APPLE_PAY_USER_CANCELLATION_ERROR = 'APPLE_PAY_USER_CANCELLATION_ERROR',
}

export enum PAYPAL_ERROR_TYPES {
  PAYPAL_DISABLED_IN_CONFIGURATION_ERROR = 'PAYPAL_DISABLED_IN_CONFIGURATION_ERROR',
}

export enum VENMO_ERROR_TYPES {
  VENMO_DISABLED_IN_CONFIGURATION = 'VENMO_DISABLED_IN_CONFIGURATION_ERROR',
}

export enum BTPayPalCheckoutIntent {
  authorize = 'authorize',
  order = 'order',
  sale = 'sale',
}
export enum BTPayPalRequestUserAction {
  none = 'none',
  payNow = 'payNow',
}

export enum BoolValue {
  true = 'true',
  false = 'false',
}

export enum BTVenmoPaymntMethodUsage {
  multiUse = 'multiUse',
  singleUse = 'singleUse',
}

export type BTApplePayMerchantCapability = '3ds' | 'credit' | 'debit' | 'emv';

export type BTApplePaySupportedNetwork =
  | 'amex'
  | 'cartesBancaires'
  | 'chinaUnionPay'
  | 'discover'
  | 'eftpos'
  | 'electron'
  | 'elo'
  | 'idCredit'
  | 'interac'
  | 'jcb'
  | 'mada'
  | 'maestro'
  | 'masterCard'
  | 'privateLabel'
  | 'quicPay'
  | 'suica'
  | 'visa';

export type BTApplePayContactField =
  | 'email'
  | 'name'
  | 'phone'
  | 'postalAddress'
  | 'phoneticName';

export type BTApplePaySummaryItemType = 'final' | 'pending';

export type BTApplePayShippingType =
  | 'shipping'
  | 'delivery'
  | 'storePickup'
  | 'servicePickup';

export type BTApplePaySummaryItem = {
  label: string;
  amount: string;
  type?: BTApplePaySummaryItemType;
};

export type BTApplePayShippingMethod = BTApplePaySummaryItem & {
  identifier: string;
  detail?: string;
};

export type BTApplePayPostalAddress = {
  street?: string;
  line1?: string;
  line2?: string;
  city?: string;
  state?: string;
  postalCode?: string;
  country?: string;
  countryCode?: string;
  subAdministrativeArea?: string;
  subLocality?: string;
};

export type BTApplePayContact = {
  emailAddress?: string;
  phoneNumber?: string;
  givenName?: string;
  familyName?: string;
  phoneticGivenName?: string;
  phoneticFamilyName?: string;
  postalAddress?: BTApplePayPostalAddress;
};

export type RequestBillingAgreementOptions = {
  clientToken: string;
  billingAgreementDescription?: string;
  displayName?: string;
  localeCode?: string;
  userAuthenticationEmail?: string;
  offerCredit?: BoolValue;
  isShippingAddressRequired?: BoolValue;
  isShippingAddressEditable?: BoolValue;
  isAccessibilityElement?: BoolValue;
  hasUserLocationConsent?: BoolValue;
  merchantAppLink: string;
};
export type RequestOneTimePaymentOptions = {
  amount: string;
  intent?: BTPayPalCheckoutIntent;
  userAction?: BTPayPalRequestUserAction;
  offerPayLater?: BoolValue;
  currencyCode?: string;
  requestBillingAgreement?: BoolValue;
  hasUserLocationConsent?: BoolValue;
  clientToken: string;
  merchantAppLink: string;
};

export type TokenizeCardOptions = {
  number: string;
  expirationMonth: string;
  expirationYear: string;
  cvv: string;
  postalCode?: string;
  clientToken: string;
};

export type RequestApplePayNonceOptions = {
  clientToken: string;
  merchantIdentifier: string;
  countryCode: string;
  currencyCode: string;
  supportedNetworks: BTApplePaySupportedNetwork[];
  paymentSummaryItems: BTApplePaySummaryItem[];
  merchantCapabilities?: BTApplePayMerchantCapability[];
  requiredBillingContactFields?: BTApplePayContactField[];
  requiredShippingContactFields?: BTApplePayContactField[];
  shippingMethods?: BTApplePayShippingMethod[];
  billingContact?: BTApplePayContact;
  shippingContact?: BTApplePayContact;
  shippingType?: BTApplePayShippingType;
  applicationData?: string;
};

export type BTPayPalAccountNonceAddressResult = {
  recipientName?: string;
  streetAddress?: string;
  extendedAddress?: string;
  locality?: string;
  countryCodeAlpha2?: string;
  postalCode?: string;
  region?: string;
};

export type BTPayPalAccountNonceResult = {
  email?: string;
  payerID?: string;
  nonce: string;
  firstName?: string;
  lastName?: string;
  billingAddress?: BTPayPalAccountNonceAddressResult;
  shippingAddress?: BTPayPalAccountNonceAddressResult;
};

export type BTCardTokenizationNonceResult = {
  nonce: string;
  cardNetwork?: string;
  lastTwo?: string;
  lastFour?: string;
  expirationMonth?: string;
  expirationYear?: string;
};

export type BTApplePayBinDataResult = {
  prepaid?: string;
  healthcare?: string;
  debit?: string;
  durbinRegulated?: string;
  commercial?: string;
  payroll?: string;
  issuingBank?: string;
  countryOfIssuance?: string;
  productID?: string;
};

export type BTApplePayNonceResult = {
  nonce: string;
  type?: string;
  isDefault?: boolean;
  isDeviceToken?: boolean;
  binData?: BTApplePayBinDataResult;
};

export type RequestVenmoNonceOptions = {
  clientToken: string;
  profileID?: string;
  vault?: BoolValue;
  paymentMethodUsage?: BTVenmoPaymntMethodUsage;
  displayName?: string;
  collectCustomerBillingAddress?: BoolValue;
  collectCustomerShippingAddress?: BoolValue;
  isFinalAmount?: BoolValue;
  subTotalAmount?: string;
  discountAmount?: string;
  taxAmount?: string;
  shippingAmount?: string;
  totalAmount?: string;
  fallbackToWeb?: BoolValue;
};

export type BTVenmoNonceResult = {
  nonce: string;
  email?: string;
  externalID?: string;
  firstName?: string;
  lastName?: string;
  phoneNumber?: string;
  username?: string;
  billingAddress?: BTPayPalAccountNonceAddressResult;
  shippingAddress?: BTPayPalAccountNonceAddressResult;
};

export type BTPayPalGetDeviceDataResult = string;

export type BTPayPalError = {
  code?: EXCEPTION_TYPES | PAYPAL_EXCEPTION_TYPES;
  message?: ERROR_TYPES | PAYPAL_ERROR_TYPES | string;
  domain?: ERROR_TYPES | PAYPAL_ERROR_TYPES;
};

export type BTVenmoError = {
  code?: EXCEPTION_TYPES | VENMO_EXCEPTION_TYPES;
  message?: ERROR_TYPES | VENMO_ERROR_TYPES | string;
  domain?: ERROR_TYPES | VENMO_ERROR_TYPES;
};

export type BTApplePayError = {
  code?: EXCEPTION_TYPES | string;
  message?: ERROR_TYPES | string;
  domain?: ERROR_TYPES | string;
};
