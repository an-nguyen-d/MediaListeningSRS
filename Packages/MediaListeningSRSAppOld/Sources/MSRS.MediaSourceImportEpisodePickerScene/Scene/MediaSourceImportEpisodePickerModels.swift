import Foundation
import JML_JMLDatabaseClient
import JML_JMLSharedModels
import METG_METGDatabaseClient
import MSRS_MediaSourceImportService
import MSRS_SharedModels

public enum MediaSourceImportEpisodePickerModels {

  public typealias Dependencies = HasJMLDatabaseClient & HasMETGDatabaseClient & HasMediaSourceImportService

  public enum Action {
    case viewDidLoad
    case searchTextChanged(String)
    case episodeTapped(MediaSourceModel.JMLMediaReference)
  }

  public struct Section: Sendable, Equatable {
    public let id: String
    public let title: String
    public let rows: [Row]

    public init(id: String, title: String, rows: [Row]) {
      self.id = id
      self.title = title
      self.rows = rows
    }
  }

  public struct Row: Sendable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let mediaReference: MediaSourceModel.JMLMediaReference

    public init(
      id: String,
      title: String,
      subtitle: String?,
      mediaReference: MediaSourceModel.JMLMediaReference
    ) {
      self.id = id
      self.title = title
      self.subtitle = subtitle
      self.mediaReference = mediaReference
    }
  }

  public enum DisplayState: Sendable, Equatable {
    case loading
    case loaded([Section])
    case failed(String)
  }
}
