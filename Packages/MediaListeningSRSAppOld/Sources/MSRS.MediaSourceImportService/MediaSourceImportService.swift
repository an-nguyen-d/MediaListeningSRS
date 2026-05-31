import Foundation
import MSRS_SharedModels

public struct MediaSourceImportService: Sendable {

  // MARK: - Import

  public enum Import {
    public struct Request: Sendable {
      public let jmlMediaReference: MediaSourceModel.JMLMediaReference
      public init(jmlMediaReference: MediaSourceModel.JMLMediaReference) {
        self.jmlMediaReference = jmlMediaReference
      }
    }
    public struct Response: Sendable, Equatable {
      public let createdMediaSource: MediaSourceModel
      public let createdCandidates: [MediaSourceCardCandidateModel]
      public init(
        createdMediaSource: MediaSourceModel,
        createdCandidates: [MediaSourceCardCandidateModel]
      ) {
        self.createdMediaSource = createdMediaSource
        self.createdCandidates = createdCandidates
      }
    }
  }

  public var `import`: @Sendable (Import.Request) async throws -> Import.Response

  public init(
    import importClosure: @Sendable @escaping (Import.Request) async throws -> Import.Response
  ) {
    self.import = importClosure
  }
}

public enum MediaSourceImportError: Error, Equatable, Sendable {
  /// The chosen JML movie or episode could not be found in JML's database.
  case jmlMediaNotFound
  /// The JML media exists but has no `japaneseSubtitleFile` configured.
  case jmlMediaHasNoJapaneseSubtitleFile
  /// MWBT has no `mediaSubtitleRecord` for this Japanese subtitle file — the user hasn't tagged it yet.
  case mediaNotTaggedInMWBT
  /// MWBT has the subtitle record but every tagged subtitle index is disabled (or there are no tagged indexes).
  case noTaggedNonDisabledSegments
}
