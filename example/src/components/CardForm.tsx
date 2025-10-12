import * as React from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  StyleSheet,
  Text,
  TextInput,
  View,
  TouchableOpacity,
} from 'react-native';

export type CardFormValues = {
  number: string;
  expirationMonth: string;
  expirationYear: string;
  cvv: string;
  postalCode: string;
};

export type CardFormProps = {
  onSubmit(values: CardFormValues): Promise<void> | void;
  isSubmitting?: boolean;
};

const initialState: CardFormValues = {
  number: '',
  expirationMonth: '',
  expirationYear: '',
  cvv: '',
  postalCode: '',
};

type FieldName = keyof CardFormValues;

type CardFormErrors = Partial<Record<FieldName, string>>;

type CardBrand = 'visa' | 'mastercard' | 'amex' | 'discover' | 'unknown';

const cardBrandPatterns: Record<CardBrand, RegExp> = {
  visa: /^4\d{0,15}$/,
  mastercard: /^(5[1-5]\d{0,14}|2[2-7]\d{0,14})$/,
  amex: /^3[47]\d{0,13}$/,
  discover: /^(6011|65|64[4-9])\d{0,15}$/,
  unknown: /^.*$/,
};

type Action =
  | { type: 'SET_FIELD'; field: FieldName; value: string }
  | { type: 'RESET' };

function formReducer(state: CardFormValues, action: Action): CardFormValues {
  switch (action.type) {
    case 'SET_FIELD':
      return {
        ...state,
        [action.field]: action.value,
      };
    case 'RESET':
      return initialState;
    default:
      return state;
  }
}

function formatCardNumber(raw: string): string {
  const digits = raw.replace(/\D+/g, '');
  const brand = detectCardBrand(digits);
  if (brand === 'amex') {
    return digits
      .replace(/(\d{1,4})(\d{1,6})?(\d{1,5})?/, (_match, p1, p2, p3) =>
        [p1, p2, p3].filter(Boolean).join(' ')
      )
      .trim();
  }
  return digits.replace(/(\d{1,4})/g, '$1 ').trim();
}

function detectCardBrand(digits: string): CardBrand {
  if (cardBrandPatterns.amex.test(digits)) return 'amex';
  if (cardBrandPatterns.visa.test(digits)) return 'visa';
  if (cardBrandPatterns.mastercard.test(digits)) return 'mastercard';
  if (cardBrandPatterns.discover.test(digits)) return 'discover';
  return 'unknown';
}

function luhnCheck(cardNumber: string): boolean {
  const digits = cardNumber.replace(/\D+/g, '');
  if (digits.length < 12) {
    return false;
  }
  let sum = 0;
  let shouldDouble = false;
  for (let i = digits.length - 1; i >= 0; i -= 1) {
    let digit = parseInt(digits.charAt(i), 10);
    if (shouldDouble) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
    shouldDouble = !shouldDouble;
  }
  return sum % 10 === 0;
}

function validate(values: CardFormValues): CardFormErrors {
  const errors: CardFormErrors = {};
  const digits = values.number.replace(/\D+/g, '');
  if (!digits) {
    errors.number = 'Card number is required.';
  } else if (digits.length < 12 || digits.length > 19 || !luhnCheck(digits)) {
    errors.number = 'Enter a valid card number.';
  }

  const month = parseInt(values.expirationMonth, 10);
  const year = parseInt(values.expirationYear, 10);
  if (
    !values.expirationMonth ||
    Number.isNaN(month) ||
    month < 1 ||
    month > 12
  ) {
    errors.expirationMonth = 'MM';
  }
  if (
    !values.expirationYear ||
    Number.isNaN(year) ||
    year < currentYearTwoDigits()
  ) {
    errors.expirationYear = 'YY';
  } else if (!errors.expirationMonth) {
    const fullYear = normalizeYear(year);
    const expiry = new Date(fullYear, month);
    const now = new Date();
    if (expiry <= now) {
      errors.expirationMonth = 'Expired';
      errors.expirationYear = 'Expired';
    }
  }

  if (!values.cvv || values.cvv.length < 3 || values.cvv.length > 4) {
    errors.cvv = 'CVV';
  }

  if (!values.postalCode || values.postalCode.length < 3) {
    errors.postalCode = 'Postal';
  }

  return errors;
}

function currentYearTwoDigits(): number {
  return parseInt(new Date().getFullYear().toString().slice(-2), 10);
}

function normalizeYear(twoDigits: number): number {
  const currentCentury = Math.floor(new Date().getFullYear() / 100) * 100;
  return currentCentury + twoDigits;
}

