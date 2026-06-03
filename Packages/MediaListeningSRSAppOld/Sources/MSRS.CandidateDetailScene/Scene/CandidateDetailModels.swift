import Foundation
import ElixirShared
import IYO_DictionaryClient
import IYO_DictionaryUIKit
import MSRS_ClipExportService
import MSRS_ClipStorageClient
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_Shared
import MSRS_SharedModels
import JML_JMLDatabaseClient
#if targetEnvironment(macCatalyst)
import METG_METGDatabaseClient
#endif

public enum CandidateDetailModels {

  #if targetEnvironment(macCatalyst)
  public typealias Dependencies = HasClipExportService
                                & HasClipStorageClient
                                & HasDictionaryClient
                                & HasExportedClipsDirectoryURL
                                & HasJMLDatabaseClient
                                & HasMediaListeningSRSDatabaseClient
                                & HasMETGDatabaseClient
                                & HasSRTParserClient
  #else
  public typealias Dependencies = HasClipExportService
                                & HasClipStorageClient
                                & HasDictionaryClient
                                & HasExportedClipsDirectoryURL
                                & HasJMLDatabaseClient
                                & HasMediaListeningSRSDatabaseClient
                                & HasSRTParserClient
  #endif

  public enum Action {
    case viewDidLoad
    case endSubtitleIndexChanged(Int)
    case startTimeAdjusted(deltaSeconds: TimeInterval)
    case endTimeAdjusted(deltaSeconds: TimeInterval)
    case termTapped(Int64)
    case markTermAsFullyKnown(Int64)
    case skipTapped
    case confirmTapped
  }

  public struct ViewModel: Sendable, Equatable {
    public let subtitleIndexStart: Int
    public let subtitleIndexEnd: Int
    public let subtitleText: String
    public let labeledRanges: [HighlightableTranscriptLabeledRange]
    public let inflectionAnnotationsText: String?
    public let englishTranslationText: String?
    public let defaultStartTime: TimeInterval
    public let defaultEndTime: TimeInterval
    public let customStartTime: TimeInterval
    public let customEndTime: TimeInterval
    public let maxAvailableEndIndex: Int

    public init(
      subtitleIndexStart: Int,
      subtitleIndexEnd: Int,
      subtitleText: String,
      labeledRanges: [HighlightableTranscriptLabeledRange],
      inflectionAnnotationsText: String?,
      englishTranslationText: String?,
      defaultStartTime: TimeInterval,
      defaultEndTime: TimeInterval,
      customStartTime: TimeInterval,
      customEndTime: TimeInterval,
      maxAvailableEndIndex: Int
    ) {
      self.subtitleIndexStart = subtitleIndexStart
      self.subtitleIndexEnd = subtitleIndexEnd
      self.subtitleText = subtitleText
      self.labeledRanges = labeledRanges
      self.inflectionAnnotationsText = inflectionAnnotationsText
      self.englishTranslationText = englishTranslationText
      self.defaultStartTime = defaultStartTime
      self.defaultEndTime = defaultEndTime
      self.customStartTime = customStartTime
      self.customEndTime = customEndTime
      self.maxAvailableEndIndex = maxAvailableEndIndex
    }
  }

  public struct DictionaryLookupResult: Sendable, Equatable {
    public let japaneseTermID: Int64
    public let viewModel: DictionaryLookupViewModel
    public let isAlreadyFullyKnown: Bool

    public init(japaneseTermID: Int64, viewModel: DictionaryLookupViewModel, isAlreadyFullyKnown: Bool) {
      self.japaneseTermID = japaneseTermID
      self.viewModel = viewModel
      self.isAlreadyFullyKnown = isAlreadyFullyKnown
    }
  }
}
