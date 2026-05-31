import Foundation
import GRDB

public struct AppSettingsRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
  public var id: Int64?

  public var masteryMinimumCardsCount: Int
  public var masteryMinimumStability: Double

  public mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}
