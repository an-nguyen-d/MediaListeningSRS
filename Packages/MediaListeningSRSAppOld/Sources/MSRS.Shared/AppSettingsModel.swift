import Foundation

public struct AppSettingsModel: Sendable, Equatable {

  public var desiredRetention: Double
  public var showFrontTranscript: Bool
  public var minimumCardCoverageCount: Int
  public var studySessionInactivityTimeout: Int
  public var requireSkipOrMakeCardConfirmation: Bool
  public var autoLoopVideo: Bool
  public var llmGradingPrompt: String
  public var syncIntervalSeconds: Int

  public init(
    desiredRetention: Double = 0.9,
    showFrontTranscript: Bool = true,
    minimumCardCoverageCount: Int = 50,
    studySessionInactivityTimeout: Int = 300,
    requireSkipOrMakeCardConfirmation: Bool = true,
    autoLoopVideo: Bool = false,
    llmGradingPrompt: String = "",
    syncIntervalSeconds: Int = 60
  ) {
    self.desiredRetention = desiredRetention
    self.showFrontTranscript = showFrontTranscript
    self.minimumCardCoverageCount = minimumCardCoverageCount
    self.studySessionInactivityTimeout = studySessionInactivityTimeout
    self.requireSkipOrMakeCardConfirmation = requireSkipOrMakeCardConfirmation
    self.autoLoopVideo = autoLoopVideo
    self.llmGradingPrompt = llmGradingPrompt
    self.syncIntervalSeconds = syncIntervalSeconds
  }
}
