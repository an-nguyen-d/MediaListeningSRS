import Foundation
import Tagged
import MSRS_Shared
import MSRS_SharedModels

public struct MediaListeningSRSDatabaseClient: Sendable {

  // MARK: - MediaSource

  public struct MediaSource: Sendable {

    public enum Create {
      public struct Request: Sendable {
        public let jmlMediaReference: MediaSourceModel.JMLMediaReference
        public init(jmlMediaReference: MediaSourceModel.JMLMediaReference) {
          self.jmlMediaReference = jmlMediaReference
        }
      }
      public struct Response: Sendable, Equatable {
        public let model: MediaSourceModel
        public init(model: MediaSourceModel) { self.model = model }
      }
    }

    public enum Fetch {
      public struct Request: Sendable {
        public let id: MediaSourceModel.ID
        public init(id: MediaSourceModel.ID) { self.id = id }
      }
      public struct Response: Sendable, Equatable {
        public let model: MediaSourceModel
        public init(model: MediaSourceModel) { self.model = model }
      }
    }

    public enum ObserveAll {
      public struct Request: Sendable { public init() {} }
      public typealias Response = AsyncThrowingStream<[MediaSourceModel], Error>
    }

    public var create: @Sendable (Create.Request) async throws -> Create.Response
    public var fetch: @Sendable (Fetch.Request) async throws -> Fetch.Response
    public var observeAll: @Sendable (ObserveAll.Request) async throws -> ObserveAll.Response

    public init(
      create: @Sendable @escaping (Create.Request) async throws -> Create.Response,
      fetch: @Sendable @escaping (Fetch.Request) async throws -> Fetch.Response,
      observeAll: @Sendable @escaping (ObserveAll.Request) async throws -> ObserveAll.Response
    ) {
      self.create = create
      self.fetch = fetch
      self.observeAll = observeAll
    }
  }
  public var mediaSource: MediaSource

  // MARK: - MediaSourceCardCandidate

  public struct MediaSourceCardCandidate: Sendable {

    public enum BulkCreate {
      public struct CandidateInput: Sendable, Equatable {
        public let subtitleIndex: Int
        public let termLinks: [TermInflectionPair]
        public init(subtitleIndex: Int, termLinks: [TermInflectionPair]) {
          self.subtitleIndex = subtitleIndex
          self.termLinks = termLinks
        }
      }
      public struct Request: Sendable {
        public let mediaSourceID: MediaSourceModel.ID
        public let candidates: [CandidateInput]
        public init(mediaSourceID: MediaSourceModel.ID, candidates: [CandidateInput]) {
          self.mediaSourceID = mediaSourceID
          self.candidates = candidates
        }
      }
      public struct Response: Sendable, Equatable {
        public let createdModels: [MediaSourceCardCandidateModel]
        public init(createdModels: [MediaSourceCardCandidateModel]) {
          self.createdModels = createdModels
        }
      }
    }

    public enum SetSkipped {
      public struct Request: Sendable {
        public let id: MediaSourceCardCandidateModel.ID
        public let isSkipped: Bool
        public init(
          id: MediaSourceCardCandidateModel.ID,
          isSkipped: Bool
        ) {
          self.id = id
          self.isSkipped = isSkipped
        }
      }
      public struct Response: Sendable, Equatable {
        public let updatedModel: MediaSourceCardCandidateModel
        public init(updatedModel: MediaSourceCardCandidateModel) {
          self.updatedModel = updatedModel
        }
      }
    }

    public enum ObserveForSource {
      public struct Request: Sendable {
        public let mediaSourceID: MediaSourceModel.ID
        public init(mediaSourceID: MediaSourceModel.ID) {
          self.mediaSourceID = mediaSourceID
        }
      }
      /// Chronological order by subtitleIndex. Skipped candidates are excluded.
      public typealias Response = AsyncThrowingStream<[MediaSourceCardCandidateModel], Error>
    }

    public enum FetchTermIDsForCandidate {
      public struct Request: Sendable {
        public let candidateID: MediaSourceCardCandidateModel.ID
        public init(candidateID: MediaSourceCardCandidateModel.ID) {
          self.candidateID = candidateID
        }
      }
      public struct Response: Sendable, Equatable {
        public let japaneseTermIDs: [Int64]
        public init(japaneseTermIDs: [Int64]) { self.japaneseTermIDs = japaneseTermIDs }
      }
    }

