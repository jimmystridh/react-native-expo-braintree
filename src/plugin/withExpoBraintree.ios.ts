/* eslint-disable no-bitwise */
import {
  IOSConfig,
  withAppDelegate,
  withInfoPlist,
  withEntitlementsPlist,
  type ConfigPlugin,
} from '@expo/config-plugins';
import eol from 'eol';
import type { ExpoBraintreePluginProps } from './withExpoBraintree';

export const withExpoBraintreeAppDelegate: ConfigPlugin<
  ExpoBraintreePluginProps
> = (expoConfig, { xCodeProjectAppName }) => {
  return withAppDelegate(expoConfig, (config) => {
    const appDelegate = config.modResults;
    if (appDelegate.language === 'swift') {
      config.modResults.contents = modifySwiftAppDelegate(appDelegate.contents);
      return config;
    }

    let contents = eol.split(appDelegate.contents);
    // Step 1 Edit Import part
    // Editing import part for -swift.h file to be able to use Braintree
    const importSwiftHeaderFileContent = `#import "${xCodeProjectAppName}-Swift.h"`;
    const importSwiftHeaderFileIndex = contents.findIndex((content) =>
      content.includes(importSwiftHeaderFileContent)
    );
    // If importSwiftHeaderFileContent do not exist in AppDelegate.mm
    if (!~importSwiftHeaderFileIndex) {
      contents = [importSwiftHeaderFileContent, ...contents];
    }
    const importExpoModulesSwiftHeader = `#import "ExpoModulesCore-Swift.h"`;
    const importExpoModulesSwiftHeaderFileIndex = contents.findIndex(
      (content) => content.includes(importExpoModulesSwiftHeader)
    );
    // If importExpoModulesSwiftHeader do not exist in AppDelegate.mm
    if (!~importExpoModulesSwiftHeaderFileIndex) {
      contents = [importExpoModulesSwiftHeader, ...contents];
    }
    // Step 2 Add configure method in didFinishLaunchingWithOptions
    const didFinishLaunchingWithOptions = 'didFinishLaunchingWithOptions';
    const expoBraintreeConfigureLine = '  [BraintreeExpoConfig configure];';
    let didFinishLaunchingWithOptionsElementIndex = contents.findIndex(
      (content) => content.includes(didFinishLaunchingWithOptions)
    );
    const expoBraintreeConfigureLineIndex = contents.findIndex((content) =>
      content.includes(expoBraintreeConfigureLine)
    );
    // If didFinishLaunchingWithOptions exist in AppDelegate.mm and expoBraintreeConfigureLine do not exist
    if (
      !~expoBraintreeConfigureLineIndex &&
      !!~didFinishLaunchingWithOptionsElementIndex
    ) {
      contents.splice(
        // We are adding +2 to the index to insert content after '{' block
        didFinishLaunchingWithOptionsElementIndex + 2,
        0,
        expoBraintreeConfigureLine
      );
    }
    // Step 3 Add method to properly handle openUrl method in AppDelegate.m
    const openUrlMethod =
      '- (BOOL)application:(UIApplication *)application openURL';
    const expoBraintreeOpenUrlLines = [
      '  if ([url.scheme localizedCaseInsensitiveCompare:[BraintreeExpoConfig getPaymentUrlScheme]] == NSOrderedSame) {',
      '    return [BraintreeExpoConfig handleUrl:url];',
      '  }',
    ];
    const openUrlMethodElementIndex = contents.findIndex((content) =>
      content.includes(openUrlMethod)
    );
    const expoBraintreeOpenUrlLineIndex = contents.findIndex((content) =>
      content.includes(expoBraintreeOpenUrlLines?.[0] ?? '')
    );
    // If openUrlMethodElementIndex exist in AppDelegate.mm and expoBraintreeOpenUrlLineIndex do not exist
    if (!~expoBraintreeOpenUrlLineIndex && !!~openUrlMethodElementIndex) {
      contents.splice(
        // We are adding +1 to the index to insert content after '{' block
        openUrlMethodElementIndex + 1,
        0,
        ...expoBraintreeOpenUrlLines
      );
    }
    config.modResults.contents = contents.join('\n');
    return config;
  });
};

