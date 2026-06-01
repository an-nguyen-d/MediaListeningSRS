import Foundation
import GRDB

struct StudySessionRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {

  var id: Int64?
  var startedAt: Date
  var endedAt: Date
  var cardsReviewed: Int

  mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}
