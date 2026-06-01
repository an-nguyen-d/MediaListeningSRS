import Foundation
import GRDB
import MSRS_SharedModels
import MSRS_MediaListeningSRSDatabaseClient

extension MediaListeningSRSDatabaseClient {

  internal static func mediaSourceCardCandidateEndpoints(
    databaseWriter: DatabaseWriter
  ) -> MediaSourceCardCandidate {
    .init(
      bulkCreate: { request in
        try await databaseWriter.write { db in
          let now = Date()
          var createdRecords: [MediaSourceCardCandidateRecord] = []
          createdRecords.reserveCapacity(request.candidates.count)

          for input in request.candidates {
            var record = MediaSourceCardCandidateRecord(
              id: nil,
              createdAt: now,
              lastUpdatedAt: now,
              mediaSourceID: request.mediaSourceID.rawValue,
              subtitleIndex: input.subtitleIndex,
              isSkipped: false,
              wasUsedInCard: false,
              isAutoFiltered: false
            )
            try record.insert(db)
            createdRecords.append(record)

            guard let candidateID = record.id else { continue }
            for termID in input.japaneseTermIDs {
              var link = MediaSourceCardCandidateJapaneseTermLinkRecord(
                id: nil,
                candidateID: candidateID,
                japaneseTermID: termID
              )
              try link.insert(db)
            }
          }

          let models = createdRecords.map {
            GRDBMapper.MediaSourceCardCandidate.mapToModel(from: $0)
          }
          return .init(createdModels: models)
        }
      },
      setSkipped: { request in
        try await databaseWriter.write { db in
          guard var record = try MediaSourceCardCandidateRecord.fetchOne(
            db,
            key: request.id.rawValue
          ) else {
            throw MediaListeningSRSDatabaseError.recordNotFound(id: request.id.rawValue)
          }
          record.isSkipped = request.isSkipped
          record.lastUpdatedAt = Date()
          try record.update(db)
          return .init(updatedModel: GRDBMapper.MediaSourceCardCandidate.mapToModel(from: record))
        }
      },
      observeForSource: { request in
        AsyncThrowingStream { continuation in
          Task { @MainActor in
            let token = ValueObservation
              .tracking { db in
                try MediaSourceCardCandidateRecord
                  .filter(Column("mediaSourceID") == request.mediaSourceID.rawValue)
                  .filter(Column("isSkipped") == false)
                  .filter(Column("wasUsedInCard") == false)
                  .filter(Column("isAutoFiltered") == false)
                  .order(Column("subtitleIndex").asc)
                  .fetchAll(db)
              }
              .start(
                in: databaseWriter,
                onError: { continuation.finish(throwing: $0) },
                onChange: { records in
                  let models = records.map {
                    GRDBMapper.MediaSourceCardCandidate.mapToModel(from: $0)
                  }
                  continuation.yield(models)
                }
              )
            continuation.onTermination = { _ in token.cancel() }
          }
        }
      },
      fetchTermIDsForCandidate: { request in
        try await databaseWriter.read { db in
          let rows = try Row.fetchAll(db, sql: """
            SELECT japaneseTermID
            FROM mediaSourceCardCandidateJapaneseTermLinkRecord
            WHERE candidateID = ?
          """, arguments: [request.candidateID.rawValue])
          return .init(japaneseTermIDs: rows.compactMap { $0["japaneseTermID"] as Int64? })
        }
      },
      fetchTotalCandidateCountForSource: { request in
        try await databaseWriter.read { db in
          let count = try MediaSourceCardCandidateRecord
            .filter(Column("mediaSourceID") == request.mediaSourceID.rawValue)
            .fetchCount(db)
          return .init(totalCount: count)
        }
      }
    )
  }
}
