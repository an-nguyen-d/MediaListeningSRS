import Foundation
import MSRS_ClipStorageClient

#if targetEnvironment(macCatalyst)
enum ClipUploadBackfillService {

  private static let userDefaultsKey = "MSRS.ClipUploadBackfill.completed"

  static func backfillIfNeeded(
    clipStorageClient: ClipStorageClient,
    exportedClipsDirectoryURL: URL
  ) async {
    guard !UserDefaults.standard.bool(forKey: userDefaultsKey) else { return }

    let mp4Files = collectMP4Files(under: exportedClipsDirectoryURL)

    guard !mp4Files.isEmpty else {
      UserDefaults.standard.set(true, forKey: userDefaultsKey)
      return
    }

    print("[ClipUploadBackfill] Found \(mp4Files.count) clips to upload")

    for fileURL in mp4Files {
      let relativePath = fileURL.path.replacingOccurrences(
        of: exportedClipsDirectoryURL.path,
        with: ""
      ).trimmingCharacters(in: CharacterSet(charactersIn: "/"))

      let remotePath = "clips/\(relativePath)"
      do {
        _ = try await clipStorageClient.upload(.init(
          localFileURL: fileURL,
          remotePath: remotePath
        ))
        print("[ClipUploadBackfill] Uploaded \(remotePath)")
      } catch {
        print("[ClipUploadBackfill] Failed \(remotePath): \(error)")
      }

      let thumbnailURL = fileURL.deletingPathExtension().appendingPathExtension("jpg")
      if FileManager.default.fileExists(atPath: thumbnailURL.path) {
        let thumbRemotePath = "clips/\(relativePath.replacingOccurrences(of: ".mp4", with: ".jpg"))"
        do {
          _ = try await clipStorageClient.upload(.init(
            localFileURL: thumbnailURL,
            remotePath: thumbRemotePath
          ))
          print("[ClipUploadBackfill] Uploaded thumbnail \(thumbRemotePath)")
        } catch {
          print("[ClipUploadBackfill] Thumbnail failed \(thumbRemotePath): \(error)")
        }
      }
    }

    UserDefaults.standard.set(true, forKey: userDefaultsKey)
    print("[ClipUploadBackfill] Backfill complete")
  }

  private static func collectMP4Files(under directory: URL) -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
      at: directory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }
    var result: [URL] = []
    for case let fileURL as URL in enumerator {
      if fileURL.pathExtension == "mp4" {
        result.append(fileURL)
      }
    }
    return result
  }
}
#endif
