import Foundation
import PassKit

private let applePayNetworks: [String: PKPaymentNetwork] = [
    "amex": .amex,
    "cartesBancaires": .cartesBancaires,
    "chinaUnionPay": .chinaUnionPay,
    "discover": .discover,
    "eftpos": .eftpos,
    "electron": .electron,
    "elo": .elo,
    "girocard": .girocard,
    "idCredit": .idCredit,
    "interac": .interac,
    "jcb": .JCB,
    "mada": .mada,
    "maestro": .maestro,
    "masterCard": .masterCard,
    "privateLabel": .privateLabel,
    "quicPay": .quicPay,
    "suica": .suica,
    "visa": .visa,
]

func applePayNetwork(named name: String) -> PKPaymentNetwork? {
    let aliases = [
        "master_card": "masterCard", "americanexpress": "amex",
        "china_union_pay": "chinaUnionPay", "private_label": "privateLabel",
    ]
    let canonicalName = aliases[name.lowercased()] ?? name
    return applePayNetworks.first {
        $0.key.caseInsensitiveCompare(canonicalName) == .orderedSame
    }?.value
}

func applePayNetworkName(_ network: PKPaymentNetwork?) -> String? {
    guard let network = network else { return nil }
    if let name = applePayNetworks.first(where: { $0.value == network })?.key {
        return name
    }
    let rawValue = network.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    return rawValue.isEmpty ? nil : rawValue
}
