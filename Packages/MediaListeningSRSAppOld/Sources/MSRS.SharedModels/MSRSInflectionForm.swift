import Foundation

public enum MSRSInflectionForm: String, Sendable, Codable, CaseIterable, Hashable {

  // Core verb
  case past
  case negative
  case causative
  case potentialOrPassive
  case potential
  case passive
  case desire
  case polite
  case volitional
  case volitionalSlang
  case imperative
  case imperativeNegative
  case masculineInformalSuffixE
  case shortCausative

  // Te/Ta derived
  case teForm
  case progressiveOrPerfect
  case taraForm
  case tariForm
  case shimau
  case chau
  case chimau
  case oku

  // Conditional / contraction
  case baForm
  case cha
  case ya

  // Polite / auxiliary
  case masuStem
  case suffixNasai
  case sugiru
  case sou
  case maiForm

  // Adjective
  case adverbial
  case adjectiveSa
  case ki
  case ge
  case garu

  // Archaic / literary
  case zuForm
  case nuForm
  case n
  case nBakari
  case nToSuru
  case mu
  case zaru
  case neba

  // Slang
  case nSlang

  // Kansai-ben
  case kansaiBenNegative
  case kansaiBenTe
  case kansaiBenTa
  case kansaiBenTara
  case kansaiBenTari
  case kansaiBenKu
  case kansaiBenAdjectiveTe
  case kansaiBenAdjectiveNegative
}

extension MSRSInflectionForm {

  public static func serializeChain(_ forms: [MSRSInflectionForm]) -> String {
    forms.map(\.rawValue).joined(separator: ".")
  }

  public static func deserializeChain(_ key: String) -> [MSRSInflectionForm] {
    guard !key.isEmpty else { return [] }
    return key.split(separator: ".").compactMap { MSRSInflectionForm(rawValue: String($0)) }
  }
}
