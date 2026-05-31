import Foundation
import ElixirShared
import IYO_DictionaryClient
import IYO_DictionaryUIKit
import JML_JMLDatabaseClient
import METG_METGDatabaseClient
import MSRS_ClipExportService
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_Shared
import MSRS_SharedModels

public enum SRSCardReviewModels {

  public typealias Dependencies = HasDictionaryClient
                                & HasExportedClipsDirectoryURL
                                & HasJMLDatabaseClient
                                & HasMediaListeningSRSDatabaseClient
                                & HasMETGDatabaseClient
                                & HasSRTParserClient

  public enum Action {
    case viewDidLoad
    case revealBackTapped
    case replayTapped
    case termTapped(Int64)
    case markTermAsKnown(Int64)
    case gradedAndNext(Grade)
  }

  public enum Grade: Sendable, Equatable {
    case fail
    case pass
  }

  public struct CardViewModel: Sendable, Equatable {
    public let cardID: SRSCardModel.ID
    public let videoFileURL: URL
    public let clipStartTimeSeconds: TimeInterval
    public let clipEndTimeSeconds: TimeInterval
    public let transcriptText: String
    public let transcriptLabeledRanges: [HighlightableTranscriptLabeledRange]
    public let englishTranslationText: String?
    public let cardPositionLabel: String

    public init(
      cardID: SRSCardModel.ID,
      videoFileURL: URL,
      clipStartTimeSeconds: TimeInterval,
      clipEndTimeSeconds: TimeInterval,
      transcriptText: String,
      transcriptLabeledRanges: [HighlightableTranscriptLabeledRange],
      englishTranslationText: String?,
      cardPositionLabel: String
    ) {
      self.cardID = cardID
      self.videoFileURL = videoFileURL
      self.clipStartTimeSeconds = clipStartTimeSeconds
      self.clipEndTimeSeconds = clipEndTimeSeconds
      self.transcriptText = transcriptText
      self.transcriptLabeledRanges = transcriptLabeledRanges
      self.englishTranslationText = englishTranslationText
      self.cardPositionLabel = cardPositionLabel
    }
  }

  public struct DictionaryLookupResult: Sendable, Equatable {
    public let japaneseTermID: Int64
    public let viewModel: DictionaryLookupViewModel
    public let isAlreadyKnown: Bool

    public init(japaneseTermID: Int64, viewModel: DictionaryLookupViewModel, isAlreadyKnown: Bool) {
      self.japaneseTermID = japaneseTermID
      self.viewModel = viewModel
      self.isAlreadyKnown = isAlreadyKnown
    }
  }
}
