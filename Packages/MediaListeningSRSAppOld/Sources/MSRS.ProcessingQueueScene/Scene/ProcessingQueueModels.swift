import Foundation
import ElixirShared
import JML_JMLDatabaseClient
import METG_METGDatabaseClient
import IYO_DictionaryClient
import MSRS_CandidateDetailScene
import MSRS_ClipExportService
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_SharedModels

public enum ProcessingQueueModels {

  public typealias Dependencies = HasClipExportService
                                & HasExportedClipsDirectoryURL
                                & HasJMLDatabaseClient
                                & HasMediaListeningSRSDatabaseClient
                                & HasSRTParserClient
                                & CandidateDetailModels.Dependencies

  public enum Action {
    case viewDidLoad
    case rowTapped(MediaSourceCardCandidateModel.ID)
  }

  public struct Row: Sendable, Equatable {
    public let id: MediaSourceCardCandidateModel.ID
    public let subtitleIndex: Int

    public init(id: MediaSourceCardCandidateModel.ID, subtitleIndex: Int) {
      self.id = id
      self.subtitleIndex = subtitleIndex
    }
  }
}
