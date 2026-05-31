import Foundation
import GRDB

// SRS reviews are explicitly NOT a cascade trigger. Reviews happen too frequently
// (potentially hundreds per session) and mastery status changes are rare relative to
// review volume. Mastery-based filtering is picked up at the next card-creation or
// mark-as-known event, which is sufficient.

internal enum CandidateValidityFilterService {

  private static let coverageThresholdUserDefaultsKey = "MSRS.Settings.minimumCardCoverageCount"
  private static let coverageThresholdDefault = 50

  static func readCoverageThreshold() -> Int {
    let value = UserDefaults.standard.integer(forKey: coverageThresholdUserDefaultsKey)
    return value > 0 ? value : coverageThresholdDefault
  }

  static func computeInvalidTermIDs(
    candidateTermIDs: Set<Int64>,
    coverageThreshold: Int,
    db: Database
  ) throws -> Set<Int64> {
    guard !candidateTermIDs.isEmpty else { return [] }

    var invalid = try KnownJapaneseTermService.computeKnownTermIDs(
      candidateTermIDs: candidateTermIDs,
      db: db
    )

    let placeholders = candidateTermIDs.map { _ in "?" }.joined(separator: ",")
    let args = StatementArguments(
      [coverageThreshold as DatabaseValueConvertible]
      + candidateTermIDs.map { $0 as DatabaseValueConvertible }
    )!
    let coverageRows = try Row.fetchAll(db, sql: """
      SELECT japaneseTermID FROM japaneseTermCardCoverageRecord
      WHERE cardCoverageCount >= ? AND japaneseTermID IN (\(placeholders))
    """, arguments: args)
    for row in coverageRows {
      if let id: Int64 = row["japaneseTermID"] {
        invalid.insert(id)
      }
    }

    return invalid
  }

  static func cascadeAutoFilter(
    changedTermIDs: Set<Int64>,
    coverageThreshold: Int,
    db: Database
  ) throws {
    guard !changedTermIDs.isEmpty else { return }

    let placeholders = changedTermIDs.map { _ in "?" }.joined(separator: ",")
    let findArgs = StatementArguments(changedTermIDs.map { $0 as DatabaseValueConvertible })!

    let candidateRows = try Row.fetchAll(db, sql: """
      SELECT DISTINCT link.candidateID
      FROM mediaSourceCardCandidateJapaneseTermLinkRecord link
      JOIN mediaSourceCardCandidateRecord c ON c.id = link.candidateID
      WHERE link.japaneseTermID IN (\(placeholders))
        AND c.isSkipped = 0
        AND c.wasUsedInCard = 0
        AND c.isAutoFiltered = 0
    """, arguments: findArgs)

    let affectedCandidateIDs: [Int64] = candidateRows.compactMap { $0["candidateID"] }
    guard !affectedCandidateIDs.isEmpty else { return }

    var termIDsByCandidateID: [Int64: Set<Int64>] = [:]
    var allTermIDs: Set<Int64> = []

    let candidatePlaceholders = affectedCandidateIDs.map { _ in "?" }.joined(separator: ",")
    let linkArgs = StatementArguments(affectedCandidateIDs.map { $0 as DatabaseValueConvertible })!
    let linkRows = try Row.fetchAll(db, sql: """
      SELECT candidateID, japaneseTermID
      FROM mediaSourceCardCandidateJapaneseTermLinkRecord
      WHERE candidateID IN (\(candidatePlaceholders))
    """, arguments: linkArgs)

    for row in linkRows {
      guard let candidateID: Int64 = row["candidateID"],
            let termID: Int64 = row["japaneseTermID"] else { continue }
      termIDsByCandidateID[candidateID, default: []].insert(termID)
      allTermIDs.insert(termID)
    }

    let invalidTermIDs = try computeInvalidTermIDs(
      candidateTermIDs: allTermIDs,
      coverageThreshold: coverageThreshold,
      db: db
    )

    let now = Date()
    for candidateID in affectedCandidateIDs {
      guard let termIDs = termIDsByCandidateID[candidateID] else { continue }
      let hasValidTerm = termIDs.contains { !invalidTermIDs.contains($0) }
      if !hasValidTerm {
        try db.execute(sql: """
          UPDATE mediaSourceCardCandidateRecord
          SET isAutoFiltered = 1, lastUpdatedAt = ?
          WHERE id = ?
        """, arguments: [now, candidateID])
      }
    }
  }
}
