import Foundation
import MSRS_SharedModels

public struct ClipExportService: Sendable {

  // MARK: - ExportClip

  public enum ExportClip {
    public struct Request: Sendable {
      public let sourceVideoFileURL: URL
      public let startTimeSeconds: TimeInterval
      public let endTimeSeconds: TimeInterval
      public let outputFileURL: URL

      public init(
        sourceVideoFileURL: URL,
        startTimeSeconds: TimeInterval,
        endTimeSeconds: TimeInterval,
        outputFileURL: URL
      ) {
        self.sourceVideoFileURL = sourceVideoFileURL
        self.startTimeSeconds = startTimeSeconds
        self.endTimeSeconds = endTimeSeconds
        self.outputFileURL = outputFileURL
      }
    }
    public struct Response: Sendable, Equatable {
      public let exportedFileURL: URL
      public init(exportedFileURL: URL) {
        self.exportedFileURL = exportedFileURL
      }
    }
  }

  public var exportClip: @Sendable (ExportClip.Request) async throws -> ExportClip.Response

  public init(
    exportClip: @Sendable @escaping (ExportClip.Request) async throws -> ExportClip.Response
  ) {
    self.exportClip = exportClip
  }
}

public enum ClipExportError: Error, Equatable, Sendable {
  case sourceVideoFileNotFound
  case invalidTimeRange
  case exportSessionCreationFailed
  case exportFailed(message: String)
}
