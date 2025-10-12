# React Native Bare Project (react-native-cli)
## Package Version 3.x.x

Please follow and Finish [Set Up App Links](https://github.com/braintree/braintree_android/blob/main/APP_LINK_SETUP.md), before the next steps.

### Android Specific

In Your `AndroidManifest.xml`, add this intent-filter to your main activity in `AndroidManifest.xml`
`braintree-example-app.web.app` should be replaced with your own domain that you defined in [Set Up App Links](https://github.com/braintree/braintree_android/blob/main/APP_LINK_SETUP.md)


```xml
<activity>
    ...
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" />
        <data android:host="braintree-example-app.web.app" />
    </intent-filter>
</activity>

```

Initialize, the Braintree, module. in your android/app/src/main/java/com/{app_name}/MainApplication.kt

```
import com.expobraintree.ExpoBraintreeModule

  override fun onCreate() {
    ...
    ExpoBraintreeModule.init()
    ...
  }

```

### iOS Specific
```bash
cd ios
pod install
```
#### Configure a new URL scheme
Add a bundle url scheme {BUNDLE_IDENTIFIER}.braintree in your app Info via XCode or manually in the Info.plist. In your Info.plist, you should have something like: 

```xml 
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.myapp</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.myapp.braintree</string>
        </array>
    </dict>
</array>
```
#### Update your code
From version 2.0.0 of the expo-braintree, for the IOS part of the setup there is need to make few more additional steps to integrate the library into your project. The reason is that Braintree SDk from version v6, reimplement all the IOS resources to use swift. Because of that we not longer can use Braintree Header files into AppDelegate.m file. And we need to create our own swift wrapper that can be accessible in AppDelegate.m file.

- Open your React Native ios Project in xCode
- Create ExpoBraintreeConfig.swift in your project, while creating the .swift file xCode will ask if you want to automatically create your {AppName}-Bridging-Header.h - Allow that
- Put following content into ExpoBraintreeConfig.swift

```swift
import Braintree
import Foundation

@objc public class ExpoBraintreeConfig: NSObject {

  @objc(configure)
  public static func configure() {
    BTAppContextSwitcher.sharedInstance.returnURLScheme = self.getPaymentUrlScheme()
  }

  @objc(getPaymentUrlScheme)
  public static func getPaymentUrlScheme() -> String {
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
    return bundleIdentifier + ".braintree"
  }

  @objc(handleUrl:)
  public static func handleUrl(url: URL) -> Bool {
    return BTAppContextSwitcher.sharedInstance.handleOpen(url)
  }
}
```
- Update Content of you AppDelegate.m


```objective-c
#import "{AppName}}-Swift.h"
#import <React/RCTLinkingManager.h>

...
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    ...
    [ExpoBraintreeConfig configure];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {

    if ([url.scheme localizedCaseInsensitiveCompare:[ExpoBraintreeConfig getPaymentUrlScheme]] == NSOrderedSame) {
        return [ExpoBraintreeConfig handleUrl:url];
    }
    
    return [RCTLinkingManager application:application openURL:url options:options];
}

```
The same steps are already implemented into example app, if you have any issues please check it.

#### Apple Pay Setup

To use `requestApplePayNonce` in a bare workflow you must configure Apple Pay manually:

1. **Create a Merchant ID** – In the Apple Developer portal register a merchant identifier such as `merchant.com.myapp.payments` and enable Apple Pay for your App ID.
2. **Update entitlements** – Add the merchant ID to your app’s entitlements (`ios/{AppName}/{AppName}.entitlements`):

   ```xml
   <key>com.apple.developer.in-app-payments</key>
   <array>
     <string>merchant.com.myapp.payments</string>
   </array>
   ```

3. **Sync capabilities in Xcode** – In the “Signing & Capabilities” tab ensure “Apple Pay” is checked and the merchant ID you created is selected.
4. **Reinstall pods** – Run `npx pod-install` so the `Braintree/ApplePay` subspec is available (already declared in the podspec included with this library).
5. **Use the JS helper** – With entitlements in place you can call:

   ```ts
   import { requestApplePayNonce } from 'react-native-expo-braintree';

   const nonce = await requestApplePayNonce({
     clientToken,
     merchantIdentifier: 'merchant.com.myapp.payments',
     countryCode: 'US',
     currencyCode: 'USD',
     supportedNetworks: ['visa', 'masterCard'],
     paymentSummaryItems: [
       { label: 'Example Item', amount: '10.00' },
       { label: 'Total', amount: '10.00' },
     ],
   });
   ```

   The method returns a nonce on success or an error describing what failed.

6. **Test on a real device** – The iOS simulator does not present the Apple Pay sheet, so use a physical iPhone with Apple Pay configured to verify the flow end-to-end.
