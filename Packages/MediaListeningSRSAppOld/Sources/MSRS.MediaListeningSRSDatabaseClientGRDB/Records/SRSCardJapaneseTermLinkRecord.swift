import Foundation
import GRDB

public struct SRSCardJapaneseTermLinkRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
  public var id: Int64?

  public var cardID: Int64
  public var japaneseTermID: Int64
  public var inflectionKey: String

  public mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}
