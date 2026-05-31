public protocol HasMediaSourceImportService {
  var mediaSourceImportService: MediaSourceImportService { get }
}

public extension HasMediaSourceImportService {
  var mediaSourceImportService: MediaSourceImportService {
    .previewValue()
  }
}
