import Foundation
import GRDB

public struct SRSCardJapaneseTermLinkRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
  public var id: Int64?

  public var cardID: Int64
  public var japaneseTermID: Int64

  public mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}
