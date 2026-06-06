import Foundation
import GRDB

public struct SRSReviewEventRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
  public var id: Int64?

  public var cardID: Int64
  public var ratingRawValue: Int                    // FSRS Rating (1=again, 2=hard, 3=good, 4=easy)
  public var stabilityAfterReview: Double
  public var difficultyAfterReview: Double
  public var dueDateAfterReview: Date
  public var occurredAt: Date
  public var listenCount: Int?

  public mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}
