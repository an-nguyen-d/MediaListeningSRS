import Foundation
import GRDB
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_SharedModels

extension MediaListeningSRSDatabaseClient {

  internal static func knownJapaneseTermEndpoints(
    databaseWriter: DatabaseWriter
  ) -> KnownJapaneseTerm {
    .init(
      markAsKnown: { request in
        try await databaseWriter.write { db in
          let exists = try Int.fetchOne(
            db,
            sql: "SELECT 1 FROM knownJapaneseTermRecord WHERE japaneseTermID = ? LIMIT 1",
            arguments: [request.japaneseTermID]
          ) != nil
          if !exists {
            var record = KnownJapaneseTermRecord(
              id: nil,
              japaneseTermID: request.japaneseTermID,
              manuallyMarkedAt: Date()
            )
            try record.insert(db)
          }
          let coverageThreshold = CandidateValidityFilterService.readCoverageThreshold()
          try CandidateValidityFilterService.cascadeAutoFilter(
            changedTermIDs: Set([request.japaneseTermID]),
            coverageThreshold: coverageThreshold,
            db: db
          )
          return .init()
        }
      },
      isKnown: { request in
        try await databaseWriter.read { db in
          let knownSet = try KnownJapaneseTermService.computeKnownTermIDs(
            candidateTermIDs: [request.japaneseTermID],
            db: db
          )
          return .init(isKnown: knownSet.contains(request.japaneseTermID))
        }
      },
      fetchKnownStatusForTermIDs: { request in
        try await databaseWriter.read { db in
          let knownSet = try KnownJapaneseTermService.computeKnownTermIDs(
            candidateTermIDs: Set(request.japaneseTermIDs),
            db: db
          )
          return .init(knownTermIDs: knownSet)
        }
      },
      fetchInvalidTermIDs: { request in
        try await databaseWriter.read { db in
          let candidateSet = Set(request.japaneseTermIDs)
          let invalidTermIDs = try CandidateValidityFilterService.computeInvalidTermIDs(
            candidateTermIDs: candidateSet,
            coverageThreshold: request.coverageThreshold,
            db: db
          )
          return .init(invalidTermIDs: invalidTermIDs)
        }
      },
      fetchCoverageCountsForTermIDs: { request in
        try await databaseWriter.read { db in
          guard !request.japaneseTermIDs.isEmpty else {
            return .init(coverageCountsByTermID: [:])
          }
          let placeholders = request.japaneseTermIDs.map { _ in "?" }.joined(separator: ",")
          let args = StatementArguments(request.japaneseTermIDs.map { $0 as DatabaseValueConvertible })!
          let rows = try Row.fetchAll(db, sql: """
            SELECT japaneseTermID, cardCoverageCount
            FROM japaneseTermCardCoverageRecord
            WHERE japaneseTermID IN (\(placeholders))
          """, arguments: args)
          var result: [Int64: Int] = [:]
          for row in rows {
            if let termID: Int64 = row["japaneseTermID"],
               let count: Int = row["cardCoverageCount"] {
              result[termID] = count
            }
          }
          return .init(coverageCountsByTermID: result)
        }
      }
    )
  }
}

// MARK: - KnownJapaneseTermService (the single source of truth)

/// All "is this word known?" decisions in the app route through this service.
/// Do not duplicate the predicate anywhere else.
internal enum KnownJapaneseTermService {

  /// Returns the subset of `candidateTermIDs` that are known.
  ///
  /// A term is known iff:
  ///   1. It appears in `knownJapaneseTermRecord` (manually marked), OR
  ///   2. It has reached SRS mastery: at least `masteryMinimumCardsCount` cards link to it
  ///      AND every one of those cards has stability >= `masteryMinimumStability`.
  static func computeKnownTermIDs(
    candidateTermIDs: Set<Int64>,
    db: Database
  ) throws -> Set<Int64> {
    guard !candidateTermIDs.isEmpty else { return [] }

    let settingsRow = try Row.fetchOne(db, sql: """
      SELECT masteryMinimumCardsCount, masteryMinimumStability
      FROM appSettingsRecord
      ORDER BY id ASC LIMIT 1
    """)
    let masteryMinimumCardsCount: Int = settingsRow?["masteryMinimumCardsCount"] ?? 10
    let masteryMinimumStability: Double = settingsRow?["masteryMinimumStability"] ?? 30

    let placeholders = candidateTermIDs.map { _ in "?" }.joined(separator: ",")
    let manualArgs = StatementArguments(candidateTermIDs.map { $0 as DatabaseValueConvertible })!

    let manualRows = try Row.fetchAll(db, sql: """
      SELECT japaneseTermID FROM knownJapaneseTermRecord
      WHERE japaneseTermID IN (\(placeholders))
    """, arguments: manualArgs)
    var known: Set<Int64> = Set(manualRows.compactMap { $0["japaneseTermID"] as Int64? })

    let masteryArgs = StatementArguments(
      candidateTermIDs.map { $0 as DatabaseValueConvertible }
      + [masteryMinimumStability as DatabaseValueConvertible,
         masteryMinimumCardsCount as DatabaseValueConvertible]
    )!
    let masteryRows = try Row.fetchAll(db, sql: """
      SELECT link.japaneseTermID AS termID
      FROM srsCardJapaneseTermLinkRecord link
      JOIN srsCardRecord card ON card.id = link.cardID
      WHERE link.japaneseTermID IN (\(placeholders))
      GROUP BY link.japaneseTermID
      HAVING COUNT(CASE WHEN card.stability >= ? THEN 1 END) >= ?
    """, arguments: masteryArgs)
    for row in masteryRows {
      if let id: Int64 = row["termID"] {
        known.insert(id)
      }
    }
    return known
  }
}
