import Foundation
import GRDB
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_Shared

extension MediaListeningSRSDatabaseClient {

  static func appSettingsEndpoints(
    databaseWriter: any DatabaseWriter
  ) -> AppSettings {
    .init(
      fetch: { _ in
        try await databaseWriter.read { db in
          guard let record = try AppSettingsRecord.fetchOne(db) else {
            return .init(model: AppSettingsModel())
          }
          return .init(model: record.toModel())
        }
      },
      update: { request in
        try await databaseWriter.write { db in
          guard var record = try AppSettingsRecord.fetchOne(db) else {
            assertionFailure("AppSettingsRecord row missing")
            return .init()
          }
          record.desiredRetention = request.model.desiredRetention
          record.showFrontTranscript = request.model.showFrontTranscript
          record.minimumCardCoverageCount = request.model.minimumCardCoverageCount
          record.studySessionInactivityTimeout = request.model.studySessionInactivityTimeout
          record.requireSkipOrMakeCardConfirmation = request.model.requireSkipOrMakeCardConfirmation
          record.autoLoopVideo = request.model.autoLoopVideo
          record.llmGradingPrompt = request.model.llmGradingPrompt
          record.syncIntervalSeconds = request.model.syncIntervalSeconds
          try record.update(db)
          return .init()
        }
      }
    )
  }
}

extension AppSettingsRecord {
  func toModel() -> AppSettingsModel {
    AppSettingsModel(
      desiredRetention: desiredRetention,
      showFrontTranscript: showFrontTranscript,
      minimumCardCoverageCount: minimumCardCoverageCount,
      studySessionInactivityTimeout: studySessionInactivityTimeout,
      requireSkipOrMakeCardConfirmation: requireSkipOrMakeCardConfirmation,
      autoLoopVideo: autoLoopVideo,
      llmGradingPrompt: llmGradingPrompt,
      syncIntervalSeconds: syncIntervalSeconds
    )
  }
}
