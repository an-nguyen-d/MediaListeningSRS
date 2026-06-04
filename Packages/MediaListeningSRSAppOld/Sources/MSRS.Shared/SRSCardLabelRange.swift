import Foundation

public struct SRSCardLabelRange: Codable, Sendable, Equatable {
  public let utf16Location: Int
  public let utf16Length: Int
  public let termID: Int64
  public let inflectionKey: String

  public init(utf16Location: Int, utf16Length: Int, termID: Int64, inflectionKey: String) {
    self.utf16Location = utf16Location
    self.utf16Length = utf16Length
    self.termID = termID
    self.inflectionKey = inflectionKey
  }
}

extension SRSCardLabelRange {

  public struct SubtitleLabelInput: Sendable {
    public let range: Range<Int>
    public let termID: Int64
    public let inflectionKey: String

    public init(range: Range<Int>, termID: Int64, inflectionKey: String) {
      self.range = range
      self.termID = termID
      self.inflectionKey = inflectionKey
    }
  }

  public static func buildFromSubtitles(
    indexRange: ClosedRange<Int>,
    subtitleTextsByIndex: [Int: String],
    labelsByIndex: [Int: [SubtitleLabelInput]]
  ) -> [SRSCardLabelRange] {
    var result: [SRSCardLabelRange] = []
    var runningUTF16Offset = 0
    for index in indexRange {
      guard let text = subtitleTextsByIndex[index] else { continue }
      let textUTF16Length = text.utf16.count
      for label in labelsByIndex[index] ?? [] {
        let length = label.range.upperBound - label.range.lowerBound
        guard label.range.lowerBound >= 0,
              label.range.lowerBound + length <= textUTF16Length else { continue }
        result.append(.init(
          utf16Location: runningUTF16Offset + label.range.lowerBound,
          utf16Length: length,
          termID: label.termID,
          inflectionKey: label.inflectionKey
        ))
      }
      runningUTF16Offset += textUTF16Length
      if index < indexRange.upperBound {
        runningUTF16Offset += 1
      }
    }
    return result
  }

  public static func encodeToJSON(_ ranges: [SRSCardLabelRange]) -> String {
    guard !ranges.isEmpty else { return "" }
    let data = try? JSONEncoder().encode(ranges)
    return data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
  }

  public static func decodeFromJSON(_ json: String) -> [SRSCardLabelRange] {
    guard !json.isEmpty,
          let data = json.data(using: .utf8),
          let decoded = try? JSONDecoder().decode([SRSCardLabelRange].self, from: data)
    else { return [] }
    return decoded
  }
}

extension Array where Element == SRSCardLabelRange {

  public func toHighlightableRanges(
    fullyKnownTermIDs: Set<Int64>
  ) -> [HighlightableTranscriptLabeledRange] {
    map { label in
      HighlightableTranscriptLabeledRange(
        range: NSRange(location: label.utf16Location, length: label.utf16Length),
        termID: label.termID,
        isFullyKnown: fullyKnownTermIDs.contains(label.termID),
        inflectionKey: label.inflectionKey
      )
    }
  }
}
