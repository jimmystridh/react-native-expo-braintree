import {
  IOSConfig,
  WarningAggregator,
  withAppDelegate,
  withEntitlementsPlist,
  withInfoPlist,
  type ConfigPlugin,
  type ExportedConfigWithProps,
} from '@expo/config-plugins';
import eol from 'eol';
import type { AppDelegateProjectFile } from '@expo/config-plugins/build/ios/Paths';

/*
 * Mods for Info.plist
 */
export const withExpoBraintreePlist: ConfigPlugin = (expoConfig) => {
  return withInfoPlist(expoConfig, (config) => {
    let bundleIdentifier = '';
    try {
      bundleIdentifier =
        IOSConfig.BundleIdentifier.getBundleIdentifier(config) ?? '';
    } catch {
      bundleIdentifier = config.ios?.bundleIdentifier ?? '';
    }

    if (!bundleIdentifier) {
      WarningAggregator.addWarningIOS(
        'withExpoBraintree',
        'ios.bundleIdentifier is not defined in your Expo config (app.json). The Braintree URL scheme cannot be generated correctly.'
      );
    }

    const bundleIdentifierWithBraintreeSchema = `${bundleIdentifier}.braintree`;
    const bundleUrlTypes = config.modResults.CFBundleURLTypes ?? [];

    // Check if an entry with the specific Braintree URL scheme already exists
    const isBraintreeEntryNotExist = !bundleUrlTypes.find((urlType) => {
      return urlType.CFBundleURLSchemes?.includes(
        bundleIdentifierWithBraintreeSchema
      );
    });

    // If Braintree entry doesn't exist, add a new one
    if (isBraintreeEntryNotExist && bundleIdentifier) {
      bundleUrlTypes.push({
        CFBundleURLSchemes: [bundleIdentifierWithBraintreeSchema],
      });
    }

    // Assign the modified bundleUrlTypes back to the config
    config.modResults.CFBundleURLTypes = bundleUrlTypes;

    return config;
  });
};

/*
 * Add allowlist Venmo URL scheme
 * @see https://developer.paypal.com/braintree/docs/guides/venmo/client-side/ios/v6#allowlist-venmo-url-scheme
 */
export const withVenmoScheme: ConfigPlugin = (expoConfig) => {
  return withInfoPlist(expoConfig, (config) => {
    // Ensure LSApplicationQueriesSchemes exists in Info.plist
    config.modResults.LSApplicationQueriesSchemes =
      config.modResults.LSApplicationQueriesSchemes || [];

    // Hardcoded scheme for Venmo
    const venmoScheme = 'com.venmo.touch.v2';

    // Add the Venmo scheme to the LSApplicationQueriesSchemes array if not already present
    if (!config.modResults.LSApplicationQueriesSchemes.includes(venmoScheme)) {
      config.modResults.LSApplicationQueriesSchemes.push(venmoScheme);
    }

    return config;
  });
};

const APPLE_PAY_ENTITLEMENT = 'com.apple.developer.in-app-payments';

export type ApplePayMerchantIdentifiers =
  | string
  | (string | undefined)[]
  | undefined;

const normalizeApplePayMerchantIdentifiers = (
  merchantIdentifier: ApplePayMerchantIdentifiers = []
): string[] => {
  const identifiers = Array.isArray(merchantIdentifier)
    ? merchantIdentifier
    : [merchantIdentifier];
  return identifiers
    .filter(
      (identifier): identifier is string => typeof identifier === 'string'
    )
    .map((identifier) => identifier.trim())
    .filter((identifier) => identifier.length > 0);
};

export const addApplePayMerchantId = <T extends Record<string, unknown>>(
  entitlements: T,
  merchantIdentifier: ApplePayMerchantIdentifiers
): T => {
  return mergeApplePayMerchantIdentifiers(
    entitlements,
    normalizeApplePayMerchantIdentifiers(merchantIdentifier)
  );
};

const mergeApplePayMerchantIdentifiers = <T extends Record<string, unknown>>(
  entitlements: T,
  identifiers: string[]
): T => {
  if (identifiers.length === 0) {
    return entitlements;
  }

  const existingValue = entitlements[APPLE_PAY_ENTITLEMENT];
  const merchantIds = Array.isArray(existingValue)
    ? existingValue.filter((value) => typeof value === 'string')
    : [];

  for (const identifier of identifiers) {
    if (!merchantIds.includes(identifier)) {
      merchantIds.push(identifier);
    }
  }

  return { ...entitlements, [APPLE_PAY_ENTITLEMENT]: merchantIds };
};

/*
 * Add Apple Pay merchant IDs to the in-app payments entitlement
 * @see https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.in-app-payments
 */
