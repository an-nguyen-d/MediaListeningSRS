import Foundation
import GRDB

public struct SRSCardRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
  public var id: Int64?

  // MARK: - Timestamps
  public var createdAt: Date
  public var lastUpdatedAt: Date

  // MARK: - Relationships
  public var mediaSourceID: Int64

  // MARK: - Snapshotted index range (frozen at promote time)
  public var subtitleIndexStart: Int
  public var subtitleIndexEnd: Int

  // MARK: - Snapshotted clip timing (frozen at promote time)
  public var clipStartTimeSeconds: TimeInterval
  public var clipEndTimeSeconds: TimeInterval

  // MARK: - Clip file
  public var clipRelativeFilePath: String   // relative to Documents/MediaListeningSRS/clips/

  // MARK: - Card type (reserved for future review modes — only listening = 1 for now)
  public var cardType: Int = 1

  // MARK: - FSRS scheduling state (populated by the FSRS-driven review flow; defaults = new card)
  public var stateRawValue: Int = 0       // CardState .new
  public var stability: Double = 0
  public var difficulty: Double = 0
  public var elapsedDays: Double = 0
  public var scheduledDays: Double = 0
  public var repCount: Int = 0
  public var lapseCount: Int = 0
  public var lastReviewDate: Date?
  public var dueDate: Date?

  public mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}