export function CardForm({ onSubmit, isSubmitting }: CardFormProps) {
  const [state, dispatch] = React.useReducer(formReducer, initialState);
  const [errors, setErrors] = React.useState<CardFormErrors>({});

  const brand = React.useMemo(
    () => detectCardBrand(state.number.replace(/\D+/g, '')),
    [state.number]
  );

  const handleChange = React.useCallback(
    (field: FieldName, formatter?: (value: string) => string) =>
      (text: string) => {
        const formatted = formatter ? formatter(text) : text;
        dispatch({ type: 'SET_FIELD', field, value: formatted });
        setErrors((prev) => ({ ...prev, [field]: undefined }));
      },
    []
  );

  const handleSubmit = React.useCallback(async () => {
    const nextErrors = validate(state);
    setErrors(nextErrors);
    const hasErrors = Object.values(nextErrors).some(Boolean);
    if (hasErrors) {
      return;
    }
    await onSubmit({
      number: state.number.replace(/\s+/g, ''),
      expirationMonth: state.expirationMonth,
      expirationYear: state.expirationYear,
      cvv: state.cvv,
      postalCode: state.postalCode,
    });
  }, [onSubmit, state]);

  const disabled = isSubmitting;

  return (
    <KeyboardAvoidingView
      behavior={Platform.select({ ios: 'padding' })}
      style={styles.wrapper}
    >
      <View style={styles.row}>
        <Text style={styles.label}>Card Number</Text>
        <Text style={[styles.brand, styles[`brand_${brand}`]]}>
          {brand.toUpperCase()}
        </Text>
      </View>
      <TextInput
        value={state.number}
        onChangeText={handleChange('number', formatCardNumber)}
        keyboardType="number-pad"
        placeholder="1234 5678 9012 3456"
        style={[styles.input, errors.number ? styles.inputError : null]}
        textContentType="creditCardNumber"
        maxLength={brand === 'amex' ? 17 : 19}
        importantForAutofill="yes"
        returnKeyType="next"
      />
      {!!errors.number && <Text style={styles.errorText}>{errors.number}</Text>}

      <View style={styles.inlineGroup}>
        <View style={styles.inlineField}>
          <Text style={styles.label}>Expiry (MM)</Text>
          <TextInput
            value={state.expirationMonth}
            onChangeText={handleChange('expirationMonth')}
            keyboardType="number-pad"
            placeholder="MM"
            style={[
              styles.input,
              errors.expirationMonth ? styles.inputError : null,
            ]}
            maxLength={2}
            returnKeyType="next"
          />
        </View>
        <View style={styles.inlineField}>
          <Text style={styles.label}>Expiry (YY)</Text>
          <TextInput
            value={state.expirationYear}
            onChangeText={handleChange('expirationYear')}
            keyboardType="number-pad"
            placeholder="YY"
            style={[
              styles.input,
              errors.expirationYear ? styles.inputError : null,
            ]}
            maxLength={2}
            returnKeyType="next"
          />
        </View>
        <View style={styles.inlineField}>
          <Text style={styles.label}>CVV</Text>
          <TextInput
            value={state.cvv}
            onChangeText={handleChange('cvv')}
            keyboardType="number-pad"
            placeholder="CVV"
            style={[styles.input, errors.cvv ? styles.inputError : null]}
            secureTextEntry
            maxLength={4}
            returnKeyType="done"
          />
        </View>
      </View>
      {(errors.expirationMonth || errors.expirationYear || errors.cvv) && (
        <Text style={styles.errorText}>
          {[errors.expirationMonth, errors.expirationYear, errors.cvv]
            .filter(Boolean)
            .join(' · ')}
        </Text>
      )}

      <Text style={styles.label}>Postal Code</Text>
      <TextInput
        value={state.postalCode}
        onChangeText={handleChange('postalCode')}
        keyboardType={Platform.OS === 'ios' ? 'ascii-capable' : 'default'}
        autoCapitalize="characters"
        placeholder="Postal Code"
        style={[styles.input, errors.postalCode ? styles.inputError : null]}
        returnKeyType="done"
      />
      {!!errors.postalCode && (
        <Text style={styles.errorText}>{errors.postalCode}</Text>
      )}

      <TouchableOpacity
        activeOpacity={0.8}
        style={[styles.submitButton, disabled && styles.submitButtonDisabled]}
        onPress={handleSubmit}
        disabled={disabled}
      >
        <Text style={styles.submitLabel}>
          {disabled ? 'Tokenizing…' : 'Tokenize Card'}
        </Text>
      </TouchableOpacity>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    width: '100%',
    borderRadius: 16,
    backgroundColor: '#ffffff',
    padding: 20,
    shadowColor: '#000',
    shadowOpacity: 0.1,
    shadowOffset: { width: 0, height: 10 },
    shadowRadius: 20,
    elevation: 4,
    rowGap: 12,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  label: {
    fontSize: 14,
    color: '#2c2c2c',
    fontWeight: '500',
  },
  brand: {
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'uppercase',
    color: '#6b6b6b',
  },
  brand_visa: { color: '#1a73e8' },
  brand_mastercard: { color: '#ff6f00' },
  brand_amex: { color: '#1aa1e8' },
  brand_discover: { color: '#ef6c00' },
  brand_unknown: { color: '#6b6b6b' },
  input: {
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: Platform.OS === 'ios' ? 12 : 10,
    fontSize: 16,
    color: '#1f1f1f',
  },
  inputError: {
    borderColor: '#d93025',
  },
  inlineGroup: {
    flexDirection: 'row',
    columnGap: 12,
  },
  inlineField: {
    flex: 1,
  },
  errorText: {
    fontSize: 12,
    color: '#d93025',
  },
  submitButton: {
    marginTop: 8,
    backgroundColor: '#1e293b',
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
  },
  submitButtonDisabled: {
    backgroundColor: '#94a3b8',
  },
  submitLabel: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },
});

export default CardForm;
