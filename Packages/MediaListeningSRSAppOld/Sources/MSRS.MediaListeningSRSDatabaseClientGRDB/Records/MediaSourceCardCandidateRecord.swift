import Foundation
import GRDB

public struct MediaSourceCardCandidateRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
  public var id: Int64?

  public var createdAt: Date
  public var lastUpdatedAt: Date

  public var mediaSourceID: Int64

  public var subtitleIndex: Int

  public var isSkipped: Bool
  /// Set when an SRSCard is created whose subtitle range covers this candidate. Drives the
  /// queue's "move to next item after processing" behavior alongside `isSkipped`.
  public var wasUsedInCard: Bool

  public mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}
