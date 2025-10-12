import { type ConfigPlugin, createRunOncePlugin } from '@expo/config-plugins';
import { withExpoBraintreeAndroid } from './withExpoBraintree.android';
import {
  withExpoBraintreeAppDelegate,
  withExpoBraintreePlist,
  withSwiftBraintreeWrapperFile,
  withApplePayMerchantIds,
  withVenmoScheme,
} from './withExpoBraintree.ios';

const path = require('path');

const fallbackPackagePath = path.join(
  __dirname,
  '..',
  '..',
  '..',
  'package.json'
);

const pkg = (() => {
  try {
    return require('react-native-expo-braintree/package.json');
  } catch (error) {
    return require(fallbackPackagePath);
  }
})();

export type ExpoBraintreePluginProps = {
  /**
   * xCode project name, used for importing the swift expo braintree config header
   */
  xCodeProjectAppName: string;

  /**
   * Android AppLink host
   */
  host: string;

  /**
   * Android AppLink pathPrefix
   */
  pathPrefix?: string;

  /**
   * Optional Apple Pay merchant identifier added to entitlements
   */
  applePayMerchantIdentifier?: string;
};

export const withExpoBraintreePlugin: ConfigPlugin<ExpoBraintreePluginProps> = (
  expoConfig,
  props
) => {
  // Android mods
  let config = withExpoBraintreeAndroid(expoConfig, props);
  // IOS mods
  config = withSwiftBraintreeWrapperFile(config);
  config = withExpoBraintreeAppDelegate(config, props);
  config = withExpoBraintreePlist(config);
  config = withVenmoScheme(config);
  config = withApplePayMerchantIds(config, props);

  return config;
};

export default createRunOncePlugin(
  withExpoBraintreePlugin,
  pkg.name,
  pkg.version
);
