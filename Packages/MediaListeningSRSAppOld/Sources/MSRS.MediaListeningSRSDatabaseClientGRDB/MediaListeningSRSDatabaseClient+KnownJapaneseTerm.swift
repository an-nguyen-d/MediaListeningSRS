import Foundation
import GRDB
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_Shared
import MSRS_SharedModels

extension MediaListeningSRSDatabaseClient {

  internal static func japaneseTermEndpoints(
    databaseWriter: DatabaseWriter
  ) -> JapaneseTerm {
    .init(
      markAsFullyKnown: { request in
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
          let coverageThreshold = CandidateValidityFilterService.readCoverageThreshold(db: db)
          try CandidateValidityFilterService.cascadeAutoFilter(
            changedPairs: Set([TermInflectionPair(japaneseTermID: request.japaneseTermID, inflectionKey: "")]),
            coverageThreshold: coverageThreshold,
            db: db
          )
          return .init()
        }
      },
      isFullyKnown: { request in
        try await databaseWriter.read { db in
          let fullyKnownSet = try FullyKnownTermService.computeFullyKnownTermIDs(
            candidateTermIDs: [request.japaneseTermID],
            db: db
          )
          return .init(isFullyKnown: fullyKnownSet.contains(request.japaneseTermID))
        }
      },
      fetchFullyKnownTermIDs: { request in
        try await databaseWriter.read { db in
          let fullyKnownSet = try FullyKnownTermService.computeFullyKnownTermIDs(
            candidateTermIDs: Set(request.japaneseTermIDs),
            db: db
          )
          return .init(fullyKnownTermIDs: fullyKnownSet)
        }
      },
      fetchLearnedScoresForTermIDs: { request in
        try await databaseWriter.read { db in
          let scores = try LearnedTermService.computeLearnedScores(
            termIDs: Set(request.japaneseTermIDs),
            db: db
          )
          return .init(scoresByTermID: scores)
        }
      },
      fetchInvalidTermPairs: { request in
        try await databaseWriter.read { db in
          let candidateSet = Set(request.termPairs)
          let invalidPairs = try CandidateValidityFilterService.computeInvalidTermPairs(
            candidatePairs: candidateSet,
            coverageThreshold: request.coverageThreshold,
            db: db
          )
          return .init(invalidPairs: invalidPairs)
        }
      },
      backfillInflectionKeys: { request in
        try await databaseWriter.write { db in
          for sourceData in request.sourceData {
            let mediaSourceIDValue = sourceData.mediaSourceID.rawValue

            let candidateRows = try Row.fetchAll(db, sql: """
              SELECT id, subtitleIndex FROM mediaSourceCardCandidateRecord
              WHERE mediaSourceID = ?
            """, arguments: [mediaSourceIDValue])

            for candidateRow in candidateRows {
              guard let candidateID: Int64 = candidateRow["id"],
                    let subtitleIndex: Int = candidateRow["subtitleIndex"] else { continue }
              guard let pairs = sourceData.pairsBySubtitleIndex[subtitleIndex], !pairs.isEmpty else { continue }

              try db.execute(sql: """
                DELETE FROM mediaSourceCardCandidateJapaneseTermLinkRecord WHERE candidateID = ?
              """, arguments: [candidateID])

              let uniquePairs = Set(pairs)
              for pair in uniquePairs {
                try db.execute(sql: """
                  INSERT OR IGNORE INTO mediaSourceCardCandidateJapaneseTermLinkRecord
                    (candidateID, japaneseTermID, inflectionKey) VALUES (?, ?, ?)
                """, arguments: [candidateID, pair.japaneseTermID, pair.inflectionKey])
              }
            }

            let cardRows = try Row.fetchAll(db, sql: """
              SELECT id, subtitleIndexStart, subtitleIndexEnd FROM srsCardRecord
              WHERE mediaSourceID = ?
            """, arguments: [mediaSourceIDValue])

            for cardRow in cardRows {
              guard let cardID: Int64 = cardRow["id"],
                    let indexStart: Int = cardRow["subtitleIndexStart"],
                    let indexEnd: Int = cardRow["subtitleIndexEnd"] else { continue }

              var cardPairs = Set<TermInflectionPair>()
              for index in indexStart...indexEnd {
                if let pairs = sourceData.pairsBySubtitleIndex[index] {
                  for pair in pairs { cardPairs.insert(pair) }
                }
              }
              guard !cardPairs.isEmpty else { continue }

              try db.execute(sql: """
                DELETE FROM srsCardJapaneseTermLinkRecord WHERE cardID = ?
              """, arguments: [cardID])

              for pair in cardPairs {
                try db.execute(sql: """
                  INSERT OR IGNORE INTO srsCardJapaneseTermLinkRecord
                    (cardID, japaneseTermID, inflectionKey) VALUES (?, ?, ?)
                """, arguments: [cardID, pair.japaneseTermID, pair.inflectionKey])
              }
            }
          }

          try db.execute(sql: "DELETE FROM japaneseTermCardCoverageRecord")
          try db.execute(sql: """
            INSERT INTO japaneseTermCardCoverageRecord (japaneseTermID, inflectionKey, cardCoverageCount)
            SELECT japaneseTermID, inflectionKey, COUNT(DISTINCT cardID)
            FROM srsCardJapaneseTermLinkRecord
            GROUP BY japaneseTermID, inflectionKey
          """)

          return .init()
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
            SELECT japaneseTermID, SUM(cardCoverageCount) AS cardCoverageCount
            FROM japaneseTermCardCoverageRecord
            WHERE japaneseTermID IN (\(placeholders))
            GROUP BY japaneseTermID
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

// MARK: - FullyKnownTermService

/// "Fully Known" = manually marked by the user. Drives candidate filtering.
internal enum FullyKnownTermService {

  static func computeFullyKnownTermIDs(
    candidateTermIDs: Set<Int64>,
    db: Database
  ) throws -> Set<Int64> {
    guard !candidateTermIDs.isEmpty else { return [] }

    let placeholders = candidateTermIDs.map { _ in "?" }.joined(separator: ",")
    let args = StatementArguments(candidateTermIDs.map { $0 as DatabaseValueConvertible })!

    let rows = try Row.fetchAll(db, sql: """
      SELECT japaneseTermID FROM knownJapaneseTermRecord
      WHERE japaneseTermID IN (\(placeholders))
    """, arguments: args)
    return Set(rows.compactMap { $0["japaneseTermID"] as Int64? })
  }
}

// MARK: - LearnedTermService

/// "Learned" = SRS-driven passive vocabulary score (0→1).
/// score = min(1, sum(min(stability, 365) for top 100 cards by stability) / 365)
internal enum LearnedTermService {

  private static let stabilityCap: Double = 365
  private static let targetSum: Double = 365
  private static let maxCardsPerTerm: Int = 100

  static func computeLearnedScores(
    termIDs: Set<Int64>,
    db: Database
  ) throws -> [Int64: Double] {
    guard !termIDs.isEmpty else { return [:] }

    let placeholders = termIDs.map { _ in "?" }.joined(separator: ",")
    let args = StatementArguments(termIDs.map { $0 as DatabaseValueConvertible })!

    let rows = try Row.fetchAll(db, sql: """
      SELECT japaneseTermID, SUM(cappedStability) AS stabilitySum
      FROM (
        SELECT link.japaneseTermID,
               MIN(card.stability, \(stabilityCap)) AS cappedStability,
               ROW_NUMBER() OVER (
                 PARTITION BY link.japaneseTermID
                 ORDER BY card.stability DESC
               ) AS rn
        FROM srsCardJapaneseTermLinkRecord link
        JOIN srsCardRecord card ON card.id = link.cardID
        WHERE link.japaneseTermID IN (\(placeholders))
      )
      WHERE rn <= \(maxCardsPerTerm)
      GROUP BY japaneseTermID
    """, arguments: args)

    var scores: [Int64: Double] = [:]
    for row in rows {
      guard let termID: Int64 = row["japaneseTermID"],
            let sum: Double = row["stabilitySum"] else { continue }
      scores[termID] = min(1.0, sum / targetSum)
    }
    return scores
  }
}
