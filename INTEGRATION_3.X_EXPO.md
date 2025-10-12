## Integration
## Package Version 3.x.x
### Expo Based Project (EXPO SDK 50 and EXPO SDK 51) 
From version 2.1.1 of the package, react-native-expo-braintree added a possibility to use the package into expo based project, without need to eject from the expo. Special expo plugin was added into the source of the package which can be used. in any expo project.

Expo based project needs minimum integration from the app perspective.
In Your `app.config.ts` or `app.config.json` or `app.config.js` please add expo-braintree plugin into plugins section.
```javascript
...
  plugins: [
    [
      "react-native-expo-braintree",
      {
        xCodeProjectAppName: "xCodeProjectAppName",
        host: "braintree-example-app.web.app",
        pathPrefix: "/braintree-payments", // Optional
        applePayMerchantIdentifier: "merchant.com.example", // Optional
      },
    ],
...
```
`xCodeProjectAppName` - Name of your xCode project in case of this repository, for example app  it will be `ExpoBraintreeExample`

`host` - Domain that provide a .well-known/applinks.json, it need to be the same as it is defined in [Set Up App Links](https://github.com/braintree/braintree_android/blob/main/APP_LINK_SETUP.md)

`pathPrefix` - Path prefix, in case of you want to separate path only to handle the context switch (Optional)

`applePayMerchantIdentifier` - Merchant identifier string to include in the generated entitlements when Apple Pay is enabled (Optional)

#### Android Specific
Currently expo-plugin written for making changes into Android settings files, using one danger modifiers from expo-config-plugins called `withMainActivity`

[Plugin Code ](src/plugin/withExpoBraintree.android.ts)


#### iOS Specific
Currently expo-plugin written for making changes into IOS settings files, using one danger modifier from expo-config-plugins called `withAppDelegate`

[Plugin Code ](src/plugin/withExpoBraintree.ios.ts)

### Apple Pay Integration

Apple Pay requires a few additional iOS-only steps:

1. **Create a Merchant ID** – In the Apple Developer portal register a merchant identifier (e.g. `merchant.com.myapp.payments`). The same value must be passed to the Expo plugin via `applePayMerchantIdentifier`.
2. **Configure the plugin** – Update `app.json`/`app.config.{js,ts}`:

   ```json
   {
     "plugins": [
       [
         "react-native-expo-braintree",
         {
           "xCodeProjectAppName": "ExpoBraintreeExample",
           "host": "braintree-example-app.web.app",
           "applePayMerchantIdentifier": "merchant.com.example"
         }
       ]
     ]
   }
   ```

   The plugin will add the merchant ID to your entitlements and wire the Braintree return URL scheme.

3. **Install pods & rebuild** – run `npx pod-install` and rebuild the iOS project so Xcode picks up the new entitlements.
4. **Test on device** – The simulator cannot display the Apple Pay sheet. Use a real iPhone with Apple Pay configured to ensure `requestApplePayNonce` presents the native UI.

Once configured, call the exported helper:

```ts
import { requestApplePayNonce } from 'react-native-expo-braintree';

const result = await requestApplePayNonce({
  clientToken,
  merchantIdentifier: 'merchant.com.example',
  countryCode: 'US',
  currencyCode: 'USD',
  supportedNetworks: ['visa', 'masterCard'],
  paymentSummaryItems: [
    { label: 'Example Item', amount: '10.00' },
    { label: 'Total', amount: '10.00' },
  ],
});
```

If a nonce is returned you can send it to your backend to complete the transaction.
