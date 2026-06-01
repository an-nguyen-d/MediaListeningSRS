import Foundation
import JML_JMLDatabaseClient
import JML_JMLSharedModels
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
  private let jmlDatabaseClient: JMLDatabaseClient

  private var observationTask: Task<Void, Never>?
  private var totalCandidateCount: Int = 0

  init(
    presenter: ProcessingQueuePresenter,
    mediaSourceID: MediaSourceModel.ID,
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    jmlDatabaseClient: JMLDatabaseClient
  ) {
    self.presenter = presenter
    self.mediaSourceID = mediaSourceID
    self.mediaListeningSRSDatabaseClient = mediaListeningSRSDatabaseClient
    self.jmlDatabaseClient = jmlDatabaseClient
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
    observationTask = Task { [mediaListeningSRSDatabaseClient, jmlDatabaseClient, presenter] in
      do {
        let sourceResponse = try await mediaListeningSRSDatabaseClient.mediaSource.fetch(
          .init(id: mediaSourceID)
        )
        let title = await Self.resolveTitle(
          for: sourceResponse.model.jmlMediaReference,
          jmlDatabaseClient: jmlDatabaseClient
        )
        await MainActor.run { presenter.presentTitle(title) }

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

  private static func resolveTitle(
    for reference: MediaSourceModel.JMLMediaReference,
    jmlDatabaseClient: JMLDatabaseClient
  ) async -> String {
    switch reference {
    case .movie(let movieID):
      guard let movie = try? await jmlDatabaseClient.movie.fetch(.init(id: movieID)) else {
        return "Movie"
      }
      return movie.titleEnglish
        ?? movie.titleJapaneseRomanized
        ?? movie.titleJapanese
        ?? "Movie"

    case .episode(let episodeID):
      guard let episode = try? await jmlDatabaseClient.tvShowEpisode.fetch(.init(id: episodeID)) else {
        return "Episode"
      }
      let epNumber = episode.indexInSeason + 1
      let epName = episode.titleEnglish ?? episode.titleJapaneseRomanized ?? episode.titleJapanese

      guard let season = try? await jmlDatabaseClient.tvShowSeason.fetch(.init(id: episode.seasonID)) else {
        if let epName { return "E\(epNumber) – \(epName)" }
        return "Episode \(epNumber)"
      }
      let seasonNumber = season.indexInSeries + 1

      guard let series = try? await jmlDatabaseClient.tvShowSeries.fetch(.init(id: season.seriesID)) else {
        if let epName { return "S\(seasonNumber)E\(epNumber) – \(epName)" }
        return "S\(seasonNumber)E\(epNumber)"
      }
      let seriesName = series.titleEnglish ?? series.titleJapaneseRomanized ?? series.titleJapanese ?? "Series"

      if let epName {
        return "\(seriesName) S\(seasonNumber)E\(epNumber) – \(epName)"
      }
      return "\(seriesName) S\(seasonNumber)E\(epNumber)"
    }
  }
}
