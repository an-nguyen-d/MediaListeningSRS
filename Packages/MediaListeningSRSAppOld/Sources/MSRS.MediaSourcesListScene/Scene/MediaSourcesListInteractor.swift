import Foundation
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_SharedModels

@MainActor
protocol MediaSourcesListInteractorProtocol {
  func sendAction(_ action: MediaSourcesListModels.Action)
}

@MainActor
final class MediaSourcesListInteractor: MediaSourcesListInteractorProtocol {

  let presenter: MediaSourcesListPresenter
  private let mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient

  private var observationTask: Task<Void, Never>?

  init(
    presenter: MediaSourcesListPresenter,
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient
  ) {
    self.presenter = presenter
    self.mediaListeningSRSDatabaseClient = mediaListeningSRSDatabaseClient
  }

  deinit {
    observationTask?.cancel()
  }

  func sendAction(_ action: MediaSourcesListModels.Action) {
    switch action {
    case .viewDidLoad:
      handleViewDidLoad()
    case .addTapped:
      presenter.presentNavigateToImportPicker()
    case .reviewAllTapped:
      presenter.presentNavigateToReviewAll()
    case .rowTapped(let id):
      presenter.presentNavigateToProcessingQueue(mediaSourceID: id)
    }
  }

  private func handleViewDidLoad() {
    observationTask?.cancel()
    observationTask = Task { [mediaListeningSRSDatabaseClient, presenter] in
      do {
        let stream = try await mediaListeningSRSDatabaseClient.mediaSource.observeAll(.init())
        for try await sources in stream {
          let rows = sources.map { source -> MediaSourcesListModels.Row in
            let referenceLabel: String
            switch source.jmlMediaReference {
            case .movie(let id): referenceLabel = "Movie #\(id.rawValue)"
            case .episode(let id): referenceLabel = "Episode #\(id.rawValue)"
            }
            return .init(
              id: source.id,
              title: referenceLabel,
              subtitle: "Imported \(Self.shortDateFormatter.string(from: source.createdAt))"
            )
          }
          await MainActor.run { presenter.presentRows(rows) }
        }
      } catch {
        await MainActor.run {
          presenter.presentError("Failed to load sources: \(error.localizedDescription)")
        }
      }
    }
  }

  private static let shortDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
  }()
}
