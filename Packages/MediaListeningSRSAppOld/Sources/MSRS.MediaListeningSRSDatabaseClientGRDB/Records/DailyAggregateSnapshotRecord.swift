import Foundation
import GRDB

struct DailyAggregateSnapshotRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
  var id: Int64?
  var snapshotDate: String
  var totalActiveCards: Int
  var newCardCount: Int
  var learningCardCount: Int
  var reviewCardCount: Int
  var relearningCardCount: Int
  var totalUniqueTermsCovered: Int
  var totalFullyKnownTerms: Int

  mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}
