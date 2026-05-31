import Foundation
import GRDB

public struct MediaSourceRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
  public var id: Int64?

  public var createdAt: Date
  public var lastUpdatedAt: Date

  public var jmlMediaReferenceType: Int   // 0 = movie, 1 = episode
  public var jmlMediaReferenceID: Int64

  public mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}