    public enum FetchTotalCandidateCountForSource {
      public struct Request: Sendable {
        public let mediaSourceID: MediaSourceModel.ID
        public init(mediaSourceID: MediaSourceModel.ID) {
          self.mediaSourceID = mediaSourceID
        }
      }
      public struct Response: Sendable, Equatable {
        public let totalCount: Int
        public init(totalCount: Int) { self.totalCount = totalCount }
      }
    }

    public enum FetchTermLinksForSource {
      public struct Request: Sendable {
        public let mediaSourceID: MediaSourceModel.ID
        public init(mediaSourceID: MediaSourceModel.ID) {
          self.mediaSourceID = mediaSourceID
        }
      }
      public struct Response: Sendable, Equatable {
        public let termLinksBySubtitleIndex: [Int: [TermInflectionPair]]
        public init(termLinksBySubtitleIndex: [Int: [TermInflectionPair]]) {
          self.termLinksBySubtitleIndex = termLinksBySubtitleIndex
        }
      }
    }

    public var bulkCreate: @Sendable (BulkCreate.Request) async throws -> BulkCreate.Response
    public var setSkipped: @Sendable (SetSkipped.Request) async throws -> SetSkipped.Response
    public var observeForSource: @Sendable (ObserveForSource.Request) async throws -> ObserveForSource.Response
    public var fetchTermIDsForCandidate: @Sendable (FetchTermIDsForCandidate.Request) async throws -> FetchTermIDsForCandidate.Response
    public var fetchTotalCandidateCountForSource: @Sendable (FetchTotalCandidateCountForSource.Request) async throws -> FetchTotalCandidateCountForSource.Response
    public var fetchTermLinksForSource: @Sendable (FetchTermLinksForSource.Request) async throws -> FetchTermLinksForSource.Response

    public init(
      bulkCreate: @Sendable @escaping (BulkCreate.Request) async throws -> BulkCreate.Response,
      setSkipped: @Sendable @escaping (SetSkipped.Request) async throws -> SetSkipped.Response,
      observeForSource: @Sendable @escaping (ObserveForSource.Request) async throws -> ObserveForSource.Response,
      fetchTermIDsForCandidate: @Sendable @escaping (FetchTermIDsForCandidate.Request) async throws -> FetchTermIDsForCandidate.Response,
      fetchTotalCandidateCountForSource: @Sendable @escaping (FetchTotalCandidateCountForSource.Request) async throws -> FetchTotalCandidateCountForSource.Response,
      fetchTermLinksForSource: @Sendable @escaping (FetchTermLinksForSource.Request) async throws -> FetchTermLinksForSource.Response
    ) {
      self.bulkCreate = bulkCreate
      self.setSkipped = setSkipped
      self.observeForSource = observeForSource
      self.fetchTermIDsForCandidate = fetchTermIDsForCandidate
      self.fetchTotalCandidateCountForSource = fetchTotalCandidateCountForSource
      self.fetchTermLinksForSource = fetchTermLinksForSource
    }
  }
  public var mediaSourceCardCandidate: MediaSourceCardCandidate

  // MARK: - SRSCard

  public struct SRSCard: Sendable {

    public enum Create {
      public struct Request: Sendable {
        public let mediaSourceID: MediaSourceModel.ID
        public let subtitleIndexStart: Int
        public let subtitleIndexEnd: Int
        public let clipStartTimeSeconds: TimeInterval
        public let clipEndTimeSeconds: TimeInterval
        public let clipRelativeFilePath: String
        public let cachedTranscriptText: String
        public let cachedEnglishTranslation: String
        public let japaneseTermLinks: [TermInflectionPair]
        public let labelRanges: [SRSCardLabelRange]

