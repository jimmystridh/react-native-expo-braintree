import { Platform } from 'react-native';
import { EXCEPTION_TYPES, requestApplePayPayment } from '../index';

jest.mock('react-native', () => ({ Platform: { OS: 'web' } }));
jest.mock('react-native-nitro-modules', () => {
  throw new Error('Native NitroModules are unavailable on this platform');
});

it.each(['web', 'windows', 'macos'] as const)(
  'imports and reports Apple Pay as unsupported on %s without loading Nitro',
  async (platform) => {
    jest.replaceProperty(Platform, 'OS', platform);
    await expect(
      requestApplePayPayment({
        clientToken: 'unused',
        paymentSummaryItems: [{ label: 'Merchant', amount: '5.00' }],
      })
    ).resolves.toMatchObject({
      code: EXCEPTION_TYPES.UNSUPPORTED_PLATFORM_EXCEPTION,
      nativeError: 'Apple Pay is only supported on iOS.',
    });
  }
);
