#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
apple_pay_test_dir=$(mktemp -d)
trap 'rm -rf "$apple_pay_test_dir"' EXIT
apple_pay_test_developer="$(xcrun --sdk macosx --show-sdk-platform-path)/Developer"
apple_pay_test_frameworks="$apple_pay_test_developer/Library/Frameworks"
apple_pay_test_target="$(uname -m)-apple-macosx11.0"

xcrun swiftc -target "$apple_pay_test_target" -F "$apple_pay_test_frameworks" -I "$apple_pay_test_developer/usr/lib" \
  -L "$apple_pay_test_developer/usr/lib" -Xlinker -rpath -Xlinker "$apple_pay_test_frameworks" \
  -Xlinker -rpath -Xlinker "$apple_pay_test_developer/usr/lib" \
  ios/Errors/errors.swift ios/Errors/applePayErrorResult.swift ios/ApplePay/ApplePayPaymentDetails.swift ios/ApplePay/ApplePayValidation.swift \
  ios/ApplePay/ApplePayRequestOptions.swift ios/ApplePay/ApplePayNetworks.swift tests/ios/ApplePayRequestOptionsTests.swift \
  ios/ApplePay/ApplePayResultHandler.swift tests/ios/ApplePayResultHandlerTests.swift \
  ios/ApplePay/ApplePayAmounts.swift tests/ios/ApplePayAmountsTests.swift \
  ios/ApplePay/ApplePayGatewayFailure.swift tests/ios/ApplePayGatewayFailureTests.swift \
  tests/ios/main.swift -o "$apple_pay_test_dir/ApplePayTests"
"$apple_pay_test_dir/ApplePayTests"