        public init(
          mediaSourceID: MediaSourceModel.ID,
          subtitleIndexStart: Int,
          subtitleIndexEnd: Int,
          clipStartTimeSeconds: TimeInterval,
          clipEndTimeSeconds: TimeInterval,
          clipRelativeFilePath: String,
          cachedTranscriptText: String,
          cachedEnglishTranslation: String,
          japaneseTermLinks: [TermInflectionPair],
          labelRanges: [SRSCardLabelRange] = []
        ) {
          self.mediaSourceID = mediaSourceID
          self.subtitleIndexStart = subtitleIndexStart
          self.subtitleIndexEnd = subtitleIndexEnd
          self.clipStartTimeSeconds = clipStartTimeSeconds
          self.clipEndTimeSeconds = clipEndTimeSeconds
          self.clipRelativeFilePath = clipRelativeFilePath
          self.cachedTranscriptText = cachedTranscriptText
          self.cachedEnglishTranslation = cachedEnglishTranslation
          self.japaneseTermLinks = japaneseTermLinks
          self.labelRanges = labelRanges
        }
      }
      public struct Response: Sendable, Equatable {
        public let model: SRSCardModel
        public init(model: SRSCardModel) { self.model = model }
      }
    }

    public enum Delete {
      public struct Request: Sendable {
        public let id: SRSCardModel.ID
        public init(id: SRSCardModel.ID) { self.id = id }
      }
      public struct Response: Sendable, Equatable {
        public init() {}
      }
    }

    public enum ObserveForSource {
      public struct Request: Sendable {
        public let mediaSourceID: MediaSourceModel.ID
        public init(mediaSourceID: MediaSourceModel.ID) {
          self.mediaSourceID = mediaSourceID
        }
      }
      public typealias Response = AsyncThrowingStream<[SRSCardModel], Error>
    }

    public enum ObserveAll {
      public struct Request: Sendable {
        public init() {}
      }
      public typealias Response = AsyncThrowingStream<[SRSCardModel], Error>
    }

    public enum RecordReview {
      public struct Request: Sendable {
        public let cardID: SRSCardModel.ID
        /// FSRS rating raw value (1=again, 2=hard, 3=good, 4=easy). Manual=0 is not allowed.
        public let ratingRawValue: Int
        public init(cardID: SRSCardModel.ID, ratingRawValue: Int) {
          self.cardID = cardID
          self.ratingRawValue = ratingRawValue
        }
      }
      public struct Response: Sendable, Equatable {
        public let updatedModel: SRSCardModel
        public let nextDueDate: Date
        public init(updatedModel: SRSCardModel, nextDueDate: Date) {
          self.updatedModel = updatedModel
          self.nextDueDate = nextDueDate
        }
      }
    }

    public enum FetchDueCards {
      public struct Request: Sendable {
        public let asOf: Date
        public let limit: Int?
        public init(asOf: Date, limit: Int? = nil) {
          self.asOf = asOf
          self.limit = limit
        }
      }
      public struct Response: Sendable, Equatable {
        public let cards: [SRSCardModel]
        public init(cards: [SRSCardModel]) { self.cards = cards }
      }
    }

    public enum UpdateFrontVideoVisibility {
      public struct Request: Sendable {
        public let cardID: SRSCardModel.ID
        public let visibility: SRSCardModel.FrontVideoVisibility
        public init(cardID: SRSCardModel.ID, visibility: SRSCardModel.FrontVideoVisibility) {
          self.cardID = cardID
          self.visibility = visibility
        }
      }
      public struct Response: Sendable, Equatable {
        public init() {}
      }
    }

    public enum UpdatePlaybackSpeed {
      public struct Request: Sendable {
        public let cardID: SRSCardModel.ID
        public let speed: Double
        public init(cardID: SRSCardModel.ID, speed: Double) {
          self.cardID = cardID
          self.speed = speed
        }
      }
      public struct Response: Sendable, Equatable {
        public init() {}
      }
    }

    public enum UpdateClipPath {
      public struct Request: Sendable {
        public let cardID: SRSCardModel.ID
        public let clipRelativeFilePath: String
        public init(cardID: SRSCardModel.ID, clipRelativeFilePath: String) {
          self.cardID = cardID
          self.clipRelativeFilePath = clipRelativeFilePath
        }
      }
      public struct Response: Sendable, Equatable {
        public init() {}
      }
    }

