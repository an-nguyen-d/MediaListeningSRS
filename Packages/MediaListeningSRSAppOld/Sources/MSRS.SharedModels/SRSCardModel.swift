import Foundation
import MSRS_Shared
import Tagged

public struct SRSCardModel: Identifiable, Sendable, Equatable {

  public typealias ID = Tagged<(Self, id: ()), Int64>

  public enum CardType: Int, Sendable, Equatable {
    case listening = 1
    case reading = 2
  }

  public struct ReadingCardTargetWord: Sendable, Equatable {
    public let termID: Int64
    public let utf16Location: Int
    public let utf16Length: Int

    public init(termID: Int64, utf16Location: Int, utf16Length: Int) {
      self.termID = termID
      self.utf16Location = utf16Location
      self.utf16Length = utf16Length
    }
  }

  public enum FrontVideoVisibility: Int, Sendable, Equatable, Codable {
    case blackScreen = 0
    case blurredThumbnail = 1
    case clearThumbnail = 2

    public var next: FrontVideoVisibility {
      switch self {
      case .blackScreen: .blurredThumbnail
      case .blurredThumbnail: .clearThumbnail
      case .clearThumbnail: .blackScreen
      }
    }
  }

  public let id: ID

  public let createdAt: Date
  public var lastUpdatedAt: Date

  public let mediaSourceID: MediaSourceModel.ID

  public let subtitleIndexStart: Int
  public let subtitleIndexEnd: Int

  public let clipStartTimeSeconds: TimeInterval
  public let clipEndTimeSeconds: TimeInterval

  public let clipRelativeFilePath: String

  public let cachedTranscriptText: String
  public let cachedEnglishTranslation: String

  public let cachedLabelRanges: [SRSCardLabelRange]

  public var frontVideoVisibility: FrontVideoVisibility
  public var playbackSpeed: Double
  public var consecutiveCorrectAtCurrentSpeed: Int
  public var isSuspended: Bool

  public let cardType: CardType
  public let readingCardTargetWord: ReadingCardTargetWord?

  public init(
    id: ID,
    createdAt: Date,
    lastUpdatedAt: Date,
    mediaSourceID: MediaSourceModel.ID,
    subtitleIndexStart: Int,
    subtitleIndexEnd: Int,
    clipStartTimeSeconds: TimeInterval,
    clipEndTimeSeconds: TimeInterval,
    clipRelativeFilePath: String,
    cachedTranscriptText: String = "",
    cachedEnglishTranslation: String = "",
    cachedLabelRanges: [SRSCardLabelRange] = [],
    frontVideoVisibility: FrontVideoVisibility = .blackScreen,
    playbackSpeed: Double = 1.0,
    consecutiveCorrectAtCurrentSpeed: Int = 0,
    isSuspended: Bool = false,
    cardType: CardType = .listening,
    readingCardTargetWord: ReadingCardTargetWord? = nil
  ) {
    self.id = id
    self.createdAt = createdAt
    self.lastUpdatedAt = lastUpdatedAt
    self.mediaSourceID = mediaSourceID
    self.subtitleIndexStart = subtitleIndexStart
    self.subtitleIndexEnd = subtitleIndexEnd
    self.clipStartTimeSeconds = clipStartTimeSeconds
    self.clipEndTimeSeconds = clipEndTimeSeconds
    self.clipRelativeFilePath = clipRelativeFilePath
    self.cachedTranscriptText = cachedTranscriptText
    self.cachedEnglishTranslation = cachedEnglishTranslation
    self.cachedLabelRanges = cachedLabelRanges
    self.frontVideoVisibility = frontVideoVisibility
    self.playbackSpeed = playbackSpeed
    self.consecutiveCorrectAtCurrentSpeed = consecutiveCorrectAtCurrentSpeed
    self.isSuspended = isSuspended
    self.cardType = cardType
    self.readingCardTargetWord = readingCardTargetWord
  }
}
