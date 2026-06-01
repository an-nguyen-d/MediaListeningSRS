public struct TermInflectionPair: Sendable, Equatable, Hashable {
  public let japaneseTermID: Int64
  public let inflectionKey: String

  public init(japaneseTermID: Int64, inflectionKey: String) {
    self.japaneseTermID = japaneseTermID
    self.inflectionKey = inflectionKey
  }
}
