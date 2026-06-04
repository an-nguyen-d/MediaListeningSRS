import Foundation
import JML_JMLDatabaseClient
import JML_JMLSharedModels
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
  private let jmlDatabaseClient: JMLDatabaseClient

  private var observationTask: Task<Void, Never>?

  init(
    presenter: MediaSourcesListPresenter,
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    jmlDatabaseClient: JMLDatabaseClient
  ) {
    self.presenter = presenter
    self.mediaListeningSRSDatabaseClient = mediaListeningSRSDatabaseClient
    self.jmlDatabaseClient = jmlDatabaseClient
  }

  deinit {
    observationTask?.cancel()
  }

  func sendAction(_ action: MediaSourcesListModels.Action) {
    switch action {
    case .viewDidLoad:
      handleViewDidLoad()
      refreshDueCardCount()
    case .viewWillAppear:
      refreshDueCardCount()
    case .addTapped:
      presenter.presentNavigateToImportPicker()
    case .reviewAllTapped:
      presenter.presentNavigateToReviewAll()
    case .rowTapped(let id):
      presenter.presentNavigateToProcessingQueue(mediaSourceID: id)
    }
  }

  private func refreshDueCardCount() {
    Task { [mediaListeningSRSDatabaseClient, presenter] in
      let response = try? await mediaListeningSRSDatabaseClient.srsCard.countDueCards(
        .init(asOf: Date())
      )
      let count = response?.count ?? 0
      await MainActor.run { presenter.presentDueCardCount(count) }
    }
  }

  private func handleViewDidLoad() {
    observationTask?.cancel()
    observationTask = Task { [mediaListeningSRSDatabaseClient, jmlDatabaseClient, presenter] in
      do {
        let stream = try await mediaListeningSRSDatabaseClient.mediaSource.observeAll(.init())
        for try await sources in stream {
          var rows: [MediaSourcesListModels.Row] = []
          for source in sources {
            let title = await Self.resolveTitle(
              for: source.jmlMediaReference,
              jmlDatabaseClient: jmlDatabaseClient
            )

            let totalResponse = try await mediaListeningSRSDatabaseClient.mediaSourceCardCandidate
              .fetchTotalCandidateCountForSource(.init(mediaSourceID: source.id))
            let total = totalResponse.totalCount

            var remaining = 0
            let candidateStream = try await mediaListeningSRSDatabaseClient.mediaSourceCardCandidate
              .observeForSource(.init(mediaSourceID: source.id))
            for try await candidates in candidateStream {
              remaining = candidates.count
              break
            }

            let processed = total - remaining
            let subtitle: String
            if total > 0 {
              let pct = Int(round(Double(processed) / Double(total) * 100))
              subtitle = "\(processed)/\(total)  \(pct)%"
            } else {
              subtitle = "No candidates"
            }

            rows.append(.init(id: source.id, title: title, subtitle: subtitle))
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
