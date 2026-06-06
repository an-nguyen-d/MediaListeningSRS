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

  // MARK: - Cached transcript (populated at card creation; backfilled for older cards on Mac)
  public var cachedTranscriptText: String = ""
  public var cachedEnglishTranslation: String = ""
  public var cachedLabelRangesJSON: String = ""

  // MARK: - Card type (reserved for future review modes — only listening = 1 for now)
  public var cardType: Int = 1

  // MARK: - Front video visibility (persisted per-card progressive disclosure state)
  public var frontVideoVisibilityRawValue: Int = 0

  // MARK: - Playback speed and streak
  public var playbackSpeed: Double = 1.0
  public var consecutiveCorrectAtCurrentSpeed: Int = 0

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

  // MARK: - Suspension
  public var isSuspended: Bool = false

  public mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}
