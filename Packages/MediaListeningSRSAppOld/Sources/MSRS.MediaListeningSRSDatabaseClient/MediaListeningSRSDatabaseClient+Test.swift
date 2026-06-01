import Foundation
import MSRS_SharedModels

extension MediaListeningSRSDatabaseClient {

  public static func previewValue() -> Self {
    fatalError("MediaListeningSRSDatabaseClient.previewValue() not yet implemented")
  }

}

extension MediaListeningSRSDatabaseClient.StudySession {

  public static func previewValue() -> Self {
    .init(
      createSession: { _ in fatalError() },
      updateSession: { _ in fatalError() },
      fetchMostRecent: { _ in fatalError() },
      fetchInDateRange: { _ in fatalError() }
    )
  }
}

extension MediaListeningSRSDatabaseClient.DailySnapshot {

  public static func previewValue() -> Self {
    .init(
      createIfNeeded: { _ in fatalError() },
      fetchAggregatesInDateRange: { _ in fatalError() },
      fetchCardSnapshotsForDate: { _ in fatalError() }
    )
  }
}