    public var create: @Sendable (Create.Request) async throws -> Create.Response
    public var delete: @Sendable (Delete.Request) async throws -> Delete.Response
    public var observeForSource: @Sendable (ObserveForSource.Request) async throws -> ObserveForSource.Response
    public var observeAll: @Sendable (ObserveAll.Request) async throws -> ObserveAll.Response
    public var recordReview: @Sendable (RecordReview.Request) async throws -> RecordReview.Response
    public var fetchDueCards: @Sendable (FetchDueCards.Request) async throws -> FetchDueCards.Response
    public var updateFrontVideoVisibility: @Sendable (UpdateFrontVideoVisibility.Request) async throws -> UpdateFrontVideoVisibility.Response
    public var updatePlaybackSpeed: @Sendable (UpdatePlaybackSpeed.Request) async throws -> UpdatePlaybackSpeed.Response
    public var updateClipPath: @Sendable (UpdateClipPath.Request) async throws -> UpdateClipPath.Response

    public enum PreviewNextIntervals {
      public struct Request: Sendable {
        public let cardID: SRSCardModel.ID
        public init(cardID: SRSCardModel.ID) { self.cardID = cardID }
      }
      public struct Response: Sendable, Equatable {
        public let failIntervalSeconds: TimeInterval
        public let passIntervalSeconds: TimeInterval
        public init(failIntervalSeconds: TimeInterval, passIntervalSeconds: TimeInterval) {
          self.failIntervalSeconds = failIntervalSeconds
          self.passIntervalSeconds = passIntervalSeconds
        }
      }
    }

    public var previewNextIntervals: @Sendable (PreviewNextIntervals.Request) async throws -> PreviewNextIntervals.Response

    public enum FetchTermLinksForCard {
      public struct Request: Sendable {
        public let cardID: SRSCardModel.ID
        public init(cardID: SRSCardModel.ID) { self.cardID = cardID }
      }
      public struct Response: Sendable, Equatable {
        public let termLinks: [TermInflectionPair]
        public init(termLinks: [TermInflectionPair]) { self.termLinks = termLinks }
      }
    }

    public var fetchTermLinksForCard: @Sendable (FetchTermLinksForCard.Request) async throws -> FetchTermLinksForCard.Response

    public enum BatchUpdateCachedTranscripts {
      public struct CardTranscriptData: Sendable {
        public let cardID: SRSCardModel.ID
        public let cachedTranscriptText: String
        public let cachedEnglishTranslation: String
        public init(cardID: SRSCardModel.ID, cachedTranscriptText: String, cachedEnglishTranslation: String) {
          self.cardID = cardID
          self.cachedTranscriptText = cachedTranscriptText
          self.cachedEnglishTranslation = cachedEnglishTranslation
        }
      }
      public struct Request: Sendable {
        public let updates: [CardTranscriptData]
        public init(updates: [CardTranscriptData]) { self.updates = updates }
      }
      public struct Response: Sendable, Equatable {
        public let updatedCount: Int
        public init(updatedCount: Int) { self.updatedCount = updatedCount }
      }
    }

    public var batchUpdateCachedTranscripts: @Sendable (BatchUpdateCachedTranscripts.Request) async throws -> BatchUpdateCachedTranscripts.Response

    public enum BatchUpdateCachedLabelRanges {
      public struct CardLabelRangesData: Sendable {
        public let cardID: SRSCardModel.ID
        public let labelRangesJSON: String
        public init(cardID: SRSCardModel.ID, labelRangesJSON: String) {
          self.cardID = cardID
          self.labelRangesJSON = labelRangesJSON
        }
      }
      public struct Request: Sendable {
        public let updates: [CardLabelRangesData]
        public init(updates: [CardLabelRangesData]) { self.updates = updates }
      }
      public struct Response: Sendable, Equatable {
        public let updatedCount: Int
        public init(updatedCount: Int) { self.updatedCount = updatedCount }
      }
    }

    public var batchUpdateCachedLabelRanges: @Sendable (BatchUpdateCachedLabelRanges.Request) async throws -> BatchUpdateCachedLabelRanges.Response

