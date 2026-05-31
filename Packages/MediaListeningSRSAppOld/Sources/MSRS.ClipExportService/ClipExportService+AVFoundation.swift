import Foundation
import AVFoundation

extension ClipExportService {

  /// AVFoundation-backed live implementation. Trims the source video between `startTimeSeconds` and `endTimeSeconds`
  /// and writes to `outputFileURL` as `.mp4`. Audio is preserved from the source.
  ///
  /// HandBrake post-compression (per ANCD's VideoClipExporter) is NOT applied in v1 — clips are roughly cut at source
  /// quality. If size becomes a problem, layer a HandBrake CLI pass behind this same interface as a follow-up.
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

        // Make sure the output directory exists.
        let outputDirectoryURL = request.outputFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        // Remove any pre-existing file at the destination — AVAssetExportSession refuses to overwrite.
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

        let startCMTime = CMTime(
          seconds: request.startTimeSeconds,
          preferredTimescale: 600
        )
        let endCMTime = CMTime(
          seconds: request.endTimeSeconds,
          preferredTimescale: 600
        )
        exportSession.timeRange = CMTimeRange(start: startCMTime, end: endCMTime)
        exportSession.outputURL = request.outputFileURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = false

        try await exportSession.export(to: request.outputFileURL, as: .mp4)

        return .init(exportedFileURL: request.outputFileURL)
      }
    )
  }

}
