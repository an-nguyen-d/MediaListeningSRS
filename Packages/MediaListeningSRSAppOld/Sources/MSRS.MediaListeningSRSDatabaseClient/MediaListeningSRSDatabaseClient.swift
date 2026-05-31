import Foundation
import Tagged
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
        public let japaneseTermIDs: [Int64]
        public init(subtitleIndex: Int, japaneseTermIDs: [Int64]) {
          self.subtitleIndex = subtitleIndex
          self.japaneseTermIDs = japaneseTermIDs
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

    public var bulkCreate: @Sendable (BulkCreate.Request) async throws -> BulkCreate.Response
    public var setSkipped: @Sendable (SetSkipped.Request) async throws -> SetSkipped.Response
    public var observeForSource: @Sendable (ObserveForSource.Request) async throws -> ObserveForSource.Response
    public var fetchTermIDsForCandidate: @Sendable (FetchTermIDsForCandidate.Request) async throws -> FetchTermIDsForCandidate.Response

    public init(
      bulkCreate: @Sendable @escaping (BulkCreate.Request) async throws -> BulkCreate.Response,
      setSkipped: @Sendable @escaping (SetSkipped.Request) async throws -> SetSkipped.Response,
      observeForSource: @Sendable @escaping (ObserveForSource.Request) async throws -> ObserveForSource.Response,
      fetchTermIDsForCandidate: @Sendable @escaping (FetchTermIDsForCandidate.Request) async throws -> FetchTermIDsForCandidate.Response
    ) {
      self.bulkCreate = bulkCreate
      self.setSkipped = setSkipped
      self.observeForSource = observeForSource
      self.fetchTermIDsForCandidate = fetchTermIDsForCandidate
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
        /// All iYomi term IDs the card's subtitle range covers (snapshotted from MWBT at promote time).
        public let japaneseTermIDs: [Int64]

        public init(
          mediaSourceID: MediaSourceModel.ID,
          subtitleIndexStart: Int,
          subtitleIndexEnd: Int,
          clipStartTimeSeconds: TimeInterval,
          clipEndTimeSeconds: TimeInterval,
          clipRelativeFilePath: String,
          japaneseTermIDs: [Int64]
        ) {
          self.mediaSourceID = mediaSourceID
          self.subtitleIndexStart = subtitleIndexStart
          self.subtitleIndexEnd = subtitleIndexEnd
          self.clipStartTimeSeconds = clipStartTimeSeconds
          self.clipEndTimeSeconds = clipEndTimeSeconds
          self.clipRelativeFilePath = clipRelativeFilePath
          self.japaneseTermIDs = japaneseTermIDs
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
        public init(asOf: Date) { self.asOf = asOf }
      }
      public struct Response: Sendable, Equatable {
        public let cards: [SRSCardModel]
        public init(cards: [SRSCardModel]) { self.cards = cards }
      }
    }

    public var create: @Sendable (Create.Request) async throws -> Create.Response
    public var delete: @Sendable (Delete.Request) async throws -> Delete.Response
    public var observeForSource: @Sendable (ObserveForSource.Request) async throws -> ObserveForSource.Response
    public var observeAll: @Sendable (ObserveAll.Request) async throws -> ObserveAll.Response
    public var recordReview: @Sendable (RecordReview.Request) async throws -> RecordReview.Response
    public var fetchDueCards: @Sendable (FetchDueCards.Request) async throws -> FetchDueCards.Response

    public init(
      create: @Sendable @escaping (Create.Request) async throws -> Create.Response,
      delete: @Sendable @escaping (Delete.Request) async throws -> Delete.Response,
      observeForSource: @Sendable @escaping (ObserveForSource.Request) async throws -> ObserveForSource.Response,
      observeAll: @Sendable @escaping (ObserveAll.Request) async throws -> ObserveAll.Response,
      recordReview: @Sendable @escaping (RecordReview.Request) async throws -> RecordReview.Response,
      fetchDueCards: @Sendable @escaping (FetchDueCards.Request) async throws -> FetchDueCards.Response
    ) {
      self.create = create
      self.delete = delete
      self.observeForSource = observeForSource
      self.observeAll = observeAll
      self.recordReview = recordReview
      self.fetchDueCards = fetchDueCards
    }
  }
  public var srsCard: SRSCard

  // MARK: - KnownJapaneseTerm
  //
  // Single source of truth for "is this word known". A word is known iff:
  //   (a) it has been manually marked as known by the user, OR
  //   (b) it has reached SRS mastery: at least `masteryMinimumCardsCount` cards linked to it,
  //       each with stability >= `masteryMinimumStability`.
  //
  // DO NOT duplicate the known-decision logic anywhere else in the codebase.

  public struct KnownJapaneseTerm: Sendable {

    public enum MarkAsKnown {
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

    public enum IsKnown {
      public struct Request: Sendable {
        public let japaneseTermID: Int64
        public init(japaneseTermID: Int64) { self.japaneseTermID = japaneseTermID }
      }
      public struct Response: Sendable, Equatable {
        public let isKnown: Bool
        public init(isKnown: Bool) { self.isKnown = isKnown }
      }
    }

    public enum FetchKnownStatusForTermIDs {
      public struct Request: Sendable {
        public let japaneseTermIDs: [Int64]
        public init(japaneseTermIDs: [Int64]) {
          self.japaneseTermIDs = japaneseTermIDs
        }
      }
      public struct Response: Sendable, Equatable {
        public let knownTermIDs: Set<Int64>
        public init(knownTermIDs: Set<Int64>) {
          self.knownTermIDs = knownTermIDs
        }
      }
    }

    public enum FetchInvalidTermIDs {
      public struct Request: Sendable {
        public let japaneseTermIDs: [Int64]
        public let coverageThreshold: Int
        public init(japaneseTermIDs: [Int64], coverageThreshold: Int) {
          self.japaneseTermIDs = japaneseTermIDs
          self.coverageThreshold = coverageThreshold
        }
      }
      public struct Response: Sendable, Equatable {
        public let invalidTermIDs: Set<Int64>
        public init(invalidTermIDs: Set<Int64>) {
          self.invalidTermIDs = invalidTermIDs
        }
      }
    }

    public var markAsKnown: @Sendable (MarkAsKnown.Request) async throws -> MarkAsKnown.Response
    public var isKnown: @Sendable (IsKnown.Request) async throws -> IsKnown.Response
    public var fetchKnownStatusForTermIDs: @Sendable (FetchKnownStatusForTermIDs.Request) async throws -> FetchKnownStatusForTermIDs.Response
    public var fetchInvalidTermIDs: @Sendable (FetchInvalidTermIDs.Request) async throws -> FetchInvalidTermIDs.Response

    public init(
      markAsKnown: @Sendable @escaping (MarkAsKnown.Request) async throws -> MarkAsKnown.Response,
      isKnown: @Sendable @escaping (IsKnown.Request) async throws -> IsKnown.Response,
      fetchKnownStatusForTermIDs: @Sendable @escaping (FetchKnownStatusForTermIDs.Request) async throws -> FetchKnownStatusForTermIDs.Response,
      fetchInvalidTermIDs: @Sendable @escaping (FetchInvalidTermIDs.Request) async throws -> FetchInvalidTermIDs.Response
    ) {
      self.markAsKnown = markAsKnown
      self.isKnown = isKnown
      self.fetchKnownStatusForTermIDs = fetchKnownStatusForTermIDs
      self.fetchInvalidTermIDs = fetchInvalidTermIDs
    }
  }
  public var knownJapaneseTerm: KnownJapaneseTerm

  public init(
    mediaSource: MediaSource,
    mediaSourceCardCandidate: MediaSourceCardCandidate,
    srsCard: SRSCard,
    knownJapaneseTerm: KnownJapaneseTerm
  ) {
    self.mediaSource = mediaSource
    self.mediaSourceCardCandidate = mediaSourceCardCandidate
    self.srsCard = srsCard
    self.knownJapaneseTerm = knownJapaneseTerm
  }
}
