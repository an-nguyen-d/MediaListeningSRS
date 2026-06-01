import Foundation
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_SharedModels

@MainActor
protocol ProcessingQueueInteractorProtocol {
  func sendAction(_ action: ProcessingQueueModels.Action)
}

@MainActor
final class ProcessingQueueInteractor: ProcessingQueueInteractorProtocol {

  let presenter: ProcessingQueuePresenter
  private let mediaSourceID: MediaSourceModel.ID

  private let mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient

  private var observationTask: Task<Void, Never>?
  private var totalCandidateCount: Int = 0

  init(
    presenter: ProcessingQueuePresenter,
    mediaSourceID: MediaSourceModel.ID,
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient
  ) {
    self.presenter = presenter
    self.mediaSourceID = mediaSourceID
    self.mediaListeningSRSDatabaseClient = mediaListeningSRSDatabaseClient
  }

  deinit {
    observationTask?.cancel()
  }

  func sendAction(_ action: ProcessingQueueModels.Action) {
    switch action {
    case .viewDidLoad:
      handleViewDidLoad()
    case .rowTapped(let id):
      presenter.presentNavigateToCandidateDetail(candidateID: id, mediaSourceID: mediaSourceID)
    }
  }

  private func handleViewDidLoad() {
    observationTask?.cancel()
    let mediaSourceID = self.mediaSourceID
    observationTask = Task { [mediaListeningSRSDatabaseClient, presenter] in
      do {
        let totalResponse = try await mediaListeningSRSDatabaseClient.mediaSourceCardCandidate
          .fetchTotalCandidateCountForSource(.init(mediaSourceID: mediaSourceID))
        let totalCount = totalResponse.totalCount

        await MainActor.run {
          self.totalCandidateCount = totalCount
        }

        let stream = try await mediaListeningSRSDatabaseClient.mediaSourceCardCandidate.observeForSource(
          .init(mediaSourceID: mediaSourceID)
        )
        for try await candidates in stream {
          await MainActor.run {
            let rows = candidates.map {
              ProcessingQueueModels.Row(id: $0.id, subtitleIndex: $0.subtitleIndex)
            }
            presenter.presentRows(rows, totalCandidateCount: totalCount)
          }
        }
      } catch {
        await MainActor.run {
          presenter.presentError("Failed to load candidates: \(error.localizedDescription)")
        }
      }
    }
  }
}
