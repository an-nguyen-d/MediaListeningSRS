public protocol HasMediaListeningSRSDatabaseClient {
  var mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient { get }
}

public extension HasMediaListeningSRSDatabaseClient {
  var mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient {
    .previewValue()
  }
}
