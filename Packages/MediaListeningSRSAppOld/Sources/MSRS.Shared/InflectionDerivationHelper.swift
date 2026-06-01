import Foundation

public enum InflectionDerivationHelper {

  public struct LabelInfo: Sendable {
    public let subtitleIndex: Int
    public let utf16Range: Range<Int>
    public let japaneseTermID: Int64

    public init(subtitleIndex: Int, utf16Range: Range<Int>, japaneseTermID: Int64) {
      self.subtitleIndex = subtitleIndex
      self.utf16Range = utf16Range
      self.japaneseTermID = japaneseTermID
    }
  }

  public struct LookupResult: Sendable {
    public let dictionaryID: Int
    public let inflectionKey: String

    public init(dictionaryID: Int, inflectionKey: String) {
      self.dictionaryID = dictionaryID
      self.inflectionKey = inflectionKey
    }
  }

  public static func deriveInflectionPairs(
    labels: [LabelInfo],
    segmentTextsByIndex: [Int: String],
    prefixLookup: @Sendable (_ surfaceText: String) async throws -> [LookupResult]
  ) async -> [Int: [TermInflectionPair]] {
    var resultsByIndex: [Int: [TermInflectionPair]] = [:]

    for label in labels {
      guard let segmentText = segmentTextsByIndex[label.subtitleIndex] else {
        resultsByIndex[label.subtitleIndex, default: []].append(
          TermInflectionPair(japaneseTermID: label.japaneseTermID, inflectionKey: "")
        )
        continue
      }

      let surfaceText = extractSurfaceText(from: segmentText, utf16Range: label.utf16Range)
      guard let surfaceText, !surfaceText.isEmpty else {
        resultsByIndex[label.subtitleIndex, default: []].append(
          TermInflectionPair(japaneseTermID: label.japaneseTermID, inflectionKey: "")
        )
        continue
      }

      do {
        let lookupResults = try await prefixLookup(surfaceText)
        let match = lookupResults.first { $0.dictionaryID == Int(label.japaneseTermID) }
        let inflectionKey = match?.inflectionKey ?? ""
        resultsByIndex[label.subtitleIndex, default: []].append(
          TermInflectionPair(japaneseTermID: label.japaneseTermID, inflectionKey: inflectionKey)
        )
      } catch {
        resultsByIndex[label.subtitleIndex, default: []].append(
          TermInflectionPair(japaneseTermID: label.japaneseTermID, inflectionKey: "")
        )
      }
    }

    return resultsByIndex
  }

  public static func extractSurfaceText(from segmentText: String, utf16Range: Range<Int>) -> String? {
    let utf16 = segmentText.utf16
    guard utf16Range.lowerBound >= 0,
          utf16Range.upperBound <= utf16.count else { return nil }
    let start = utf16.index(utf16.startIndex, offsetBy: utf16Range.lowerBound)
    let end = utf16.index(utf16.startIndex, offsetBy: utf16Range.upperBound)
    return String(utf16[start..<end])
  }
}