function modifySwiftAppDelegate(appDelegateContents: string): string {
  const lines = eol.split(appDelegateContents);
  const updatedLines: string[] = [];
  const importsToOmit = new Set([
    '#import "ExpoModulesCore-Swift.h"',
    '#import "ExpoBraintree-Swift.h"',
  ]);

  const configureCall = 'BraintreeExpoConfig.configure()';
  let didInsertConfigure = appDelegateContents.includes(configureCall);
  let didInsertHandle = appDelegateContents.includes(
    'BraintreeExpoConfig.handleUrl'
  );
  let awaitingConfigureBody = false;
  let awaitingHandleBody = false;

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i] ?? '';
    if (importsToOmit.has(line.trim())) {
      continue;
    }
    if (line.includes('[BraintreeExpoConfig configure];')) {
      updatedLines.push('    BraintreeExpoConfig.configure()');
      didInsertConfigure = true;
      continue;
    }
    if (!didInsertConfigure && line.includes('didFinishLaunchingWithOptions')) {
      awaitingConfigureBody = true;
    }

    if (!didInsertHandle && line.includes('open url: URL')) {
      awaitingHandleBody = true;
    }

    updatedLines.push(line);

    if (awaitingConfigureBody && line.includes(') -> Bool {')) {
      const indentation = line.match(/^(\s*)/)?.[1] ?? '';
      const bodyIndentation = `${indentation}  `;
      updatedLines.push(`${bodyIndentation}${configureCall}`);
      didInsertConfigure = true;
      awaitingConfigureBody = false;
    }

    if (awaitingHandleBody && line.includes(') -> Bool {')) {
      const indentation = line.match(/^(\s*)/)?.[1] ?? '';
      const bodyIndentation = `${indentation}  `;
      updatedLines.push(
        `${bodyIndentation}if BraintreeExpoConfig.handleUrl(url: url) {`
      );
      updatedLines.push(`${bodyIndentation}  return true`);
      updatedLines.push(`${bodyIndentation}}`);
      didInsertHandle = true;
      awaitingHandleBody = false;
    }
  }

  return updatedLines.join('\n');
}

/**
 * Add a new wrapper Swift file to the Xcode project for Swift compatibility.
 */
export const withSwiftBraintreeWrapperFile: ConfigPlugin = (config) => {
  return IOSConfig.XcodeProjectFile.withBuildSourceFile(config, {
    filePath: 'BraintreeExpoConfig.swift',
    contents: [
      'import Braintree',
      'import Foundation',
      '',
      '@objc public class BraintreeExpoConfig: NSObject {',
      '',
      '@objc(configure)',
      'public static func configure() {',
      '  BTAppContextSwitcher.sharedInstance.returnURLScheme = self.getPaymentUrlScheme()',
      '}',
      '',
      '@objc(getPaymentUrlScheme)',
      'public static func getPaymentUrlScheme() -> String {',
      '  let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""',
      '  return bundleIdentifier + ".braintree"',
      '}',
      '',
      '@objc(handleUrl:)',
      'public static func handleUrl(url: URL) -> Bool {',
      '  return BTAppContextSwitcher.sharedInstance.handleOpen(url)',
      '}',
      '}',
    ].join('\n'),
  });
};

export const withExpoBraintreePlist: ConfigPlugin = (expoConfig) => {
  return withInfoPlist(expoConfig, (config) => {
    const bundleIdentifier = config.ios?.bundleIdentifier ?? '';
    const bundleIdentifierWithBraintreeSchema = `${bundleIdentifier}.braintree`;
    const bundleUrlTypes = config.modResults.CFBundleURLTypes ?? [];

    // Check if an entry with the specific Braintree URL scheme already exists
    const isBraintreeEntryNotExist = !bundleUrlTypes.find((urlType) => {
      return urlType.CFBundleURLSchemes?.includes(
        bundleIdentifierWithBraintreeSchema
      );
    });

    // If Braintree entry doesn't exist, add a new one
    if (isBraintreeEntryNotExist) {
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

export const withApplePayMerchantIds: ConfigPlugin<ExpoBraintreePluginProps> = (
  expoConfig,
  { applePayMerchantIdentifier }
) => {
  return withEntitlementsPlist(expoConfig, (config) => {
    if (!applePayMerchantIdentifier) {
      return config;
    }

    const entitlementKey = 'com.apple.developer.in-app-payments';
    const existingValue = config.modResults[entitlementKey];
    const merchantIds = Array.isArray(existingValue) ? [...existingValue] : [];

    if (!merchantIds.includes(applePayMerchantIdentifier)) {
      merchantIds.push(applePayMerchantIdentifier);
    }

    config.modResults[entitlementKey] = merchantIds;
    return config;
  });
};
