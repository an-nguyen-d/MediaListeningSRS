import Foundation
import IYO_DictionaryClient
import IYO_DictionaryUIKit
import IYO_JapaneseParserClient
import MSRS_ClipExportService
import MSRS_ClipStorageClient
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_Shared
import MSRS_SharedModels

public enum SRSCardReviewModels {

  public typealias Dependencies = HasClipStorageClient
                                & HasDictionaryClient
                                & HasExportedClipsDirectoryURL
                                & HasJapaneseParserClient
                                & HasMediaListeningSRSDatabaseClient

  public enum Action {
    case viewDidLoad
    case revealBackTapped
    case replayTapped
    case termTapped(Int64)
    case markTermAsFullyKnown(Int64)
    case gradedAndNext(Grade)
    case frontVideoVisibilityChanged(SRSCardModel.FrontVideoVisibility)
    case playbackSpeedChanged(Double)
    case submitTypedAnswer(String)
    case transcriptTappedAtCharacterIndex(Int)
    case autoLoopVideoChanged(Bool)
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
    public let inflectionAnnotationsText: String?
    public let englishTranslationText: String?
    public let cardPositionLabel: String
    public let frontVideoVisibility: SRSCardModel.FrontVideoVisibility
    public let thumbnailFileURL: URL
    public let playbackSpeed: Double
    public let consecutiveCorrectAtCurrentSpeed: Int
    public let failIntervalSeconds: TimeInterval?
    public let passIntervalSeconds: TimeInterval?

    public init(
      cardID: SRSCardModel.ID,
      videoFileURL: URL,
      clipStartTimeSeconds: TimeInterval,
      clipEndTimeSeconds: TimeInterval,
      transcriptText: String,
      transcriptLabeledRanges: [HighlightableTranscriptLabeledRange],
      inflectionAnnotationsText: String?,
      englishTranslationText: String?,
      cardPositionLabel: String,
      frontVideoVisibility: SRSCardModel.FrontVideoVisibility,
      thumbnailFileURL: URL,
      playbackSpeed: Double,
      consecutiveCorrectAtCurrentSpeed: Int,
      failIntervalSeconds: TimeInterval? = nil,
      passIntervalSeconds: TimeInterval? = nil
    ) {
      self.cardID = cardID
      self.videoFileURL = videoFileURL
      self.clipStartTimeSeconds = clipStartTimeSeconds
      self.clipEndTimeSeconds = clipEndTimeSeconds
      self.transcriptText = transcriptText
      self.transcriptLabeledRanges = transcriptLabeledRanges
      self.inflectionAnnotationsText = inflectionAnnotationsText
      self.englishTranslationText = englishTranslationText
      self.cardPositionLabel = cardPositionLabel
      self.frontVideoVisibility = frontVideoVisibility
      self.thumbnailFileURL = thumbnailFileURL
      self.playbackSpeed = playbackSpeed
      self.consecutiveCorrectAtCurrentSpeed = consecutiveCorrectAtCurrentSpeed
      self.failIntervalSeconds = failIntervalSeconds
      self.passIntervalSeconds = passIntervalSeconds
    }
  }

  public struct LLMGradeResult: Sendable, Equatable {
    public let score: Int
    public let reasoning: String
    public let recommendedGrade: Grade

    public init(score: Int, reasoning: String) {
      self.score = score
      self.reasoning = reasoning
      self.recommendedGrade = score >= 70 ? .pass : .fail
    }
  }

  public struct DictionaryLookupResult: Sendable, Equatable {
    public let japaneseTermID: Int64
    public let viewModel: DictionaryLookupViewModel
    public let isAlreadyFullyKnown: Bool
    public let tappedRange: NSRange?

    public init(
      japaneseTermID: Int64,
      viewModel: DictionaryLookupViewModel,
      isAlreadyFullyKnown: Bool,
      tappedRange: NSRange? = nil
    ) {
      self.japaneseTermID = japaneseTermID
      self.viewModel = viewModel
      self.isAlreadyFullyKnown = isAlreadyFullyKnown
      self.tappedRange = tappedRange
    }
  }
}
