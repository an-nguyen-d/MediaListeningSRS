import Foundation

public actor ClipExportManager {

  public static let shared = ClipExportManager()

  private struct QueueItem: Sendable {
    let request: ClipExportService.ExportClip.Request
    let exportClip: @Sendable (ClipExportService.ExportClip.Request) async throws -> ClipExportService.ExportClip.Response
    let onComplete: @Sendable (URL) async -> Void
  }

  private var queue: [QueueItem] = []
  private var isRunning = false

  public func enqueue(
    request: ClipExportService.ExportClip.Request,
    exportClip: @Sendable @escaping (ClipExportService.ExportClip.Request) async throws -> ClipExportService.ExportClip.Response,
    onComplete: @Sendable @escaping (URL) async -> Void
  ) {
    queue.append(QueueItem(request: request, exportClip: exportClip, onComplete: onComplete))
    if !isRunning { startProcessing() }
  }

  private func startProcessing() {
    isRunning = true
    Task {
      while !queue.isEmpty {
        let item = queue.removeFirst()
        do {
          let response = try await item.exportClip(item.request)
          await item.onComplete(response.exportedFileURL)
        } catch {
          print("[ClipExportManager] Export failed: \(error)")
        }
      }
      isRunning = false
    }
  }
}
