export enum EXCEPTION_TYPES {
  UNSUPPORTED_PLATFORM_EXCEPTION = 'ExpoBraintree:`UnsupportedPlatformException',
  KOTLIN_EXCEPTION = 'ExpoBraintree:`KotlinException',
  SWIFT_EXCEPTION = 'ExpoBraintree:`SwiftException',
  USER_CANCEL_EXCEPTION = 'ExpoBraintree:`UserCancelException',
  TOKENIZE_EXCEPTION = 'ExpoBraintree:`TokenizeException',
}

export enum PAYPAL_EXCEPTION_TYPES {
  PAYPAL_DISABLED_IN_CONFIGURATION = 'ExpoBraintree:`Paypal disabled in configuration',
}

export enum DATA_COLLECTOR_EXCEPTION_TYPES {
  DATA_COLLECTOR_ERROR = 'ExpoBraintree:`Data Collector error',
}

export enum VENMO_EXCEPTION_TYPES {
  VENMO_DISABLED_IN_CONFIGURATION = 'ExpoBraintree:`VENMO disabled in configuration',
}

export enum GOOGLE_PAY_ERROR_TYPES {
  GOOGLE_PAY_NOT_AVAILABLE = 'GOOGLE_PAY_NOT_AVAILABLE',
  GOOGLE_PAY_FAILED = 'GOOGLE_PAY_FAILED',
}

export enum APPLE_PAY_ERROR_TYPES {
  APPLE_PAY_NOT_AVAILABLE_ERROR = 'APPLE_PAY_NOT_AVAILABLE_ERROR',
  APPLE_PAY_CONFIGURATION_ERROR = 'APPLE_PAY_CONFIGURATION_ERROR',
  APPLE_PAY_REQUEST_ERROR = 'APPLE_PAY_REQUEST_ERROR',
  APPLE_PAY_IN_PROGRESS_ERROR = 'APPLE_PAY_IN_PROGRESS_ERROR',
  APPLE_PAY_PRESENTATION_ERROR = 'APPLE_PAY_PRESENTATION_ERROR',
  APPLE_PAY_TOKENIZATION_ERROR = 'APPLE_PAY_TOKENIZATION_ERROR',
  APPLE_PAY_USER_CANCELLATION_ERROR = 'APPLE_PAY_USER_CANCELLATION_ERROR',
}

export enum ERROR_TYPES {
  API_CLIENT_INITIALIZATION_ERROR = 'API_CLIENT_INITIALIZATION_ERROR',
  TOKENIZE_VAULT_PAYMENT_ERROR = 'TOKENIZE_VAULT_PAYMENT_ERROR',
  USER_CANCEL_TRANSACTION_ERROR = 'USER_CANCEL_TRANSACTION_ERROR',
  DATA_COLLECTOR_ERROR = 'DATA_COLLECTOR_ERROR',
  CARD_TOKENIZATION_ERROR = 'CARD_TOKENIZATION_ERROR',
}

export enum DATA_COLLECTOR_ERROR_TYPES {
  DATA_COLLECTOR_ERROR = 'DATA_COLLECTOR_ERROR',
}

export enum PAYPAL_ERROR_TYPES {
  PAYPAL_DISABLED_IN_CONFIGURATION_ERROR = 'PAYPAL_DISABLED_IN_CONFIGURATION_ERROR',
}

export enum VENMO_ERROR_TYPES {
  VENMO_DISABLED_IN_CONFIGURATION = 'VENMO_DISABLED_IN_CONFIGURATION_ERROR',
}

export enum THREE_D_SECURE_ERROR_TYPES {
  D_SECURE_NOT_ABLE_TO_SHIFT_LIABILITY = 'D_SECURE_NOT_ABLE_TO_SHIFT_LIABILITY',
  D_SECURE_LIABILITY_NOT_SHIFTED = 'D_SECURE_LIABILITY_NOT_SHIFTED',
  PAYMENT_3D_SECURE_FAILED = 'PAYMENT_3D_SECURE_FAILED',
}

