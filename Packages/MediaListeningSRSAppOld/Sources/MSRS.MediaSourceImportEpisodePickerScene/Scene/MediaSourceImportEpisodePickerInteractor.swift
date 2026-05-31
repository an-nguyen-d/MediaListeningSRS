import Foundation
import JML_JMLDatabaseClient
import JML_JMLSharedModels
import METG_METGDatabaseClient
import MSRS_MediaSourceImportService
import MSRS_SharedModels

@MainActor
protocol MediaSourceImportEpisodePickerInteractorProtocol {
  func sendAction(_ action: MediaSourceImportEpisodePickerModels.Action)
}

@MainActor
final class MediaSourceImportEpisodePickerInteractor: MediaSourceImportEpisodePickerInteractorProtocol {

  let presenter: MediaSourceImportEpisodePickerPresenter
  private let seriesID: TVShowSeriesModel.ID
  private let jmlDatabaseClient: JMLDatabaseClient
  private let metgDatabaseClient: METGDatabaseClient
  private let mediaSourceImportService: MediaSourceImportService

  private var allSections: [MediaSourceImportEpisodePickerModels.Section] = []
  private var searchText: String = ""

  init(
    presenter: MediaSourceImportEpisodePickerPresenter,
    seriesID: TVShowSeriesModel.ID,
    jmlDatabaseClient: JMLDatabaseClient,
    metgDatabaseClient: METGDatabaseClient,
    mediaSourceImportService: MediaSourceImportService
  ) {
    self.presenter = presenter
    self.seriesID = seriesID
    self.jmlDatabaseClient = jmlDatabaseClient
    self.metgDatabaseClient = metgDatabaseClient
    self.mediaSourceImportService = mediaSourceImportService
  }

  func sendAction(_ action: MediaSourceImportEpisodePickerModels.Action) {
    switch action {
    case .viewDidLoad:
      handleViewDidLoad()
    case .searchTextChanged(let text):
      searchText = text
      presenter.presentState(.loaded(filteredSections()))
    case .episodeTapped(let ref):
      handleEpisodeTapped(ref)
    }
  }

  private func handleViewDidLoad() {
    presenter.presentState(.loading)
    let seriesID = self.seriesID
    Task { [jmlDatabaseClient, metgDatabaseClient, presenter] in
      do {
        let item = try await jmlDatabaseClient.tvShowSeries.fetchWithSeasons(
          .init(seriesID: seriesID, hierarchyLevel: .withEpisodes)
        )

        let allEpisodeFileIDs = item.seasons
          .flatMap(\.episodes)
          .compactMap(\.japaneseSubtitleFile?.id)
        let readyFileIDs = try await Self.fetchReadyFileIDs(
          fileIDs: allEpisodeFileIDs,
          metgDatabaseClient: metgDatabaseClient
        )

        let sections = Self.buildSections(from: item, readyFileIDs: readyFileIDs)
        await MainActor.run {
          self.allSections = sections
          presenter.presentState(.loaded(self.filteredSections()))
        }
      } catch {
        await MainActor.run {
          presenter.presentState(.failed("Failed to load episodes: \(error.localizedDescription)"))
        }
      }
    }
  }

  private func handleEpisodeTapped(_ ref: MediaSourceModel.JMLMediaReference) {
    Task { [mediaSourceImportService, presenter] in
      do {
        let response = try await mediaSourceImportService.import(
          .init(jmlMediaReference: ref)
        )
        await MainActor.run {
          presenter.presentImportSucceeded(
            createdSourceID: response.createdMediaSource.id,
            candidateCount: response.createdCandidates.count
          )
        }
      } catch {
        await MainActor.run {
          presenter.presentImportError("Import failed: \(error)")
        }
      }
    }
  }

  private func filteredSections() -> [MediaSourceImportEpisodePickerModels.Section] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !query.isEmpty else { return allSections }
    return allSections.compactMap { section in
      let filteredRows = section.rows.filter { row in
        row.title.lowercased().contains(query) ||
        (row.subtitle?.lowercased().contains(query) ?? false)
      }
      return filteredRows.isEmpty
        ? nil
        : .init(id: section.id, title: section.title, rows: filteredRows)
    }
  }

  private static func buildSections(
    from item: TVShowListItemModel,
    readyFileIDs: Set<Int64>
  ) -> [MediaSourceImportEpisodePickerModels.Section] {
    var sections: [MediaSourceImportEpisodePickerModels.Section] = []
    for season in item.seasons {
      let seasonNumber = season.indexInSeries + 1
      let seasonTitle = season.titleJapaneseRomanized.map { "Season \(seasonNumber) — \($0)" }
        ?? "Season \(seasonNumber)"

      let rows = season.episodes.compactMap { episode -> MediaSourceImportEpisodePickerModels.Row? in
        guard let fileID = episode.japaneseSubtitleFile?.id,
              readyFileIDs.contains(fileID.rawValue) else {
          return nil
        }
        let episodeNumber = episode.indexInSeason + 1
        let title = episode.titleEnglish
          ?? episode.titleJapaneseRomanized
          ?? episode.titleJapanese
          ?? "Episode \(episodeNumber)"
        return .init(
          id: "episode-\(episode.id.rawValue)",
          title: "E\(episodeNumber) — \(title)",
          subtitle: nil,
          mediaReference: .episode(episode.id)
        )
      }
      if !rows.isEmpty {
        sections.append(.init(id: "season-\(season.id.rawValue)", title: seasonTitle, rows: rows))
      }
    }
    return sections
  }

  private static func fetchReadyFileIDs(
    fileIDs: [LocalizedLocalFileModel.ID],
    metgDatabaseClient: METGDatabaseClient
  ) async throws -> Set<Int64> {
    guard !fileIDs.isEmpty else { return [] }
    let response = try await metgDatabaseClient.mediaSubtitlesList.fetchByFileIDs(
      .init(fileIDs: fileIDs)
    )
    var readyIDs = Set<Int64>()
    for row in response.subtitles {
      if row.subtitle.hasFinishedLabelling && row.subtitle.hasCheckedSubtitleTimings {
        readyIDs.insert(row.subtitle.localizedLocalFileId)
      }
    }
    return readyIDs
  }
}
