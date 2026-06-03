import Foundation
import IYO_JapaneseParserClient
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_MediaSourceImportPickerScene
import MSRS_ProcessingQueueScene
import MSRS_SharedModels
import MSRS_SRSCardReviewScene
import SYNC_ElixirSyncClient

public enum MediaSourcesListModels {

  public typealias Dependencies = HasMediaListeningSRSDatabaseClient
                                & HasElixirSyncClient
                                & MediaSourceImportPickerModels.Dependencies
                                & ProcessingQueueModels.Dependencies
                                & SRSCardReviewModels.Dependencies

  public enum Action {
    case viewDidLoad
    case addTapped
    case reviewAllTapped
    case rowTapped(MediaSourceModel.ID)
  }

  public struct Row: Sendable, Equatable {
    public let id: MediaSourceModel.ID
    public let title: String
    public let subtitle: String?

    public init(id: MediaSourceModel.ID, title: String, subtitle: String?) {
      self.id = id
      self.title = title
      self.subtitle = subtitle
    }
  }
}
