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

private let applePayNetworkAliases = [
    "master_card": "mastercard", "americanexpress": "amex",
    "china_union_pay": "chinaunionpay", "private_label": "privatelabel",
]

private let applePayNetworksByName = Dictionary(uniqueKeysWithValues: applePayNetworks.map { ($0.key.lowercased(), $0.value) })

private let applePayCardNetworkNames: [PKPaymentNetwork: String] = [
    .visa: "Visa", .masterCard: "MasterCard", .amex: "Amex", .JCB: "JCB",
    .maestro: "Maestro", .discover: "Discover", .chinaUnionPay: "UnionPay",
]

func applePayNetwork(named name: String) -> PKPaymentNetwork? {
    let name = name.lowercased()
    return applePayNetworksByName[applePayNetworkAliases[name] ?? name]
}

func applePayNetworkName(_ network: PKPaymentNetwork?) -> String? {
    guard let network = network else { return nil }
    if let name = applePayCardNetworkNames[network] { return name }
    let rawValue = network.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    return rawValue.isEmpty ? nil : rawValue
}
