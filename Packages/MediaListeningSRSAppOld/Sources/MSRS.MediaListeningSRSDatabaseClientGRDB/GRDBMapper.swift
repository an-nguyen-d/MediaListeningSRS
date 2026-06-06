import Foundation
import MSRS_Shared
import MSRS_SharedModels
import JML_JMLSharedModels

internal enum GRDBMapper {

  // MARK: - MediaSource

  internal enum MediaSource {

    internal static func mapToModel(from record: MediaSourceRecord) -> MediaSourceModel {
      guard let rawID = record.id else {
        fatalError("MediaSourceRecord missing id after fetch")
      }

      let reference: MediaSourceModel.JMLMediaReference
      switch record.jmlMediaReferenceType {
      case 0:
        reference = .movie(.init(rawValue: record.jmlMediaReferenceID))
      case 1:
        reference = .episode(.init(rawValue: record.jmlMediaReferenceID))
      default:
        fatalError("Unknown jmlMediaReferenceType raw value \(record.jmlMediaReferenceType)")
      }

      return .init(
        id: .init(rawValue: rawID),
        createdAt: record.createdAt,
        lastUpdatedAt: record.lastUpdatedAt,
        jmlMediaReference: reference
      )
    }

    internal static func referenceColumns(
      _ reference: MediaSourceModel.JMLMediaReference
    ) -> (type: Int, id: Int64) {
      switch reference {
      case .movie(let id): return (0, id.rawValue)
      case .episode(let id): return (1, id.rawValue)
      }
    }
  }

  // MARK: - MediaSourceCardCandidate

  internal enum MediaSourceCardCandidate {

    internal static func mapToModel(
      from record: MediaSourceCardCandidateRecord
    ) -> MediaSourceCardCandidateModel {
      guard let rawID = record.id else {
        fatalError("MediaSourceCardCandidateRecord missing id after fetch")
      }

      return .init(
        id: .init(rawValue: rawID),
        createdAt: record.createdAt,
        lastUpdatedAt: record.lastUpdatedAt,
        mediaSourceID: .init(rawValue: record.mediaSourceID),
        subtitleIndex: record.subtitleIndex,
        isSkipped: record.isSkipped,
        wasUsedInCard: record.wasUsedInCard,
        isAutoFiltered: record.isAutoFiltered
      )
    }
  }

  // MARK: - SRSCard

  internal enum SRSCard {

    internal static func mapToModel(from record: SRSCardRecord) -> SRSCardModel {
      guard let rawID = record.id else {
        fatalError("SRSCardRecord missing id after fetch")
      }

      return .init(
        id: .init(rawValue: rawID),
        createdAt: record.createdAt,
        lastUpdatedAt: record.lastUpdatedAt,
        mediaSourceID: .init(rawValue: record.mediaSourceID),
        subtitleIndexStart: record.subtitleIndexStart,
        subtitleIndexEnd: record.subtitleIndexEnd,
        clipStartTimeSeconds: record.clipStartTimeSeconds,
        clipEndTimeSeconds: record.clipEndTimeSeconds,
        clipRelativeFilePath: record.clipRelativeFilePath,
        cachedTranscriptText: record.cachedTranscriptText,
        cachedEnglishTranslation: record.cachedEnglishTranslation,
        cachedLabelRanges: SRSCardLabelRange.decodeFromJSON(record.cachedLabelRangesJSON),
        frontVideoVisibility: SRSCardModel.FrontVideoVisibility(rawValue: record.frontVideoVisibilityRawValue) ?? .blackScreen,
        playbackSpeed: record.playbackSpeed,
        consecutiveCorrectAtCurrentSpeed: record.consecutiveCorrectAtCurrentSpeed,
        isSuspended: record.isSuspended
      )
    }
  }

  // MARK: - StudySession

  internal enum StudySession {

    internal static func mapToModel(from record: StudySessionRecord) -> StudySessionModel {
      guard let rawID = record.id else {
        fatalError("StudySessionRecord missing id after fetch")
      }

      return .init(
        id: .init(rawValue: rawID),
        startedAt: record.startedAt,
        endedAt: record.endedAt,
        cardsReviewed: record.cardsReviewed
      )
    }
  }

  // MARK: - DailyAggregateSnapshot

  internal enum DailyAggregateSnapshot {

    internal static func mapToModel(from record: DailyAggregateSnapshotRecord) -> DailyAggregateSnapshotModel {
      guard let rawID = record.id else {
        fatalError("DailyAggregateSnapshotRecord missing id after fetch")
      }

      return .init(
        id: .init(rawValue: rawID),
        snapshotDate: record.snapshotDate,
        totalActiveCards: record.totalActiveCards,
        newCardCount: record.newCardCount,
        learningCardCount: record.learningCardCount,
        reviewCardCount: record.reviewCardCount,
        relearningCardCount: record.relearningCardCount,
        totalUniqueTermsCovered: record.totalUniqueTermsCovered,
        totalFullyKnownTerms: record.totalFullyKnownTerms
      )
    }
  }

  // MARK: - DailyCardSnapshot

  internal enum DailyCardSnapshot {

    internal static func mapToModel(from record: DailyCardSnapshotRecord) -> DailyCardSnapshotModel {
      guard let rawID = record.id else {
        fatalError("DailyCardSnapshotRecord missing id after fetch")
      }

      return .init(
        id: .init(rawValue: rawID),
        aggregateSnapshotID: .init(rawValue: record.aggregateSnapshotID),
        cardID: .init(rawValue: record.cardID),
        stateRawValue: record.stateRawValue,
        stability: record.stability,
        difficulty: record.difficulty,
        repCount: record.repCount,
        lapseCount: record.lapseCount,
        dueDate: record.dueDate
      )
    }
  }
}
