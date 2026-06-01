import Foundation
import GRDB

public struct JapaneseTermCardCoverageRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
  public var id: Int64?
  public var japaneseTermID: Int64
  public var inflectionKey: String
  public var cardCoverageCount: Int

  public mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}
