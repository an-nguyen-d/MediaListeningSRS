import Foundation
import JML_JMLDatabaseClient
import JML_JMLSharedModels
import MSRS_MediaSourceImportEpisodePickerScene
import MSRS_MediaSourceImportService
import MSRS_SharedModels

public enum MediaSourceImportPickerModels {

  public typealias Dependencies = HasJMLDatabaseClient
                                & HasMediaSourceImportService
                                & MediaSourceImportEpisodePickerModels.Dependencies

  public enum Action {
    case viewDidLoad
    case searchTextChanged(String)
    case rowTapped(Row)
  }

  public struct Row: Sendable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let kind: Kind

    public init(id: String, title: String, subtitle: String?, kind: Kind) {
      self.id = id
      self.title = title
      self.subtitle = subtitle
      self.kind = kind
    }

    public enum Kind: Sendable, Equatable {
      case movie(MediaSourceModel.JMLMediaReference)
      case series(TVShowSeriesModel.ID)
    }
  }

  public enum DisplayState: Sendable, Equatable {
    case loading
    case loaded([Row])
    case failed(String)
  }
}