    public enum FetchAllCards {
      public struct Request: Sendable { public init() {} }
      public struct Response: Sendable, Equatable {
        public let cards: [SRSCardModel]
        public init(cards: [SRSCardModel]) { self.cards = cards }
      }
    }

    public var fetchAllCards: @Sendable (FetchAllCards.Request) async throws -> FetchAllCards.Response

    public init(
      create: @Sendable @escaping (Create.Request) async throws -> Create.Response,
      delete: @Sendable @escaping (Delete.Request) async throws -> Delete.Response,
      observeForSource: @Sendable @escaping (ObserveForSource.Request) async throws -> ObserveForSource.Response,
      observeAll: @Sendable @escaping (ObserveAll.Request) async throws -> ObserveAll.Response,
      recordReview: @Sendable @escaping (RecordReview.Request) async throws -> RecordReview.Response,
      fetchDueCards: @Sendable @escaping (FetchDueCards.Request) async throws -> FetchDueCards.Response,
      updateFrontVideoVisibility: @Sendable @escaping (UpdateFrontVideoVisibility.Request) async throws -> UpdateFrontVideoVisibility.Response,
      updatePlaybackSpeed: @Sendable @escaping (UpdatePlaybackSpeed.Request) async throws -> UpdatePlaybackSpeed.Response,
      updateClipPath: @Sendable @escaping (UpdateClipPath.Request) async throws -> UpdateClipPath.Response,
      previewNextIntervals: @Sendable @escaping (PreviewNextIntervals.Request) async throws -> PreviewNextIntervals.Response,
      fetchTermLinksForCard: @Sendable @escaping (FetchTermLinksForCard.Request) async throws -> FetchTermLinksForCard.Response,
      batchUpdateCachedTranscripts: @Sendable @escaping (BatchUpdateCachedTranscripts.Request) async throws -> BatchUpdateCachedTranscripts.Response,
      batchUpdateCachedLabelRanges: @Sendable @escaping (BatchUpdateCachedLabelRanges.Request) async throws -> BatchUpdateCachedLabelRanges.Response,
      fetchAllCards: @Sendable @escaping (FetchAllCards.Request) async throws -> FetchAllCards.Response
    ) {
      self.create = create
      self.delete = delete
      self.observeForSource = observeForSource
      self.observeAll = observeAll
      self.recordReview = recordReview
      self.fetchDueCards = fetchDueCards
      self.updateFrontVideoVisibility = updateFrontVideoVisibility
      self.updatePlaybackSpeed = updatePlaybackSpeed
      self.updateClipPath = updateClipPath
      self.previewNextIntervals = previewNextIntervals
      self.fetchTermLinksForCard = fetchTermLinksForCard
      self.batchUpdateCachedTranscripts = batchUpdateCachedTranscripts
      self.batchUpdateCachedLabelRanges = batchUpdateCachedLabelRanges
      self.fetchAllCards = fetchAllCards
    }
  }
  public var srsCard: SRSCard

  // MARK: - JapaneseTerm
  //
  // Two levels of word knowledge:
  //   - "Fully Known": manually marked by the user ("I know everything about this word").
  //     Drives candidate filtering — fully-known terms are invalid for new candidates.
  //   - "Learned": SRS-driven passive vocabulary score (0→1).
  //     score = min(1, sum(min(stability, 365) for top 100 cards) / 365).
  //     Informational only — does not affect candidate filtering.

  public struct JapaneseTerm: Sendable {

    public enum MarkAsFullyKnown {
      public struct Request: Sendable {
        public let japaneseTermID: Int64
        public init(japaneseTermID: Int64) {
          self.japaneseTermID = japaneseTermID
        }
      }
      public struct Response: Sendable, Equatable {
        public init() {}
      }
    }

    public enum IsFullyKnown {
      public struct Request: Sendable {
        public let japaneseTermID: Int64
        public init(japaneseTermID: Int64) { self.japaneseTermID = japaneseTermID }
      }
      public struct Response: Sendable, Equatable {
        public let isFullyKnown: Bool
        public init(isFullyKnown: Bool) { self.isFullyKnown = isFullyKnown }
      }
    }

