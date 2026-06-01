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
