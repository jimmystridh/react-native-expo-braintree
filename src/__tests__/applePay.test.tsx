import { Platform } from 'react-native';
import {
  APPLE_PAY_ERROR_TYPES,
  EXCEPTION_TYPES,
  requestApplePayPayment,
  type BTApplePayContact,
  type BTApplePayNonceResult,
  type BTApplePayShippingMethod,
  type RequestApplePayOptions,
} from '../index';

const mockRequestApplePayPayment = jest.fn();

jest.mock('react-native-nitro-modules', () => ({
  NitroModules: {
    createHybridObject: () => ({
      requestApplePayPayment: (...args: unknown[]) =>
        mockRequestApplePayPayment(...args),
    }),
  },
}));

const options: RequestApplePayOptions = {
  clientToken: 'sandbox_token',
  merchantIdentifier: 'merchant.com.example',
  supportedNetworks: ['visa', 'masterCard'],
  paymentSummaryItems: [
    { label: 'Item', amount: '4.00' },
    { label: 'Example Inc.', amount: '4.00', type: 'final' },
  ],
  billingContact: { givenName: 'Ada', postalAddress: { city: 'London' } },
};

describe('requestApplePayPayment', () => {
  beforeEach(() => {
    mockRequestApplePayPayment.mockReset();
    jest.replaceProperty(Platform, 'OS', 'ios');
  });

  it('sends strings as-is and nested values as JSON to native', async () => {
    mockRequestApplePayPayment.mockResolvedValue({ nonce: 'fake-nonce' });

    await requestApplePayPayment(options);

    expect(mockRequestApplePayPayment).toHaveBeenCalledWith({
      clientToken: 'sandbox_token',
      merchantIdentifier: 'merchant.com.example',
      supportedNetworks: '["visa","masterCard"]',
      paymentSummaryItems:
        '[{"label":"Item","amount":"4.00"},{"label":"Example Inc.","amount":"4.00","type":"final"}]',
      billingContact: '{"givenName":"Ada","postalAddress":{"city":"London"}}',
    });
  });

  it('parses booleans and bin data in the nonce result', async () => {
    mockRequestApplePayPayment.mockResolvedValue({
      nonce: 'fake-nonce',
      type: 'ApplePayCard',
      isDefault: 'false',
      isDeviceToken: 'true',
      cardNetwork: 'Visa',
      binData: '{"prepaid":"No","debit":"Yes"}',
    });

    await expect(requestApplePayPayment(options)).resolves.toEqual({
      nonce: 'fake-nonce',
      type: 'ApplePayCard',
      isDefault: false,
      isDeviceToken: true,
      cardNetwork: 'Visa',
      binData: { prepaid: 'No', debit: 'Yes' },
    });
  });

  it('returns the authorized contacts and selected shipping method as objects', async () => {
    const billingContact: BTApplePayContact = {
      givenName: 'Ada',
      familyName: 'Lovelace',
      postalAddress: { street: '1 Billing Street', countryCode: 'GB' },
    };
    const shippingContact: BTApplePayContact = {
      emailAddress: 'ada@example.com',
      phoneNumber: '+44 20 1234 5678',
      givenName: 'Ada',
      familyName: 'Lovelace',
      phoneticGivenName: 'Ay-duh',
      phoneticFamilyName: 'Luv-lays',
      postalAddress: {
        street: '2 Shipping Street\nFlat 3',
        city: 'London',
        state: 'London',
        postalCode: 'SW1A 1AA',
        country: 'United Kingdom',
        countryCode: 'GB',
        subAdministrativeArea: 'Westminster',
        subLocality: 'St James’s',
      },
    };
    const shippingMethod: BTApplePayShippingMethod = {
      identifier: 'express',
      label: 'Express delivery',
      detail: 'Next day',
      amount: '7.25',
      type: 'final',
    };
    const expected: BTApplePayNonceResult = {
      nonce: 'fake-nonce',
      type: 'ApplePayCard',
      isDefault: false,
      isDeviceToken: true,
      billingContact,
      shippingContact,
      shippingMethod,
    };
    mockRequestApplePayPayment.mockResolvedValue({
      ...expected,
      isDefault: 'false',
      isDeviceToken: 'true',
      billingContact: JSON.stringify(billingContact),
      shippingContact: JSON.stringify(shippingContact),
      shippingMethod: JSON.stringify(shippingMethod),
    });

    await expect(requestApplePayPayment(options)).resolves.toEqual(expected);
  });

  it('returns native errors instead of throwing', async () => {
    const nativeError = {
      error: 'true',
      code: EXCEPTION_TYPES.USER_CANCEL_EXCEPTION,
      message: APPLE_PAY_ERROR_TYPES.APPLE_PAY_USER_CANCELLATION_ERROR,
      domain: APPLE_PAY_ERROR_TYPES.APPLE_PAY_USER_CANCELLATION_ERROR,
      nativeError: 'User closed the Apple Pay sheet',
    };
    mockRequestApplePayPayment.mockResolvedValue(nativeError);

    await expect(requestApplePayPayment(options)).resolves.toEqual(nativeError);
  });

  it('does not call native code on Android', async () => {
    jest.replaceProperty(Platform, 'OS', 'android');

    const result = await requestApplePayPayment(options);

    expect(mockRequestApplePayPayment).not.toHaveBeenCalled();
    expect(result).toMatchObject({
      error: 'true',
      message: APPLE_PAY_ERROR_TYPES.APPLE_PAY_NOT_AVAILABLE_ERROR,
    });
  });
});