    public enum FetchFullyKnownTermIDs {
      public struct Request: Sendable {
        public let japaneseTermIDs: [Int64]
        public init(japaneseTermIDs: [Int64]) {
          self.japaneseTermIDs = japaneseTermIDs
        }
      }
      public struct Response: Sendable, Equatable {
        public let fullyKnownTermIDs: Set<Int64>
        public init(fullyKnownTermIDs: Set<Int64>) {
          self.fullyKnownTermIDs = fullyKnownTermIDs
        }
      }
    }

    public enum FetchLearnedScoresForTermIDs {
      public struct Request: Sendable {
        public let japaneseTermIDs: [Int64]
        public init(japaneseTermIDs: [Int64]) {
          self.japaneseTermIDs = japaneseTermIDs
        }
      }
      public struct Response: Sendable, Equatable {
        public let scoresByTermID: [Int64: Double]
        public init(scoresByTermID: [Int64: Double]) {
          self.scoresByTermID = scoresByTermID
        }
      }
    }

    public enum FetchInvalidTermPairs {
      public struct Request: Sendable {
        public let termPairs: [TermInflectionPair]
        public let coverageThreshold: Int
        public init(termPairs: [TermInflectionPair], coverageThreshold: Int) {
          self.termPairs = termPairs
          self.coverageThreshold = coverageThreshold
        }
      }
      public struct Response: Sendable, Equatable {
        public let invalidPairs: Set<TermInflectionPair>
        public init(invalidPairs: Set<TermInflectionPair>) {
          self.invalidPairs = invalidPairs
        }
      }
    }

    public struct SourceInflectionData: Sendable {
      public let mediaSourceID: MediaSourceModel.ID
      public let pairsBySubtitleIndex: [Int: [TermInflectionPair]]
      public init(mediaSourceID: MediaSourceModel.ID, pairsBySubtitleIndex: [Int: [TermInflectionPair]]) {
        self.mediaSourceID = mediaSourceID
        self.pairsBySubtitleIndex = pairsBySubtitleIndex
      }
    }

    public enum BackfillInflectionKeys {
      public struct Request: Sendable {
        public let sourceData: [SourceInflectionData]
        public init(sourceData: [SourceInflectionData]) {
          self.sourceData = sourceData
        }
      }
      public struct Response: Sendable, Equatable {
        public init() {}
      }
    }

    public enum FetchCoverageCountsForTermIDs {
      public struct Request: Sendable {
        public let japaneseTermIDs: [Int64]
        public init(japaneseTermIDs: [Int64]) {
          self.japaneseTermIDs = japaneseTermIDs
        }
      }
      public struct Response: Sendable, Equatable {
        public let coverageCountsByTermID: [Int64: Int]
        public init(coverageCountsByTermID: [Int64: Int]) {
          self.coverageCountsByTermID = coverageCountsByTermID
        }
      }
    }

    public var markAsFullyKnown: @Sendable (MarkAsFullyKnown.Request) async throws -> MarkAsFullyKnown.Response
    public var isFullyKnown: @Sendable (IsFullyKnown.Request) async throws -> IsFullyKnown.Response
    public var fetchFullyKnownTermIDs: @Sendable (FetchFullyKnownTermIDs.Request) async throws -> FetchFullyKnownTermIDs.Response
    public var fetchLearnedScoresForTermIDs: @Sendable (FetchLearnedScoresForTermIDs.Request) async throws -> FetchLearnedScoresForTermIDs.Response
    public var fetchInvalidTermPairs: @Sendable (FetchInvalidTermPairs.Request) async throws -> FetchInvalidTermPairs.Response
    public var backfillInflectionKeys: @Sendable (BackfillInflectionKeys.Request) async throws -> BackfillInflectionKeys.Response
    public var fetchCoverageCountsForTermIDs: @Sendable (FetchCoverageCountsForTermIDs.Request) async throws -> FetchCoverageCountsForTermIDs.Response

