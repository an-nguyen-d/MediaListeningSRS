import Foundation
import GRDB

struct DailyCardSnapshotRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
  var id: Int64?
  var aggregateSnapshotID: Int64
  var cardID: Int64
  var stateRawValue: Int
  var stability: Double
  var difficulty: Double
  var repCount: Int
  var lapseCount: Int
  var dueDate: Date?

  mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}
