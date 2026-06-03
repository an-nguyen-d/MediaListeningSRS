import Foundation
import JML_JMLDatabaseClient
import JML_JMLSharedModels
#if targetEnvironment(macCatalyst)
import METG_METGDatabaseClient
#endif
import MSRS_MediaSourceImportService
import MSRS_SharedModels

@MainActor
protocol MediaSourceImportPickerInteractorProtocol {
  func sendAction(_ action: MediaSourceImportPickerModels.Action)
}

@MainActor
final class MediaSourceImportPickerInteractor: MediaSourceImportPickerInteractorProtocol {

  let presenter: MediaSourceImportPickerPresenter
  private let jmlDatabaseClient: JMLDatabaseClient
  #if targetEnvironment(macCatalyst)
  private let metgDatabaseClient: METGDatabaseClient
  #endif
  private let mediaSourceImportService: MediaSourceImportService

  private var allRows: [MediaSourceImportPickerModels.Row] = []
  private var searchText: String = ""

  #if targetEnvironment(macCatalyst)
  init(
    presenter: MediaSourceImportPickerPresenter,
    jmlDatabaseClient: JMLDatabaseClient,
    metgDatabaseClient: METGDatabaseClient,
    mediaSourceImportService: MediaSourceImportService
  ) {
    self.presenter = presenter
    self.jmlDatabaseClient = jmlDatabaseClient
    self.metgDatabaseClient = metgDatabaseClient
    self.mediaSourceImportService = mediaSourceImportService
  }
  #else
  init(
    presenter: MediaSourceImportPickerPresenter,
    jmlDatabaseClient: JMLDatabaseClient,
    mediaSourceImportService: MediaSourceImportService
  ) {
    self.presenter = presenter
    self.jmlDatabaseClient = jmlDatabaseClient
    self.mediaSourceImportService = mediaSourceImportService
  }
  #endif

  func sendAction(_ action: MediaSourceImportPickerModels.Action) {
    switch action {
    case .viewDidLoad:
      handleViewDidLoad()
    case .searchTextChanged(let text):
      searchText = text
      presenter.presentState(.loaded(filteredRows()))
    case .rowTapped(let row):
      handleRowTapped(row)
    }
  }

  // MARK: - viewDidLoad

  private func handleViewDidLoad() {
    presenter.presentState(.loading)
    Task { [jmlDatabaseClient, presenter] in
      do {
        #if targetEnvironment(macCatalyst)
        let allSubtitles = try await metgDatabaseClient.mediaSubtitles.fetchAll(.init())

        let readyFileIDs: [LocalizedLocalFileModel.ID] = allSubtitles.subtitles
          .filter { $0.hasFinishedLabelling && $0.hasCheckedSubtitleTimings }
          .map { LocalizedLocalFileModel.ID($0.localizedLocalFileId) }
        #else
        let readyFileIDs: [LocalizedLocalFileModel.ID] = []
        #endif

        guard !readyFileIDs.isEmpty else {
          await MainActor.run {
            self.allRows = []
            presenter.presentState(.loaded([]))
          }
          return
        }

        let rootAndItems = try await jmlDatabaseClient.rootAndMediaItems
          .fetchWithLocalizedLocalFileIDs(.init(fileIDs: readyFileIDs))

        let rows = Self.buildRows(rootAndItems: rootAndItems)
        await MainActor.run {
          self.allRows = rows
          presenter.presentState(.loaded(self.filteredRows()))
        }
      } catch {
        await MainActor.run {
          presenter.presentState(.failed("Failed to load JML media: \(error.localizedDescription)"))
        }
      }
    }
  }

  // MARK: - Row tap

  private func handleRowTapped(_ row: MediaSourceImportPickerModels.Row) {
    switch row.kind {
    case .movie(let reference):
      handleMovieTapped(reference)
    case .series(let seriesID):
      let title = row.title
      presenter.presentNavigateToEpisodePicker(seriesID: seriesID, seriesTitle: title)
    }
  }

  private func handleMovieTapped(_ reference: MediaSourceModel.JMLMediaReference) {
    Task { [mediaSourceImportService, presenter] in
      do {
        let response = try await mediaSourceImportService.import(
          .init(jmlMediaReference: reference)
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

  // MARK: - Filtering

  private func filteredRows() -> [MediaSourceImportPickerModels.Row] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !query.isEmpty else { return allRows }
    return allRows.filter { row in
      row.title.lowercased().contains(query) ||
      (row.subtitle?.lowercased().contains(query) ?? false)
    }
  }

  // MARK: - Row building

  private static func buildRows(
    rootAndItems: JMLDatabaseClient.RootAndMediaItems.FetchWithLocalizedLocalFileIDs.Response
  ) -> [MediaSourceImportPickerModels.Row] {
    var episodeCountBySeriesID: [TVShowSeriesModel.ID: Int] = [:]
    var movieIDs: Set<MovieModel.ID> = []

    for (_, item) in rootAndItems.fileIDToMediaItem {
      switch item.rootMediaID {
      case .series(let seriesID):
        episodeCountBySeriesID[seriesID, default: 0] += 1
      case .movie(let movieID):
        movieIDs.insert(movieID)
      }
    }

    var rows: [MediaSourceImportPickerModels.Row] = []

    for (seriesID, readyEpisodeCount) in episodeCountBySeriesID {
      guard let root = rootAndItems.rootsByID[.series(seriesID)] else { continue }
      let subtitle = "Series · \(readyEpisodeCount) episode\(readyEpisodeCount == 1 ? "" : "s") ready"
      rows.append(.init(
        id: "series-\(seriesID.rawValue)",
        title: root.title,
        subtitle: subtitle,
        kind: .series(seriesID)
      ))
    }

    for movieID in movieIDs {
      guard let root = rootAndItems.rootsByID[.movie(movieID)] else { continue }
      rows.append(.init(
        id: "movie-\(movieID.rawValue)",
        title: root.title,
        subtitle: "Movie",
        kind: .movie(.movie(movieID))
      ))
    }

    rows.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    return rows
  }
}
