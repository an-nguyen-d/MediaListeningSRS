import Foundation
import FirebaseStorage

extension ClipStorageClient {

  public static func firebaseValue() -> Self {
    .init(
      upload: { request in
        let storageRef = Storage.storage().reference(withPath: request.remotePath)
        return try await withCheckedThrowingContinuation { continuation in
          storageRef.putFile(from: request.localFileURL, metadata: nil) { _, error in
            if let error {
              continuation.resume(throwing: error)
            } else {
              continuation.resume(returning: .init())
            }
          }
        }
      },
      download: { request in
        let storageRef = Storage.storage().reference(withPath: request.remotePath)
        let outputDir = request.localFileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        return try await withCheckedThrowingContinuation { continuation in
          storageRef.write(toFile: request.localFileURL) { _, error in
            if let error {
              continuation.resume(throwing: error)
            } else {
              continuation.resume(returning: .init())
            }
          }
        }
      }
    )
  }
}
