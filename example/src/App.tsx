import * as React from 'react';

import {
  ActivityIndicator,
  Alert,
  Button,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import CardForm, { type CardFormValues } from './components/CardForm';
import {
  BTVenmoPaymntMethodUsage,
  BoolValue,
  getDeviceDataFromDataCollector,
  requestBillingAgreement,
  requestApplePayNonce,
  requestOneTimePayment,
  requestVenmoNonce,
  tokenizeCardData,
} from 'react-native-expo-braintree';

export const clientToken = 'sandbox_x62mvdjj_p8ngm2sczm8248vg';
export const merchantAppLink = 'https://braintree-example-app.web.app';
export const applePayMerchantIdentifier = 'merchant.com.example';

export default function App() {
  const [isLoading, setIsLoading] = React.useState(false);
  const [result, setResult] = React.useState('');

  return (
    <ScrollView
      contentContainerStyle={styles.scrollContent}
      keyboardShouldPersistTaps="handled"
    >
      <View style={styles.container}>
        <Text style={styles.heading}>Card Tokenization</Text>
        <Text style={styles.subheading}>
          The form below validates and formats card details locally before
          calling Braintree. Values never leave the device except for the
          tokenization request.
        </Text>

        <CardForm
          isSubmitting={isLoading}
          onSubmit={async ({
            number,
            expirationMonth,
            expirationYear,
            cvv,
            postalCode,
          }: CardFormValues) => {
            try {
              setIsLoading(true);
              const tokenizedCard = await tokenizeCardData({
                clientToken,
                number,
                expirationMonth,
                expirationYear,
                cvv,
                postalCode,
              });
              if ('nonce' in tokenizedCard) {
                const payload = JSON.stringify(tokenizedCard, null, 2);
                setResult(payload);
                console.log(payload);
                Alert.alert('Card Tokenized', `Nonce: ${tokenizedCard.nonce}`);
              } else {
                throw tokenizedCard;
              }
            } catch (ex: any) {
              const message = ex?.message ?? JSON.stringify(ex);
              setResult(message);
              Alert.alert('Card Tokenization Failed', message);
            } finally {
              setIsLoading(false);
            }
          }}
        />

        <Text style={styles.sectionHeading}>Other Payment Flows</Text>
      </View>

      <View style={styles.sectionBlock}>
        <Button
          title="Click Me to request Billing Agreement"
          onPress={async () => {
            try {
              setIsLoading(true);
              const localResult = await requestBillingAgreement({
                clientToken,
                merchantAppLink,
              });
              setIsLoading(false);
              setResult(JSON.stringify(localResult));
              console.log(JSON.stringify(localResult));
            } catch (ex) {
              setResult(JSON.stringify(ex));
              setResult(JSON.stringify(ex));

              console.log(JSON.stringify(ex));
            } finally {
              setIsLoading(false);
            }
          }}
        />

        <Button
          title="Trigger Apple Pay Sheet"
          onPress={async () => {
            try {
              setIsLoading(true);
              const applePayNonce = await requestApplePayNonce({
                clientToken,
                merchantIdentifier: applePayMerchantIdentifier,
                countryCode: 'US',
                currencyCode: 'USD',
                supportedNetworks: ['visa', 'masterCard', 'amex'],
                paymentSummaryItems: [
                  { label: 'Example Item', amount: '4.00' },
                  { label: 'Example Tax', amount: '1.00' },
                  { label: 'Expo Demo Total', amount: '5.00' },
                ],
              });
              setIsLoading(false);
              if ('nonce' in applePayNonce) {
                const noncePayload = JSON.stringify(applePayNonce, null, 2);
                setResult(noncePayload);
                console.log(noncePayload);
                Alert.alert(
                  'Apple Pay',
                  `Nonce created successfully.\n\n${applePayNonce.nonce}`
                );
              } else {
                throw applePayNonce;
              }
            } catch (ex: any) {
              const message = ex?.message ?? JSON.stringify(ex);
              setResult(JSON.stringify(ex));
              console.log(message);
              Alert.alert(
                'Apple Pay Unavailable',
                Platform.OS === 'ios'
                  ? `${message}\n\nTip: the simulator does not support the Apple Pay sheet; use a real device with Apple Pay configured.`
                  : message
              );
            } finally {
              setIsLoading(false);
            }
          }}
          disabled={Platform.OS !== 'ios'}
        />
        <Button
          title="Click Me To Get Device Data"
          onPress={async () => {
            try {
              setIsLoading(true);
              const resultDeviceData =
                await getDeviceDataFromDataCollector(clientToken);
              setIsLoading(false);
              setResult(JSON.stringify(resultDeviceData));
              console.log(JSON.stringify(resultDeviceData));
            } catch (ex) {
              setResult(JSON.stringify(ex));
              console.log(JSON.stringify(ex));
            } finally {
              setIsLoading(false);
            }
          }}
        />

        <Button
          title="Click Me To request One time Payment"
          onPress={async () => {
            try {
              setIsLoading(true);
              const resultDeviceData = await requestOneTimePayment({
                clientToken,
                amount: '5',
                merchantAppLink,
              });
              setIsLoading(false);
              setResult(JSON.stringify(resultDeviceData));
              console.log(JSON.stringify(resultDeviceData));
            } catch (ex) {
              setResult(JSON.stringify(ex));
              console.log(JSON.stringify(ex));
            } finally {
              setIsLoading(false);
            }
          }}
        />

        <Button
          title="Click Me To Tokenize Card"
          onPress={async () => {
            try {
              setIsLoading(true);
              const tokenizedCard = await tokenizeCardData({
                clientToken,
                number: '1111222233334444',
                expirationMonth: '11',
                expirationYear: '24',
                cvv: '123',
                postalCode: '',
              });
              setIsLoading(false);
              setResult(JSON.stringify(tokenizedCard));
              console.log(JSON.stringify(tokenizedCard));
            } catch (ex) {
              setResult(JSON.stringify(ex));
              console.log(JSON.stringify(ex));
            } finally {
              setIsLoading(false);
            }
          }}
        />

        <Button
          title="Click Me To Request a Venmo nonce"
          onPress={async () => {
            try {
              setIsLoading(true);
              const nonce = await requestVenmoNonce({
                clientToken,
                vault: BoolValue.true,
                paymentMethodUsage: BTVenmoPaymntMethodUsage.multiUse,
                totalAmount: '5',
              });
              setIsLoading(false);
              setResult(JSON.stringify(nonce));
              console.log(JSON.stringify(nonce));
            } catch (ex) {
              setResult(JSON.stringify(ex));
              console.log(ex);
            } finally {
              setIsLoading(false);
            }
          }}
        />
      </View>
      {isLoading && <ActivityIndicator />}
      {!!result && <Text style={styles.result}>{result}</Text>}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scrollContent: {
    padding: 24,
    paddingBottom: 48,
    backgroundColor: '#f4f6fb',
  },
  container: {
    gap: 16,
    marginBottom: 32,
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
  heading: {
    fontSize: 24,
    fontWeight: '700',
    color: '#0f172a',
  },
  subheading: {
    fontSize: 14,
    color: '#475569',
    lineHeight: 20,
  },
  sectionHeading: {
    marginTop: 24,
    fontSize: 18,
    fontWeight: '600',
    color: '#1f2937',
  },
  sectionBlock: {
    gap: 16,
  },
  result: {
    paddingHorizontal: 24,
    textAlign: 'center',
    fontFamily:
      Platform.select({ ios: 'Menlo', android: 'monospace' }) ?? undefined,
    marginTop: 24,
    color: '#111827',
  },
});
