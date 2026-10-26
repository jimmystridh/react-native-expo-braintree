## Integration

## Package Version 4.0.0 (Nitro Modules)

> **Required dependency:** `react-native-nitro-modules` must be installed alongside this library and configured in your project. It provides the Nitro Modules runtime that bridges native code.

```sh
npx expo install react-native-expo-braintree react-native-nitro-modules
```

### Expo Based Project (Expo SDK 53+)

Expo based project needs minimum integration from the app perspective.
In your `app.config.ts` or `app.config.json` or `app.config.js` add the expo-braintree plugin:

```javascript
plugins: [
  [
    "react-native-expo-braintree",
    {
      host: "braintree-example-app.web.app",
      pathPrefix: "/braintree-payments", // Optional
      initialize3DSecure: "true",         // Optional, if you use 3D Secure
      initializeGooglePay: "true",        // Optional, if you use Google Pay
      initializeVenmo: "true",            // Optional, if you use Venmo
      addFallbackUrlScheme: "true",       // Optional, needed for Android Venmo/3DSecure fallback
      applePayMerchantIdentifier: "merchant.com.example", // Optional, if you use Apple Pay
    },
  ],
];
```

### Plugin Options

| Option | Description |
| :----- | :---------- |
| `host` | Domain that serves `.well-known/assetlinks.json` for Android App Links |
| `pathPrefix` | Path prefix for context switch handling (Optional) |
| `initialize3DSecure` | Whether to initialize 3D Secure launcher (`"true"` / `"false"`) |
| `initializeGooglePay` | Whether to initialize Google Pay launcher (`"true"` / `"false"`) |
| `initializeVenmo` | Whether to initialize Venmo context switching on iOS (`"true"` / `"false"`) |
| `addFallbackUrlScheme` | Whether to add a fallback URL scheme for Android Venmo (`"true"` / `"false"`) |
| `applePayMerchantIdentifier` | Apple Pay merchant ID or array of IDs added to the iOS `com.apple.developer.in-app-payments` entitlement (Optional) |

### Android Specific

The plugin modifies `AndroidManifest.xml` to add intent filters for App Links and fallback URL scheme.
It also injects `initGooglePay()` and `initThreeDSecure()` calls into `MainActivity.onCreate()` if enabled.

### iOS Specific

If `initializeVenmo` is set to `"true"`, the plugin automatically modifies `AppDelegate.swift` to handle URL callbacks for Venmo, configures `Info.plist` schemes, and registers `ExpoBraintreeConfig.swift`. No manual code modifications or Xcode configurations are required.

### Apple Pay

1. Register a merchant ID (for example `merchant.com.myapp`) in the Apple Developer portal and enable Apple Pay for your App ID.
2. Enable Apple Pay for that merchant ID in the Braintree Control Panel. This is where you create the Apple Pay Payment Processing Certificate.
3. Set `applePayMerchantIdentifier` in the plugin options to a merchant ID string or an array such as `["merchant.com.example", "merchant.com.example.store"]`. The plugin adds each merchant ID to your entitlements without duplicates. Apple Pay does not need any `AppDelegate` changes.
4. Run `npx expo prebuild` and rebuild the iOS app so Xcode picks up the new entitlement.
5. Use the iOS Simulator to exercise the sheet and delegate callbacks with simulated cards. Test the complete Braintree tokenization flow on an Apple Pay-capable physical device with an Apple Pay sandbox test card. See the [Apple Pay testing notes](USAGE_4.X.md#apple-pay-ios-only).

[withExpoBraintree.android.ts](src/plugin/withExpoBraintree.android.ts)
