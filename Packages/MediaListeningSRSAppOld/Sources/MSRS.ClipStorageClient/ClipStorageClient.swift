import Foundation

public struct ClipStorageClient: Sendable {

  public enum Upload {
    public struct Request: Sendable {
      public let localFileURL: URL
      public let remotePath: String
      public init(localFileURL: URL, remotePath: String) {
        self.localFileURL = localFileURL
        self.remotePath = remotePath
      }
    }
    public struct Response: Sendable, Equatable {
      public init() {}
    }
  }

  public enum Download {
    public struct Request: Sendable {
      public let remotePath: String
      public let localFileURL: URL
      public init(remotePath: String, localFileURL: URL) {
        self.remotePath = remotePath
        self.localFileURL = localFileURL
      }
    }
    public struct Response: Sendable, Equatable {
      public init() {}
    }
  }

  public var upload: @Sendable (Upload.Request) async throws -> Upload.Response
  public var download: @Sendable (Download.Request) async throws -> Download.Response

  public init(
    upload: @Sendable @escaping (Upload.Request) async throws -> Upload.Response,
    download: @Sendable @escaping (Download.Request) async throws -> Download.Response
  ) {
    self.upload = upload
    self.download = download
  }
}
