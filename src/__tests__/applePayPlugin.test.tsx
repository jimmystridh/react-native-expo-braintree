import type { ExportedConfig } from '@expo/config-plugins';
import {
  addApplePayMerchantId,
  withApplePayMerchantId,
  type ApplePayMerchantIdentifiers,
} from '../plugin/withExpoBraintree.ios';

const {
  withExpoBraintreePlugin,
}: typeof import('../plugin/withExpoBraintree') = require('../plugin/withExpoBraintree.ts');

const entitlementKey = 'com.apple.developer.in-app-payments';
const emptyMerchantIds: { identifiers: ApplePayMerchantIdentifiers }[] = [
  { identifiers: [] },
  { identifiers: undefined },
  { identifiers: [undefined] },
  { identifiers: '' },
  { identifiers: ' \t\n ' },
  { identifiers: ['', ' ', '\t\n'] },
];

describe('addApplePayMerchantId', () => {
  it('creates the in-app payments entitlement', () => {
    expect(
      addApplePayMerchantId({ 'aps-environment': 'development' }, 'merchant.a')
    ).toEqual({
      'aps-environment': 'development',
      [entitlementKey]: ['merchant.a'],
    });
  });

  it('keeps existing merchant IDs and does not duplicate', () => {
    const entitlements = { [entitlementKey]: ['merchant.a', 'merchant.b'] };

    expect(addApplePayMerchantId(entitlements, 'merchant.b')).toEqual(
      entitlements
    );
    expect(addApplePayMerchantId(entitlements, 'merchant.c')).toEqual({
      [entitlementKey]: ['merchant.a', 'merchant.b', 'merchant.c'],
    });
  });

  it('accepts multiple merchant IDs and adds each only once', () => {
    const entitlements = {
      'aps-environment': 'development',
      [entitlementKey]: ['merchant.a'],
    };

    expect(
      addApplePayMerchantId(entitlements, [
        'merchant.a',
        'merchant.b',
        'merchant.b',
        'merchant.c',
      ])
    ).toEqual({
      'aps-environment': 'development',
      [entitlementKey]: ['merchant.a', 'merchant.b', 'merchant.c'],
    });
    expect(entitlements[entitlementKey]).toEqual(['merchant.a']);
  });

  it('preserves existing IDs when given an empty array', () => {
    const entitlements = { [entitlementKey]: ['merchant.a'] };

    expect(addApplePayMerchantId(entitlements, [])).toEqual(entitlements);
  });
});

describe('empty Apple Pay merchant identifiers', () => {
  it.each(emptyMerchantIds)(
    'does not add an entitlement for $identifiers',
    ({ identifiers }) => {
      const entitlements = { 'aps-environment': 'development' };
      const result = addApplePayMerchantId(entitlements, identifiers);

      expect(result).toEqual(entitlements);
      expect(result).not.toHaveProperty([entitlementKey]);
    }
  );

  it.each(emptyMerchantIds)(
    'does not register the entitlement mod for $identifiers',
    ({ identifiers }) => {
      const config = { name: 'Test app', slug: 'test-app' };

      const result: ExportedConfig = withApplePayMerchantId(
        config,
        identifiers
      );

      expect(result.mods?.ios?.entitlements).toBeUndefined();
    }
  );

  it.each(emptyMerchantIds)(
    'skips Apple Pay in the top-level plugin for $identifiers',
    ({ identifiers }) => {
      const config: ExportedConfig = withExpoBraintreePlugin(
        { name: 'Test app', slug: 'test-app' },
        {
          host: 'example.com',
          applePayMerchantIdentifier: identifiers,
        }
      );

      expect(config.mods?.ios?.entitlements).toBeUndefined();
    }
  );
});

describe('non-empty Apple Pay merchant identifiers', () => {
  it('drops blank IDs, trims valid IDs, and preserves existing entitlements', () => {
    const entitlements = {
      'aps-environment': 'development',
      [entitlementKey]: ['merchant.existing'],
    };

    expect(
      addApplePayMerchantId(entitlements, [
        undefined,
        '',
        ' \t ',
        ' merchant.new ',
        'merchant.new',
        '\nmerchant.other\t',
      ])
    ).toEqual({
      'aps-environment': 'development',
      [entitlementKey]: ['merchant.existing', 'merchant.new', 'merchant.other'],
    });
    expect(entitlements[entitlementKey]).toEqual(['merchant.existing']);
  });

  it('trims a single merchant ID', () => {
    expect(addApplePayMerchantId({}, ' merchant.example ')).toEqual({
      [entitlementKey]: ['merchant.example'],
    });
  });

  it('still registers Apple Pay when the list contains a valid ID', () => {
    const config: ExportedConfig = withExpoBraintreePlugin(
      { name: 'Test app', slug: 'test-app' },
      {
        host: 'example.com',
        applePayMerchantIdentifier: [undefined, '', ' merchant.example ', ' '],
      }
    );

    expect(config.mods?.ios?.entitlements).toEqual(expect.any(Function));
  });
});