export enum BTPayPalCheckoutIntent {
  authorize = 'authorize', // Default
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

export type RequestBillingAgreementOptions = {
  clientToken: string;
  billingAgreementDescription?: string;
  displayName?: string;
  localeCode?: string;
  userAuthenticationEmail?: string;
  offerCredit?: BoolValue;
  isShippingAddressRequired?: BoolValue;
  isShippingAddressEditable?: BoolValue;
  hasUserLocationConsent?: BoolValue;
  merchantAppLink: string;
  fallbackUrlScheme?: string;
};
export type RequestOneTimePaymentOptions = {
  amount: string;
  intent?: BTPayPalCheckoutIntent;
  userAction?: BTPayPalRequestUserAction;
  offerPayLater?: BoolValue;
  currencyCode?: string;
  requestBillingAgreement?: BoolValue;
  hasUserLocationConsent?: boolean;
  clientToken: string;
  merchantAppLink: string;
  fallbackUrlScheme?: string;
};

export type TokenizeCardOptions = {
  number: string;
  expirationMonth: string;
  expirationYear: string;
  cvv: string;
  postalCode?: string;
  clientToken: string;
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
  fallbackUrlScheme?: string;
  merchantAppLink: string;
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

export type BTDataCollectorError = {
  code?: EXCEPTION_TYPES | DATA_COLLECTOR_EXCEPTION_TYPES;
  message?: ERROR_TYPES | DATA_COLLECTOR_ERROR_TYPES | string;
  domain?: ERROR_TYPES | DATA_COLLECTOR_ERROR_TYPES;
  nativeError?: string;
};

export type BTPayPalError = {
  code?: EXCEPTION_TYPES | PAYPAL_EXCEPTION_TYPES;
  message?: ERROR_TYPES | PAYPAL_ERROR_TYPES | string;
  domain?: ERROR_TYPES | PAYPAL_ERROR_TYPES;
  nativeError?: string;
};

export type BTVenmoError = {
  code?: EXCEPTION_TYPES | VENMO_EXCEPTION_TYPES;
  message?: ERROR_TYPES | VENMO_ERROR_TYPES | string;
  domain?: ERROR_TYPES | VENMO_ERROR_TYPES;
  nativeError?: string;
};

export type BTThreeDError = {
  code?: EXCEPTION_TYPES | VENMO_EXCEPTION_TYPES;
  message?: ERROR_TYPES | THREE_D_SECURE_ERROR_TYPES | string;
  domain?: ERROR_TYPES | THREE_D_SECURE_ERROR_TYPES;
  nativeError?: string;
};

export type ThreeDSecureInfo = {
  /** True if the bank accepts responsibility for the fraud risk */
  liabilityShifted: boolean;
  /** True if the card is eligible for 3D Secure */
  liabilityShiftPossible: boolean;
  /** The status of the 3D Secure verification (e.g., 'authenticated', 'lookup_error') */
  status: string;
  /** Indicates if the verification process was actually performed */
  wasVerified: boolean;
};

export type BTCardTokenization3DSNonceResult = {
  nonce: string;
  cardNetwork?: string;
  lastTwo?: string;
  lastFour?: string;
  expirationMonth?: string;
  expirationYear?: string;
  /** Detailed 3D Secure verification results from the bank */
  threeDSecureInfo?: ThreeDSecureInfo;
};

type D = '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9';

export type ThreeDSecureCheckOptions = {
  clientToken: string;
  /**
   * Transaction amount in "X.YY" format.
   * @example "10.00"
   */
  amount: `${number}.${D}${D}`;
  nonce: string;
  email?: string;
  givenName?: string;
  surName?: string;
  phoneNumber?: string;
  streetAddress?: string;
  extendedAddress?: string;
  city?: string;
  postalCode?: string;
  region?: string;
  countryCodeAlpha2?: string;
};

export enum GOOGLE_PAY_TOTAL_PRICE_STATUS {
  /** The total price is an estimated price and might still change (maps to 1 in Kotlin) */
  ESTIMATED = 1,
  /** The total price is the final price and will not change (maps to 3/else in Kotlin) */
  FINAL = 3,
}

export type RequestGooglePayOptions = {
  clientToken: string;
  totalPrice: string;
  currencyCode: string;
  totalPriceStatus?: GOOGLE_PAY_TOTAL_PRICE_STATUS;
  googleMerchantName?: string;
  billingAddressRequired?: boolean;
  emailRequired?: boolean;
  phoneNumberRequired?: boolean;
  shippingAddressRequired?: boolean;
  allowPrepaidCards?: boolean;
};

export type BTGooglePayNonceResult = {
  nonce: string;
  type: 'GooglePayCard';
  description: string;
  details: {
    cardType: string;
    lastFour: string;
    lastTwo: string;
  };
  billingAddress?: {
    recipientName?: string;
    streetAddress?: string;
    locality?: string;
    countryCodeAlpha2?: string;
  };
};

export type BTGooglePayError = {
  code?: EXCEPTION_TYPES | GOOGLE_PAY_ERROR_TYPES;
  message?: string;
  nativeError?: string;
};

export type BTApplePayMerchantCapability = '3ds' | 'credit' | 'debit' | 'emv';

export type BTApplePaySupportedNetwork =
  | 'amex'
  | 'cartesBancaires'
  | 'chinaUnionPay'
  | 'discover'
  | 'eftpos'
  | 'electron'
  | 'elo'
  | 'girocard'
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
  /** Decimal string without grouping or exponents; negative line items represent discounts */
  amount: string;
  type?: BTApplePaySummaryItemType;
};

export type BTApplePayShippingMethod = BTApplePaySummaryItem & {
  /** Must be unique within shippingMethods; shipping amounts must be non-negative */
  identifier: string;
  detail?: string;
};

export type BTApplePayShippingOption = BTApplePayShippingMethod & {
  /** Complete summary shown for this method, ending with its positive grand total */
  paymentSummaryItems: BTApplePaySummaryItem[];
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

export type RequestApplePayOptions = {
  clientToken: string;
  /**
   * Line items shown on the Apple Pay sheet. Apple expects the last item to be
   * the positive grand total, labelled with your company name.
   */
  paymentSummaryItems: BTApplePaySummaryItem[];
  /** Defaults to the merchant ID configured for Apple Pay in the Braintree gateway */
  merchantIdentifier?: string;
  /** Defaults to the country configured in the Braintree gateway */
  countryCode?: string;
  /** Defaults to the currency configured in the Braintree gateway */
  currencyCode?: string;
  /** Defaults to the card networks enabled in the Braintree gateway */
  supportedNetworks?: BTApplePaySupportedNetwork[];
  /** Defaults to ['3ds']; '3ds' is always included with other capabilities */
  merchantCapabilities?: BTApplePayMerchantCapability[];
  requiredBillingContactFields?: BTApplePayContactField[];
  requiredShippingContactFields?: BTApplePayContactField[];
  /**
   * Each method supplies its complete summary. The top-level summary must
   * match the first method, which is selected initially. Selecting a method
   * replaces the whole summary without inferring lines or calculating prices.
   */
  shippingMethods?: BTApplePayShippingOption[];
  billingContact?: BTApplePayContact;
  shippingContact?: BTApplePayContact;
  shippingType?: BTApplePayShippingType;
  /** UTF-8 text whose bytes are hashed into the payment token by Apple; never base64-decoded */
  applicationData?: string;
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
  type: string;
  isDefault: boolean;
  isDeviceToken: boolean;
  /** Final amount displayed on the authorized sheet, including the selected shipping cost */
  authorizedTotal?: { amount: string; currencyCode: string };
  /** Uses card tokenization names, e.g. 'Visa' or 'MasterCard'; omitted when unavailable */
  cardNetwork?: string;
  binData?: BTApplePayBinDataResult;
  /** Billing contact from the authorized payment, when provided by Wallet */
  billingContact?: BTApplePayContact;
  /** Shipping contact from the authorized payment, when provided by Wallet */
  shippingContact?: BTApplePayContact;
  /** Shipping method selected in Wallet, preserving the configured amount string */
  shippingMethod?: BTApplePayShippingMethod;
};

export type BTApplePayError = {
  error?: 'true';
  code?: EXCEPTION_TYPES;
  message?: APPLE_PAY_ERROR_TYPES | ERROR_TYPES | string;
  domain?: APPLE_PAY_ERROR_TYPES | ERROR_TYPES | string;
  nativeError?: string;
};
