import Foundation
import GRDB
import MSRS_Shared
import MSRS_SharedModels

internal enum CandidateValidityFilterService {

  private static let coverageThresholdUserDefaultsKey = "MSRS.Settings.minimumCardCoverageCount"
  private static let coverageThresholdDefault = 50

  static func readCoverageThreshold() -> Int {
    let value = UserDefaults.standard.integer(forKey: coverageThresholdUserDefaultsKey)
    return value > 0 ? value : coverageThresholdDefault
  }

  static func computeInvalidTermPairs(
    candidatePairs: Set<TermInflectionPair>,
    coverageThreshold: Int,
    db: Database
  ) throws -> Set<TermInflectionPair> {
    guard !candidatePairs.isEmpty else { return [] }

    let allTermIDs = Set(candidatePairs.map(\.japaneseTermID))
    let fullyKnownTermIDs = try FullyKnownTermService.computeFullyKnownTermIDs(
      candidateTermIDs: allTermIDs,
      db: db
    )

    var invalid = Set<TermInflectionPair>()
    for pair in candidatePairs where fullyKnownTermIDs.contains(pair.japaneseTermID) {
      invalid.insert(pair)
    }

    let placeholders = candidatePairs.map { _ in "(?, ?)" }.joined(separator: ",")
    var args: [DatabaseValueConvertible] = [coverageThreshold]
    for pair in candidatePairs {
      args.append(pair.japaneseTermID)
      args.append(pair.inflectionKey)
    }
    let coverageRows = try Row.fetchAll(db, sql: """
      SELECT japaneseTermID, inflectionKey FROM japaneseTermCardCoverageRecord
      WHERE cardCoverageCount >= ?
        AND (japaneseTermID, inflectionKey) IN (\(placeholders))
    """, arguments: StatementArguments(args)!)
    for row in coverageRows {
      if let termID: Int64 = row["japaneseTermID"],
         let key: String = row["inflectionKey"] {
        invalid.insert(TermInflectionPair(japaneseTermID: termID, inflectionKey: key))
      }
    }

    return invalid
  }

  static func cascadeAutoFilter(
    changedPairs: Set<TermInflectionPair>,
    coverageThreshold: Int,
    db: Database
  ) throws {
    guard !changedPairs.isEmpty else { return }

    let changedTermIDs = Set(changedPairs.map(\.japaneseTermID))
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

    var pairsByCandidateID: [Int64: Set<TermInflectionPair>] = [:]
    var allPairs: Set<TermInflectionPair> = []

    let candidatePlaceholders = affectedCandidateIDs.map { _ in "?" }.joined(separator: ",")
    let linkArgs = StatementArguments(affectedCandidateIDs.map { $0 as DatabaseValueConvertible })!
    let linkRows = try Row.fetchAll(db, sql: """
      SELECT candidateID, japaneseTermID, inflectionKey
      FROM mediaSourceCardCandidateJapaneseTermLinkRecord
      WHERE candidateID IN (\(candidatePlaceholders))
    """, arguments: linkArgs)

    for row in linkRows {
      guard let candidateID: Int64 = row["candidateID"],
            let termID: Int64 = row["japaneseTermID"],
            let key: String = row["inflectionKey"] else { continue }
      let pair = TermInflectionPair(japaneseTermID: termID, inflectionKey: key)
      pairsByCandidateID[candidateID, default: []].insert(pair)
      allPairs.insert(pair)
    }

    let invalidPairs = try computeInvalidTermPairs(
      candidatePairs: allPairs,
      coverageThreshold: coverageThreshold,
      db: db
    )

    let now = Date()
    for candidateID in affectedCandidateIDs {
      guard let pairs = pairsByCandidateID[candidateID] else { continue }
      let hasValidPair = pairs.contains { !invalidPairs.contains($0) }
      if !hasValidPair {
        try db.execute(sql: """
          UPDATE mediaSourceCardCandidateRecord
          SET isAutoFiltered = 1, lastUpdatedAt = ?
          WHERE id = ?
        """, arguments: [now, candidateID])
      }
    }
  }
}
