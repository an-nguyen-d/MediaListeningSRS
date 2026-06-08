import Foundation

public actor ClipExportManager {

  public static let shared = ClipExportManager()

  private struct QueueItem: Sendable {
    let finalOutputURL: URL
    let exportRequest: ClipExportService.ExportClip.Request
    let exportClip: @Sendable (ClipExportService.ExportClip.Request) async throws -> ClipExportService.ExportClip.Response
    let onComplete: @Sendable (URL) async -> Void
  }

  private var queue: [QueueItem] = []
  private var isRunning = false
  private var drainContinuations: [CheckedContinuation<Void, Never>] = []

  private var enqueuedCount = 0
  private var completedCount = 0
  private var itemCompletedCallbacks: [@Sendable (Int, Int) async -> Void] = []

  public func enqueue(
    request: ClipExportService.ExportClip.Request,
    exportClip: @Sendable @escaping (ClipExportService.ExportClip.Request) async throws -> ClipExportService.ExportClip.Response,
    onComplete: @Sendable @escaping (URL) async -> Void
  ) {
    enqueuedCount += 1
    let tempOutputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".mp4", isDirectory: false)
    let tempRequest = ClipExportService.ExportClip.Request(
      sourceVideoFileURL: request.sourceVideoFileURL,
      startTimeSeconds: request.startTimeSeconds,
      endTimeSeconds: request.endTimeSeconds,
      outputFileURL: tempOutputURL
    )
    queue.append(QueueItem(
      finalOutputURL: request.outputFileURL,
      exportRequest: tempRequest,
      exportClip: exportClip,
      onComplete: onComplete
    ))
    if !isRunning { startProcessing() }
  }

  public func waitUntilDrained(
    onItemCompleted: (@Sendable (Int, Int) async -> Void)? = nil
  ) async {
    if queue.isEmpty && !isRunning { return }
    if let onItemCompleted {
      itemCompletedCallbacks.append(onItemCompleted)
    }
    await withCheckedContinuation { continuation in
      drainContinuations.append(continuation)
    }
  }

  private func startProcessing() {
    isRunning = true
    Task {
      while !queue.isEmpty {
        let item = queue.removeFirst()
        do {
          _ = try await item.exportClip(item.exportRequest)
          let tempURL = item.exportRequest.outputFileURL
          let finalURL = item.finalOutputURL
          let fm = FileManager.default
          let parentDir = finalURL.deletingLastPathComponent()
          if !fm.fileExists(atPath: parentDir.path) {
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
          }
          try fm.moveItem(at: tempURL, to: finalURL)

          let tempThumb = tempURL.deletingPathExtension().appendingPathExtension("jpg")
          if fm.fileExists(atPath: tempThumb.path) {
            let finalThumb = finalURL.deletingPathExtension().appendingPathExtension("jpg")
            try? fm.moveItem(at: tempThumb, to: finalThumb)
          }

          await item.onComplete(finalURL)
        } catch {
          print("[ClipExportManager] Export failed: \(error)")
          try? FileManager.default.removeItem(at: item.exportRequest.outputFileURL)
        }
        completedCount += 1
        let completed = completedCount
        let total = enqueuedCount
        for callback in itemCompletedCallbacks {
          await callback(completed, total)
        }
      }
      isRunning = false
      enqueuedCount = 0
      completedCount = 0
      itemCompletedCallbacks.removeAll()
      let continuations = drainContinuations
      drainContinuations.removeAll()
      for continuation in continuations {
        continuation.resume()
      }
    }
  }
}
