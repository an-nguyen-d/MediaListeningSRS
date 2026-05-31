import Foundation
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
        clipRelativeFilePath: record.clipRelativeFilePath
      )
    }
  }
}
