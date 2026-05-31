import Foundation
import GRDB

public struct KnownJapaneseTermRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
  public var id: Int64?

  /// iYomi internal term ID (DictionaryTermModel.ID raw value).
  public var japaneseTermID: Int64
  public var manuallyMarkedAt: Date

  public mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}
