# Usage
# Package Version 2.x.x
## Request One Time Payment

```javascript
import {
  requestOneTimePayment,
} from "expo-braintree";

const result: BTPayPalAccountNonceResult | BTPayPalError  = await requestOneTimePayment({
    clientToken: 'Token',
    amount: '5.0',
    currencyCode: 'USD'
    })

```

## Card tokenization
```javascript
import {
  tokenizeCard,
} from "expo-braintree";

const result: BTCardTokenizationNonceResult | BTPayPalError = await tokenizeCard({
    clientToken: 'Token",
    number: '1111222233334444',
    expirationMonth: '11',
    expirationYear: '24',
    cvv: '123',
    postalCode: '',
    })

```

## Request PayPal billing agreement
```javascript
import {
  requestBillingAgreement,
} from "expo-braintree";

const result: BTPayPalAccountNonceResult | BTPayPalError  = await requestBillingAgreement({
    clientToken: 'Token',
    billingAgreementDescription: 'Description,
    localeCode: 'en-US'
    })
    .then(result => console.log(result))
    .catch((error) => console.log(error));
```
## Call Data Collector and get correlation id
```javascript
import {
  getDeviceDataFromDataCollector,
} from "expo-braintree";

const result: string = await getDeviceDataFromDataCollector(clientToken})

```

## Request Apple Pay nonce
```javascript
import {
  requestApplePayNonce,
} from "expo-braintree";

const nonce = await requestApplePayNonce({
    clientToken,
    merchantIdentifier: 'merchant.com.example',
    countryCode: 'US',
    currencyCode: 'USD',
    supportedNetworks: ['visa', 'masterCard', 'amex'],
    paymentSummaryItems: [
      { label: 'Example Item', amount: '4.00' },
      { label: 'Example Tax', amount: '1.00' },
      { label: 'Example Total', amount: '5.00' },
    ],
});
```

> Apple Pay sheets only present on a real iOS device with Apple Pay configured; the simulator will return an `APPLE_PAY_NOT_AVAILABLE_ERROR`.
