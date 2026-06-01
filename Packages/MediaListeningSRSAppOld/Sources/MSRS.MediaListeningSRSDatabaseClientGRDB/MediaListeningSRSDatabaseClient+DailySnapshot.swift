import Foundation
import GRDB
import MSRS_SharedModels
import MSRS_MediaListeningSRSDatabaseClient

extension MediaListeningSRSDatabaseClient {

  internal static func dailySnapshotEndpoints(
    databaseWriter: DatabaseWriter
  ) -> DailySnapshot {

    let dateFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "yyyy-MM-dd"
      f.locale = Locale(identifier: "en_US_POSIX")
      return f
    }()

    return .init(
      createIfNeeded: { request in
        try await databaseWriter.write { db in
          let dateString = dateFormatter.string(from: request.date)

          let existingCount = try DailyAggregateSnapshotRecord
            .filter(Column("snapshotDate") == dateString)
            .fetchCount(db)
          if existingCount > 0 {
            return .init(wasCreated: false)
          }

          let totalActiveCards = try SRSCardRecord.fetchCount(db)

          // FSRS CardState: 0=new, 1=learning, 2=review, 3=relearning
          let stateCounts = try Row.fetchAll(db, sql: """
            SELECT stateRawValue, COUNT(*) as cnt
            FROM srsCardRecord
            GROUP BY stateRawValue
          """)
          var countsByState: [Int: Int] = [:]
          for row in stateCounts {
            countsByState[row["stateRawValue"]] = row["cnt"]
          }

          let totalUniqueTermsCovered = try Int.fetchOne(db, sql: """
            SELECT COUNT(DISTINCT japaneseTermID) FROM srsCardJapaneseTermLinkRecord
          """) ?? 0

          let totalFullyKnownTerms = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM knownJapaneseTermRecord
          """) ?? 0

          var aggregate = DailyAggregateSnapshotRecord(
            id: nil,
            snapshotDate: dateString,
            totalActiveCards: totalActiveCards,
            newCardCount: countsByState[0, default: 0],
            learningCardCount: countsByState[1, default: 0],
            reviewCardCount: countsByState[2, default: 0],
            relearningCardCount: countsByState[3, default: 0],
            totalUniqueTermsCovered: totalUniqueTermsCovered,
            totalFullyKnownTerms: totalFullyKnownTerms
          )
          try aggregate.insert(db)

          guard let aggregateID = aggregate.id else {
            return .init(wasCreated: true)
          }

          try db.execute(sql: """
            INSERT INTO dailyCardSnapshotRecord
              (aggregateSnapshotID, cardID, stateRawValue, stability, difficulty, repCount, lapseCount, dueDate)
            SELECT ?, id, stateRawValue, stability, difficulty, repCount, lapseCount, dueDate
            FROM srsCardRecord
          """, arguments: [aggregateID])

          return .init(wasCreated: true)
        }
      },
      fetchAggregatesInDateRange: { request in
        try await databaseWriter.read { db in
          let records = try DailyAggregateSnapshotRecord.fetchAll(db, sql: """
            SELECT * FROM dailyAggregateSnapshotRecord
            WHERE snapshotDate BETWEEN ? AND ?
            ORDER BY snapshotDate ASC
          """, arguments: [request.startDate, request.endDate])
          return .init(models: records.map { GRDBMapper.DailyAggregateSnapshot.mapToModel(from: $0) })
        }
      },
      fetchCardSnapshotsForDate: { request in
        try await databaseWriter.read { db in
          guard let aggregate = try DailyAggregateSnapshotRecord
            .filter(Column("snapshotDate") == request.snapshotDate)
            .fetchOne(db),
                let aggregateID = aggregate.id else {
            return .init(models: [])
          }
          let records = try DailyCardSnapshotRecord.fetchAll(db, sql: """
            SELECT * FROM dailyCardSnapshotRecord
            WHERE aggregateSnapshotID = ?
          """, arguments: [aggregateID])
          return .init(models: records.map { GRDBMapper.DailyCardSnapshot.mapToModel(from: $0) })
        }
      }
    )
  }
}
