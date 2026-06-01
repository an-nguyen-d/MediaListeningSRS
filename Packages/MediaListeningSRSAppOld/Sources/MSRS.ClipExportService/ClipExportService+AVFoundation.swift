import Foundation
import AVFoundation

extension ClipExportService {

  public static func avFoundationValue() -> Self {
    .init(
      exportClip: { request in
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: request.sourceVideoFileURL.path) else {
          throw ClipExportError.sourceVideoFileNotFound
        }

        guard request.endTimeSeconds > request.startTimeSeconds else {
          throw ClipExportError.invalidTimeRange
        }

        let outputDirectoryURL = request.outputFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: request.outputFileURL.path) {
          try fileManager.removeItem(at: request.outputFileURL)
        }

        let asset = AVURLAsset(url: request.sourceVideoFileURL)

        guard let exportSession = AVAssetExportSession(
          asset: asset,
          presetName: AVAssetExportPresetHighestQuality
        ) else {
          throw ClipExportError.exportSessionCreationFailed
        }

        let startCMTime = CMTime(seconds: request.startTimeSeconds, preferredTimescale: 600)
        let endCMTime = CMTime(seconds: request.endTimeSeconds, preferredTimescale: 600)
        exportSession.timeRange = CMTimeRange(start: startCMTime, end: endCMTime)
        exportSession.outputURL = request.outputFileURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = false

        try await exportSession.export(to: request.outputFileURL, as: .mp4)

        #if targetEnvironment(macCatalyst)
        try await compressWithFFmpeg(inputURL: request.outputFileURL)
        #endif

        return .init(exportedFileURL: request.outputFileURL)
      }
    )
  }

  #if targetEnvironment(macCatalyst)
  // HEVC 540p, CRF 32, audio passthrough. Replaces the file in-place.
  private static func compressWithFFmpeg(inputURL: URL) async throws {
    let ffmpegPath = "/opt/homebrew/bin/ffmpeg"
    guard FileManager.default.fileExists(atPath: ffmpegPath) else {
      throw ClipExportError.ffmpegNotFound
    }

    let tempURL = inputURL.deletingLastPathComponent()
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("mp4")

    let command = "\(ffmpegPath) -y -i '\(inputURL.path)' -vf scale=-2:540 -c:v libx265 -crf 32 -preset fast -tag:v hvc1 -c:a copy '\(tempURL.path)'"

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      DispatchQueue.global(qos: .userInitiated).async {
        let appleScript = "do shell script \"\(command)\""
        var scriptError: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
          scriptObject.executeAndReturnError(&scriptError)
          if let error = scriptError {
            let message = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown ffmpeg error"
            continuation.resume(throwing: ClipExportError.ffmpegFailed(message: message))
          } else if FileManager.default.fileExists(atPath: tempURL.path) {
            do {
              let fm = FileManager.default
              try fm.removeItem(at: inputURL)
              try fm.moveItem(at: tempURL, to: inputURL)
              continuation.resume()
            } catch {
              continuation.resume(throwing: ClipExportError.ffmpegFailed(message: "Failed to replace original: \(error.localizedDescription)"))
            }
          } else {
            continuation.resume(throwing: ClipExportError.ffmpegFailed(message: "Output file not created"))
          }
        } else {
          continuation.resume(throwing: ClipExportError.ffmpegFailed(message: "Failed to create AppleScript"))
        }
      }
    }
  }
  #endif

}
