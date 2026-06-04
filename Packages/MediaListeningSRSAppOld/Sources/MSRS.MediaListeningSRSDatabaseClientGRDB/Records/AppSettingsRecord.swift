import Foundation
import GRDB

public struct AppSettingsRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
  public var id: Int64?

  public var masteryMinimumCardsCount: Int
  public var masteryMinimumStability: Double

  public var desiredRetention: Double
  public var showFrontTranscript: Bool
  public var minimumCardCoverageCount: Int
  public var studySessionInactivityTimeout: Int
  public var requireSkipOrMakeCardConfirmation: Bool
  public var autoLoopVideo: Bool
  public var llmGradingPrompt: String
  public var syncIntervalSeconds: Int
  public var candidatePlayDelay: Double

  public mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}
