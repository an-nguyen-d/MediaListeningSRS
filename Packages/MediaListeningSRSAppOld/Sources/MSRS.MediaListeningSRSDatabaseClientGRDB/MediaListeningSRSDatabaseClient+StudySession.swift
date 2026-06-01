import Foundation
import GRDB
import MSRS_SharedModels
import MSRS_MediaListeningSRSDatabaseClient

extension MediaListeningSRSDatabaseClient {

  internal static func studySessionEndpoints(
    databaseWriter: DatabaseWriter
  ) -> StudySession {
    .init(
      createSession: { request in
        try await databaseWriter.write { db in
          var record = StudySessionRecord(
            id: nil,
            startedAt: request.startedAt,
            endedAt: request.endedAt,
            cardsReviewed: request.cardsReviewed
          )
          try record.insert(db)
          return .init(model: GRDBMapper.StudySession.mapToModel(from: record))
        }
      },
      updateSession: { request in
        try await databaseWriter.write { db in
          guard var record = try StudySessionRecord.fetchOne(db, key: request.id.rawValue) else {
            throw MediaListeningSRSDatabaseError.recordNotFound(id: request.id.rawValue)
          }
          record.endedAt = request.endedAt
          record.cardsReviewed = request.cardsReviewed
          try record.update(db)
          return .init()
        }
      },
      fetchMostRecent: { _ in
        try await databaseWriter.read { db in
          let record = try StudySessionRecord
            .order(Column("startedAt").desc)
            .fetchOne(db)
          return .init(model: record.map { GRDBMapper.StudySession.mapToModel(from: $0) })
        }
      },
      fetchInDateRange: { request in
        try await databaseWriter.read { db in
          let records = try StudySessionRecord
            .filter(Column("startedAt") >= request.startDate && Column("startedAt") <= request.endDate)
            .order(Column("startedAt").asc)
            .fetchAll(db)
          return .init(models: records.map { GRDBMapper.StudySession.mapToModel(from: $0) })
        }
      }
    )
  }
}
