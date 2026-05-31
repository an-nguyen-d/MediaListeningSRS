import Foundation
import GRDB
import MSRS_SharedModels
import MSRS_MediaListeningSRSDatabaseClient

extension MediaListeningSRSDatabaseClient {

  internal static func mediaSourceEndpoints(
    databaseWriter: DatabaseWriter
  ) -> MediaSource {
    .init(
      create: { request in
        try await databaseWriter.write { db in
          let columns = GRDBMapper.MediaSource.referenceColumns(request.jmlMediaReference)
          let now = Date()
          var record = MediaSourceRecord(
            id: nil,
            createdAt: now,
            lastUpdatedAt: now,
            jmlMediaReferenceType: columns.type,
            jmlMediaReferenceID: columns.id
          )
          try record.insert(db)
          return .init(model: GRDBMapper.MediaSource.mapToModel(from: record))
        }
      },
      fetch: { request in
        try await databaseWriter.read { db in
          guard let record = try MediaSourceRecord.fetchOne(db, key: request.id.rawValue) else {
            throw MediaListeningSRSDatabaseError.recordNotFound(id: request.id.rawValue)
          }
          return .init(model: GRDBMapper.MediaSource.mapToModel(from: record))
        }
      },
      observeAll: { _ in
        AsyncThrowingStream { continuation in
          Task { @MainActor in
            let token = ValueObservation
              .tracking { db in
                try MediaSourceRecord
                  .order(Column("lastUpdatedAt").desc, Column("id").asc)
                  .fetchAll(db)
              }
              .start(
                in: databaseWriter,
                onError: { continuation.finish(throwing: $0) },
                onChange: { records in
                  let models = records.map { GRDBMapper.MediaSource.mapToModel(from: $0) }
                  continuation.yield(models)
                }
              )
            continuation.onTermination = { _ in token.cancel() }
          }
        }
      }
    )
  }
}
