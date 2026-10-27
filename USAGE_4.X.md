# Usage

## Import

```typescript
import {
  requestOneTimePayment,
  requestBillingAgreement,
  tokenizeCardData,
  getDeviceDataFromDataCollector,
  requestVenmoNonce,
  request3DSecurePaymentCheck,
  requestGooglePayPayment,
  requestApplePayPayment,
} from 'react-native-expo-braintree';
```

---

## Request One Time Payment (PayPal)

```typescript
const result = await requestOneTimePayment({
  clientToken: 'YOUR_CLIENT_TOKEN',
  merchantAppLink: 'https://braintree-example-app.web.app',
  amount: '5.0',
  currencyCode: 'USD',
  intent: BTPayPalCheckoutIntent.sale, // authorize | order | sale
});
```
Implementation inside [requestOneTimePayment](src/index.tsx).

---

## Request Billing Agreement (PayPal Vault)

```typescript
const result = await requestBillingAgreement({
  clientToken: 'YOUR_CLIENT_TOKEN',
  merchantAppLink: 'https://braintree-example-app.web.app',
  billingAgreementDescription: 'Recurring Payment',
  displayName: 'My App',
});
```
Implementation inside [requestBillingAgreement](src/index.tsx).

---

## Card Tokenization

```typescript
const result = await tokenizeCardData({
  clientToken: 'YOUR_CLIENT_TOKEN',
  number: '4111111111111111',
  expirationMonth: '12',
  expirationYear: '2030',
  cvv: '123',
  postalCode: '12345', // optional
});
```
Implementation inside [tokenizeCardData](src/index.tsx).

---

## Data Collector

```typescript
const deviceData = await getDeviceDataFromDataCollector(clientToken);
```

Returns a correlation ID string for fraud detection.
Implementation inside [getDeviceDataFromDataCollector](src/index.tsx).

---

## Venmo Nonce

```typescript
const nonce = await requestVenmoNonce({
  clientToken: 'YOUR_CLIENT_TOKEN',
  merchantAppLink: 'https://braintree-example-app.web.app/braintree-payments/',
  vault: BoolValue.false,
  paymentMethodUsage: BTVenmoPaymntMethodUsage.singleUse,
});
```
Implementation inside [requestVenmoNonce](src/index.tsx).

---

## 3D Secure

```typescript
// First, tokenize a card:
const tokenized = await tokenizeCardData({
  clientToken: '3DS_CLIENT_TOKEN',
  number: '4000000000002503', // challenge required
  expirationMonth: '12',
  expirationYear: '2028',
  cvv: '123',
});

// Then verify with 3D Secure:
const verified = await request3DSecurePaymentCheck({
  clientToken: '3DS_CLIENT_TOKEN',
  amount: '10.00',
  nonce: tokenized.nonce,
  email: 'jill.doe@example.com',
  givenName: 'Jill',
  surName: 'Doe',
  streetAddress: '555 Smith St',
  city: 'Chicago',
  region: 'IL',
  postalCode: '60622',
  countryCodeAlpha2: 'US',
  phoneNumber: '5551234567',
});
```
Implementation inside [request3DSecurePaymentCheck](src/index.tsx).

### 3DS Test Cards

| Scenario | Card Number |
| :------- | :---------- |
| Success (No Challenge) | `4000000000002701` |
| Challenge Required | `4000000000002503` |
| Failed (Frictionless) | `4000000000002925` |

---

## Google Pay (Android only)

```typescript
const result = await requestGooglePayPayment({
  clientToken: 'YOUR_CLIENT_TOKEN',
  totalPrice: '199.00',
  currencyCode: 'USD',
  totalPriceStatus: GOOGLE_PAY_TOTAL_PRICE_STATUS.FINAL,
  billingAddressRequired: true,
  shippingAddressRequired: true,
  emailRequired: true,
  allowPrepaidCards: false,
});
```
Implementation inside [requestGooglePayPayment](src/index.tsx).

---

## Apple Pay (iOS only)

```typescript
const result = await requestApplePayPayment({
  clientToken: 'YOUR_CLIENT_TOKEN',
  merchantIdentifier: 'merchant.com.example', // Optional, defaults to the Braintree gateway configuration
  countryCode: 'US',                          // Optional, defaults to the Braintree gateway configuration
  currencyCode: 'USD',                        // Optional, defaults to the Braintree gateway configuration
  supportedNetworks: ['visa', 'masterCard'],  // Optional, defaults to the Braintree gateway configuration
  requiredBillingContactFields: ['postalAddress'],
  paymentSummaryItems: [
    { label: 'Example Item', amount: '4.00' },
    { label: 'Example Tax', amount: '1.00' },
    { label: 'Example Inc.', amount: '5.00' }, // Apple expects the last item to be the total
  ],
});

if ('nonce' in result) {
  // result.cardNetwork, result.binData, result.isDeviceToken are also available.
  // result.billingContact, result.shippingContact and result.shippingMethod
  // contain the details from the authorized payment, when supplied by Wallet.
}
```
Implementation inside [requestApplePayPayment](src/index.tsx).

The promise resolves after the sheet is dismissed and the native session is released, so you can start another checkout directly from the result. Sheet success means Braintree tokenization succeeded; it does not mean your server has authorized, charged, or settled the payment. Send the nonce to your server and show the server's payment result in your app. Server declines cannot be displayed on the dismissed Apple Pay sheet with this API.