    public init(
      markAsFullyKnown: @Sendable @escaping (MarkAsFullyKnown.Request) async throws -> MarkAsFullyKnown.Response,
      isFullyKnown: @Sendable @escaping (IsFullyKnown.Request) async throws -> IsFullyKnown.Response,
      fetchFullyKnownTermIDs: @Sendable @escaping (FetchFullyKnownTermIDs.Request) async throws -> FetchFullyKnownTermIDs.Response,
      fetchLearnedScoresForTermIDs: @Sendable @escaping (FetchLearnedScoresForTermIDs.Request) async throws -> FetchLearnedScoresForTermIDs.Response,
      fetchInvalidTermPairs: @Sendable @escaping (FetchInvalidTermPairs.Request) async throws -> FetchInvalidTermPairs.Response,
      backfillInflectionKeys: @Sendable @escaping (BackfillInflectionKeys.Request) async throws -> BackfillInflectionKeys.Response,
      fetchCoverageCountsForTermIDs: @Sendable @escaping (FetchCoverageCountsForTermIDs.Request) async throws -> FetchCoverageCountsForTermIDs.Response
    ) {
      self.markAsFullyKnown = markAsFullyKnown
      self.isFullyKnown = isFullyKnown
      self.fetchFullyKnownTermIDs = fetchFullyKnownTermIDs
      self.fetchLearnedScoresForTermIDs = fetchLearnedScoresForTermIDs
      self.fetchInvalidTermPairs = fetchInvalidTermPairs
      self.backfillInflectionKeys = backfillInflectionKeys
      self.fetchCoverageCountsForTermIDs = fetchCoverageCountsForTermIDs
    }
  }
  public var japaneseTerm: JapaneseTerm

  // MARK: - StudySession

  public struct StudySession: Sendable {

    public enum CreateSession {
      public struct Request: Sendable {
        public let startedAt: Date
        public let endedAt: Date
        public let cardsReviewed: Int
        public init(startedAt: Date, endedAt: Date, cardsReviewed: Int) {
          self.startedAt = startedAt
          self.endedAt = endedAt
          self.cardsReviewed = cardsReviewed
        }
      }
      public struct Response: Sendable, Equatable {
        public let model: StudySessionModel
        public init(model: StudySessionModel) { self.model = model }
      }
    }

    public enum UpdateSession {
      public struct Request: Sendable {
        public let id: StudySessionModel.ID
        public let endedAt: Date
        public let cardsReviewed: Int
        public init(id: StudySessionModel.ID, endedAt: Date, cardsReviewed: Int) {
          self.id = id
          self.endedAt = endedAt
          self.cardsReviewed = cardsReviewed
        }
      }
      public struct Response: Sendable, Equatable {
        public init() {}
      }
    }

    public enum FetchMostRecent {
      public struct Request: Sendable {
        public init() {}
      }
      public struct Response: Sendable, Equatable {
        public let model: StudySessionModel?
        public init(model: StudySessionModel?) { self.model = model }
      }
    }

    public enum FetchInDateRange {
      public struct Request: Sendable {
        public let startDate: Date
        public let endDate: Date
        public init(startDate: Date, endDate: Date) {
          self.startDate = startDate
          self.endDate = endDate
        }
      }
      public struct Response: Sendable, Equatable {
        public let models: [StudySessionModel]
        public init(models: [StudySessionModel]) { self.models = models }
      }
    }

    public var createSession: @Sendable (CreateSession.Request) async throws -> CreateSession.Response
    public var updateSession: @Sendable (UpdateSession.Request) async throws -> UpdateSession.Response
    public var fetchMostRecent: @Sendable (FetchMostRecent.Request) async throws -> FetchMostRecent.Response
    public var fetchInDateRange: @Sendable (FetchInDateRange.Request) async throws -> FetchInDateRange.Response

    public init(
      createSession: @Sendable @escaping (CreateSession.Request) async throws -> CreateSession.Response,
      updateSession: @Sendable @escaping (UpdateSession.Request) async throws -> UpdateSession.Response,
      fetchMostRecent: @Sendable @escaping (FetchMostRecent.Request) async throws -> FetchMostRecent.Response,
      fetchInDateRange: @Sendable @escaping (FetchInDateRange.Request) async throws -> FetchInDateRange.Response
    ) {
      self.createSession = createSession
      self.updateSession = updateSession
      self.fetchMostRecent = fetchMostRecent
      self.fetchInDateRange = fetchInDateRange
    }
  }
  public var studySession: StudySession