export const withApplePayMerchantId: ConfigPlugin<
  ApplePayMerchantIdentifiers
> = (expoConfig, merchantIdentifier) => {
  const identifiers = normalizeApplePayMerchantIdentifiers(merchantIdentifier);
  if (identifiers.length === 0) {
    return expoConfig;
  }

  return withEntitlementsPlist(expoConfig, (config) => {
    config.modResults = mergeApplePayMerchantIdentifiers(
      config.modResults,
      identifiers
    );
    return config;
  });
};

/**
 * Mods for AppDelegate.swift React Native above 0.77.x and Expo above 53
 */
export const modifyAppDelegateSwift = (
  config: ExportedConfigWithProps<AppDelegateProjectFile>
) => {
  const appDelegate = config.modResults;
  let contents = eol.split(appDelegate.contents);

  // Step 1 Add method to properly handle openUrl method in AppDelegate.swift
  const openUrlIdentifier = `options: [UIApplication.OpenURLOptionsKey: Any] = [:]`;

  const expoBraintreeConfigHandleUrl = `return ExpoBraintreeConfig.handleUrl(url: url)`;
  const expoBraintreeOpenUrlLines = [
    `    // @generated by react-native-expo-braintree (DO NOT MODIFY)`,
    `    if url.scheme?.localizedCaseInsensitiveCompare(`,
    `      ExpoBraintreeConfig.paymentURLScheme`,
    `    ) == .orderedSame {`,
    `      ${expoBraintreeConfigHandleUrl}`,
    `    }`,
    `    // @generated by react-native-expo-braintree (DO NOT MODIFY)`,
  ];
  const openUrlIdentifierElementIndex = contents.findIndex((content) =>
    content.includes(openUrlIdentifier)
  );

  // Step 2 If openUrlIdentifierElementIndex exist in AppDelegate.swift then we only need to add expoBraintreeOpenUrlLines at the top of that method
  if (openUrlIdentifierElementIndex !== -1) {
    contents.splice(
      // We are adding +2 to the index to insert content after ') -> Bool {' block
      openUrlIdentifierElementIndex + 2,
      0,
      ...expoBraintreeOpenUrlLines
    );
  }
  // Step 3 If openUrlIdentifierElementIndex do not exist in AppDelegate.swift add a warning that something went wrong
  else {
    WarningAggregator.addWarningIOS(
      'withExpoBraintree',
      `Unable to find "options: [UIApplication.OpenURLOptionsKey: Any] = [:]" in AppDelegate.swift, automatic changes not applied expo-braintree might not working as expected`
    );
  }

  const expoBraintreeConfigHandleUrlElementIndex = contents.findIndex(
    (content) => content.includes(expoBraintreeConfigHandleUrl)
  );

  if (expoBraintreeConfigHandleUrlElementIndex === -1) {
    WarningAggregator.addWarningIOS(
      'withExpoBraintree',
      `Unable to find "return ExpoBraintreeConfig.handleUrl(url: url)" in AppDelegate.swift, automatic changes not applied expo-braintree might not working as expected`
    );
  }
  return contents;
};

export const withExpoBraintreeAppDelegate: ConfigPlugin = (expoConfig) => {
  return withAppDelegate(expoConfig, (config) => {
    const appDelegateLanguage = config.modResults.language;
    if (appDelegateLanguage === 'swift') {
      const resultSwift = modifyAppDelegateSwift(config);
      config.modResults.contents = resultSwift.join('\n');
    } else {
      WarningAggregator.addWarningIOS(
        'withExpoBraintree',
        `Objective-C/Objective-C++ AppDelegate (${appDelegateLanguage}) is not supported in version 4.0.0. Please upgrade your project to a Swift AppDelegate.`
      );
    }
    return config;
  });
};

// Add a new wrapper Swift file to the Xcode project for Swift compatibility.
export const withBraintreeWrapperFile: ConfigPlugin = (config) => {
  const braintreeWrapperSwift = [
    'import Braintree',
    'import Foundation',
    '',
    'public final class ExpoBraintreeConfig {',
    '',
    ' private init() {}',
    '',
    ' public static var paymentURLScheme: String {',
    '   let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""',
    '   return bundleIdentifier + ".braintree"',
    ' }',
    '',
    ' public static func handleUrl(url: URL) -> Bool {',
    '   return BTAppContextSwitcher.sharedInstance.handleOpen(url)',
    ' }',
    '}',
  ];

  return IOSConfig.XcodeProjectFile.withBuildSourceFile(config, {
    filePath: 'ExpoBraintreeConfig.swift',
    contents: braintreeWrapperSwift.join('\n'),
  });
};