`applicationData` is always encoded as UTF-8. Strings such as `order123`, `test`, and `SGVsbG8=` are used literally, never base64-decoded. When verifying Apple's application-data hash on your server, hash the UTF-8 bytes of the same string.

Amounts must be decimal strings without grouping separators, exponents, whitespace, or trailing characters. Discount line items may be negative; the grand total must be positive and shipping prices must be non-negative. Malformed JSON, invalid list elements, and invalid shipping methods return `APPLE_PAY_CONFIGURATION_ERROR` with the field or item index instead of silently changing the request. The `3ds` capability is always retained when other merchant capabilities are supplied.

To offer shipping choices, pass `shippingMethods` and include the first method's cost in the initial `paymentSummaryItems` total. The first method is selected by default. Selecting a different method updates the total by the price difference, including when switching back to the first method. If you show a separate shipping summary line, use the first method's exact label and amount so that line also updates. Prices are fixed per method; address-based shipping rates and tax recalculation are not supported.

Request the fulfillment details you need with `requiredShippingContactFields` (for example, `['name', 'postalAddress', 'email', 'phone']`). The successful result includes `billingContact`, `shippingContact`, and `shippingMethod` when Wallet provides them. Contacts use the same shape as the input contacts, with postal street lines joined by `\n` in `postalAddress.street`; the selected shipping method retains its configured amount string, including trailing zeros. Known card networks use the same names as `supportedNetworks`, such as `amex` and `masterCard`; `cardNetwork` is omitted when Wallet supplies no network.

The iOS Simulator can present the Apple Pay sheet with simulated cards and return dummy payment data, as described in [Apple's authorization guide](https://developer.apple.com/library/archive/ApplePay_Guide/Authorization.html). Use it to exercise the sheet and delegate callbacks. Validate the complete Braintree tokenization flow on an Apple Pay-capable physical device with an Apple Pay sandbox test card; see [Braintree's testing guide](https://developer.paypal.com/braintree/docs/guides/apple-pay/testing-go-live).

`APPLE_PAY_NOT_AVAILABLE_ERROR` means the device cannot make Apple Pay payments or no card matches the configured networks and merchant capabilities; it is not an automatic result of running in the simulator. If the user closes the sheet it returns `APPLE_PAY_USER_CANCELLATION_ERROR`. A failed tokenization keeps the sheet open so the user can pick another card, and is reported as `APPLE_PAY_TOKENIZATION_ERROR` only if the sheet is closed without a successful payment.

A missing client token, invalid `paymentSummaryItems`, or a missing merchant ID or supported networks returns `APPLE_PAY_CONFIGURATION_ERROR`. Options are parsed before fetching the gateway configuration. After gateway defaults and caller overrides are applied, merchant ID and networks are validated before checking Wallet eligibility using the configured networks and `merchantCapabilities`. This order also applies to devices without Apple Pay, which may still fetch the gateway configuration before eligibility is determined.

See [INTEGRATION_4.X_EXPO.md](INTEGRATION_4.X_EXPO.md#apple-pay) or [INTEGRATION_4.X_REACT_NATIVE_CLI.md](INTEGRATION_4.X_REACT_NATIVE_CLI.md#5-apple-pay-optional) for the required merchant ID setup.

Apple Pay is disabled in the bundled demo apps until you set their `applePayMerchantIdentifier` constant to a real merchant ID and configure the matching entitlement. Expo demos also need that ID in the config plugin options before prebuild; the bare demo needs the Apple Pay capability enabled in Xcode. No placeholder merchant entitlement is enabled by default, so ordinary device builds do not require Apple Pay provisioning.

---

## Error Handling

All methods return a result on success or throw an error object with the following structure:

```typescript
{
  code?: string;        // e.g. "ExpoBraintree:`KotlinException"
  message?: string;     // e.g. "TOKENIZE_VAULT_PAYMENT_ERROR"
  domain?: string;      // e.g. "TOKENIZE_VAULT_PAYMENT_ERROR"
  nativeError?: string; // Original native error message
}
```

Errors can also include `error: 'true'` flag for methods that resolve successfully with an error payload.

---

## TypeScript Types

Available via:

```typescript
import type {
  BTPayPalAccountNonceResult,
  BTPayPalError,
  BTCardTokenizationNonceResult,
  BTCardTokenization3DSNonceResult,
  BTThreeDError,
  BTVenmoNonceResult,
  BTVenmoError,
  BTGooglePayNonceResult,
  BTGooglePayError,
  BTApplePayNonceResult,
  BTApplePayError,
  BTDataCollectorError,
  ThreeDSecureCheckOptions,
  RequestOneTimePaymentOptions,
  RequestBillingAgreementOptions,
  TokenizeCardOptions,
  RequestVenmoNonceOptions,
  RequestGooglePayOptions,
  RequestApplePayOptions,
} from 'react-native-expo-braintree';
```

Defined inside [types.ts](src/types.ts).

### Enums

```typescript
import {
  BTPayPalCheckoutIntent,
  BTPayPalRequestUserAction,
  BoolValue,
  BTVenmoPaymntMethodUsage,
  GOOGLE_PAY_TOTAL_PRICE_STATUS,
  APPLE_PAY_ERROR_TYPES,
} from 'react-native-expo-braintree';
```