  // MARK: - DailySnapshot

  public struct DailySnapshot: Sendable {

    public enum CreateIfNeeded {
      public struct Request: Sendable {
        public let date: Date
        public init(date: Date) { self.date = date }
      }
      public struct Response: Sendable, Equatable {
        public let wasCreated: Bool
        public init(wasCreated: Bool) { self.wasCreated = wasCreated }
      }
    }

    public enum FetchAggregatesInDateRange {
      public struct Request: Sendable {
        public let startDate: String
        public let endDate: String
        public init(startDate: String, endDate: String) {
          self.startDate = startDate
          self.endDate = endDate
        }
      }
      public struct Response: Sendable, Equatable {
        public let models: [DailyAggregateSnapshotModel]
        public init(models: [DailyAggregateSnapshotModel]) { self.models = models }
      }
    }

    public enum FetchCardSnapshotsForDate {
      public struct Request: Sendable {
        public let snapshotDate: String
        public init(snapshotDate: String) { self.snapshotDate = snapshotDate }
      }
      public struct Response: Sendable, Equatable {
        public let models: [DailyCardSnapshotModel]
        public init(models: [DailyCardSnapshotModel]) { self.models = models }
      }
    }

    public var createIfNeeded: @Sendable (CreateIfNeeded.Request) async throws -> CreateIfNeeded.Response
    public var fetchAggregatesInDateRange: @Sendable (FetchAggregatesInDateRange.Request) async throws -> FetchAggregatesInDateRange.Response
    public var fetchCardSnapshotsForDate: @Sendable (FetchCardSnapshotsForDate.Request) async throws -> FetchCardSnapshotsForDate.Response

    public init(
      createIfNeeded: @Sendable @escaping (CreateIfNeeded.Request) async throws -> CreateIfNeeded.Response,
      fetchAggregatesInDateRange: @Sendable @escaping (FetchAggregatesInDateRange.Request) async throws -> FetchAggregatesInDateRange.Response,
      fetchCardSnapshotsForDate: @Sendable @escaping (FetchCardSnapshotsForDate.Request) async throws -> FetchCardSnapshotsForDate.Response
    ) {
      self.createIfNeeded = createIfNeeded
      self.fetchAggregatesInDateRange = fetchAggregatesInDateRange
      self.fetchCardSnapshotsForDate = fetchCardSnapshotsForDate
    }
  }
  public var dailySnapshot: DailySnapshot

  // MARK: - AppSettings

  public struct AppSettings: Sendable {

    public enum Fetch {
      public struct Request: Sendable { public init() {} }
      public struct Response: Sendable, Equatable {
        public let model: AppSettingsModel
        public init(model: AppSettingsModel) { self.model = model }
      }
    }

    public enum Update {
      public struct Request: Sendable {
        public let model: AppSettingsModel
        public init(model: AppSettingsModel) { self.model = model }
      }
      public struct Response: Sendable, Equatable {
        public init() {}
      }
    }

    public var fetch: @Sendable (Fetch.Request) async throws -> Fetch.Response
    public var update: @Sendable (Update.Request) async throws -> Update.Response

    public init(
      fetch: @Sendable @escaping (Fetch.Request) async throws -> Fetch.Response,
      update: @Sendable @escaping (Update.Request) async throws -> Update.Response
    ) {
      self.fetch = fetch
      self.update = update
    }
  }
  public var appSettings: AppSettings

  public var close: @Sendable () throws -> Void

  public init(
    mediaSource: MediaSource,
    mediaSourceCardCandidate: MediaSourceCardCandidate,
    srsCard: SRSCard,
    japaneseTerm: JapaneseTerm,
    studySession: StudySession,
    dailySnapshot: DailySnapshot,
    appSettings: AppSettings,
    close: @Sendable @escaping () throws -> Void
  ) {
    self.mediaSource = mediaSource
    self.mediaSourceCardCandidate = mediaSourceCardCandidate
    self.srsCard = srsCard
    self.japaneseTerm = japaneseTerm
    self.studySession = studySession
    self.dailySnapshot = dailySnapshot
    self.appSettings = appSettings
    self.close = close
  }
}
