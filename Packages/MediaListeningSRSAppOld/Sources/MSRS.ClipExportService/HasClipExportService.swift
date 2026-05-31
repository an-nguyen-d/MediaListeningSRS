public protocol HasClipExportService {
  var clipExportService: ClipExportService { get }
}

public extension HasClipExportService {
  var clipExportService: ClipExportService {
    .previewValue()
  }
}
