import IYO_JapaneseModels

public enum MSRSInflectionFormMapper {

  public static func map(_ inflectionType: InflectionType) -> MSRSInflectionForm? {
    switch inflectionType {
    case .past: return .past
    case .negative: return .negative
    case .causative: return .causative
    case .potentialOrPassive: return .potentialOrPassive
    case .potential: return .potential
    case .passive: return .passive
    case .desire: return .desire
    case .polite: return .polite
    case .volitional: return .volitional
    case .volitionalSlang: return .volitionalSlang
    case .imperative: return .imperative
    case .imperativeNegative: return .imperativeNegative
    case .masculineInformalSuffixE: return .masculineInformalSuffixE
    case .shortCausative: return .shortCausative
    case .teForm: return .teForm
    case .progressiveOrPerfect: return .progressiveOrPerfect
    case .taraForm: return .taraForm
    case .tariForm: return .tariForm
    case .shimau: return .shimau
    case .chau: return .chau
    case .chimau: return .chimau
    case .oku: return .oku
    case .baForm: return .baForm
    case .cha: return .cha
    case .ya: return .ya
    case .masuStem: return .masuStem
    case .suffixNasai: return .suffixNasai
    case .sugiru: return .sugiru
    case .sou: return .sou
    case .maiForm: return .maiForm
    case .adverbial: return .adverbial
    case .adjectiveSa: return .adjectiveSa
    case .ki: return .ki
    case .ge: return .ge
    case .garu: return .garu
    case .zuForm: return .zuForm
    case .nuForm: return .nuForm
    case .n: return .n
    case .nBakari: return .nBakari
    case .nToSuru: return .nToSuru
    case .mu: return .mu
    case .zaru: return .zaru
    case .neba: return .neba
    case .nSlang: return .nSlang
    case .kansaiBenNegative: return .kansaiBenNegative
    case .kansaiBenTe: return .kansaiBenTe
    case .kansaiBenTa: return .kansaiBenTa
    case .kansaiBenTara: return .kansaiBenTara
    case .kansaiBenTari: return .kansaiBenTari
    case .kansaiBenKu: return .kansaiBenKu
    case .kansaiBenAdjectiveTe: return .kansaiBenAdjectiveTe
    case .kansaiBenAdjectiveNegative: return .kansaiBenAdjectiveNegative
    @unknown default: return nil
    }
  }

  public static func mapChain(_ inflections: [InflectionType]) -> [MSRSInflectionForm] {
    inflections.compactMap(map)
  }

  public static func inflectionKey(from inflections: [InflectionType]) -> String {
    MSRSInflectionForm.serializeChain(mapChain(inflections))
  }
}
