import Foundation
import IYO_DictionaryClient
import IYO_DictionaryModels
import MSRS_MediaListeningSRSDatabaseClient

@MainActor
final class WordsListInteractor {

  let presenter: WordsListPresenter

  private let dictionaryClient: DictionaryClient
  private let mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient

  private static let pageSize = 100

  private var allLoadedResults: [DictionaryLookupResult] = []
  private var fullyKnownTermIDs: Set<Int64> = []
  private var learnedScoresByTermID: [Int64: Double] = [:]
  private var coverageCountsByTermID: [Int64: Int] = [:]
  private var currentOffset = 0
  private var hasMorePages = true
  private var isLoading = false
  private var activeSortField: WordsListModels.SortField = .frequencyRank
  private var activeFullyKnownFilter: WordsListModels.FullyKnownFilter = .all
  private var searchQuery: String = ""
  private var searchDebounceTask: Task<Void, Never>?

  init(
    presenter: WordsListPresenter,
    dictionaryClient: DictionaryClient,
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient
  ) {
    self.presenter = presenter
    self.dictionaryClient = dictionaryClient
    self.mediaListeningSRSDatabaseClient = mediaListeningSRSDatabaseClient
  }

  func sendAction(_ action: WordsListModels.Action) {
    switch action {
    case .viewDidLoad:
      loadPage()
    case .loadNextPage:
      loadPage()
    case .sortChanged(let field):
      activeSortField = field
      resetAndReload()
    case .fullyKnownFilterChanged(let filter):
      activeFullyKnownFilter = filter
      emitViewModel()
    case .searchQueryChanged(let query):
      searchDebounceTask?.cancel()
      searchDebounceTask = Task { @MainActor [weak self] in
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled, let self = self else { return }
        self.searchQuery = query
        self.resetAndReload()
      }
    case .markTermAsFullyKnown(let termID):
      handleMarkTermAsFullyKnown(termID)
    }
  }

  private func resetAndReload() {
    allLoadedResults = []
    fullyKnownTermIDs = []
    learnedScoresByTermID = [:]
    coverageCountsByTermID = [:]
    currentOffset = 0
    hasMorePages = true
    loadPage()
  }

  private func loadPage() {
    guard !isLoading, hasMorePages else { return }
    isLoading = true
    emitViewModel()

    let offset = currentOffset
    let limit = Self.pageSize
    let query = searchQuery

    Task { [dictionaryClient, mediaListeningSRSDatabaseClient] in
      do {
        let results: [DictionaryLookupResult]
        if !query.isEmpty {
          results = try await dictionaryClient.search(.init(
            query: query,
            searchSpelling: true,
            searchMeaning: true,
            limit: limit,
            offset: offset
          ))
        } else {
          results = try await dictionaryClient.lookupByFrequencyPaginated(.init(
            limit: limit,
            offset: offset,
            order: .ascending
          ))
        }

        let termIDs = results.map { $0.termID.rawValue }

        let knownResponse = try await mediaListeningSRSDatabaseClient.japaneseTerm
          .fetchFullyKnownTermIDs(.init(japaneseTermIDs: termIDs))

        let learnedResponse = try await mediaListeningSRSDatabaseClient.japaneseTerm
          .fetchLearnedScoresForTermIDs(.init(japaneseTermIDs: termIDs))

        let coverageResponse = try await mediaListeningSRSDatabaseClient.japaneseTerm
          .fetchCoverageCountsForTermIDs(.init(japaneseTermIDs: termIDs))

        await MainActor.run {
          self.allLoadedResults.append(contentsOf: results)
          self.fullyKnownTermIDs.formUnion(knownResponse.fullyKnownTermIDs)
          self.learnedScoresByTermID.merge(learnedResponse.scoresByTermID) { _, new in new }
          self.coverageCountsByTermID.merge(coverageResponse.coverageCountsByTermID) { _, new in new }
          self.currentOffset += results.count
          self.hasMorePages = results.count >= Self.pageSize
          self.isLoading = false
          self.emitViewModel()
        }
      } catch {
        await MainActor.run {
          self.isLoading = false
          self.emitViewModel()
          self.presenter.presentError("Failed to load words: \(error.localizedDescription)")
        }
      }
    }
  }

  private func handleMarkTermAsFullyKnown(_ termID: Int64) {
    Task { [mediaListeningSRSDatabaseClient] in
      do {
        _ = try await mediaListeningSRSDatabaseClient.japaneseTerm.markAsFullyKnown(
          .init(japaneseTermID: termID)
        )
        await MainActor.run {
          self.fullyKnownTermIDs.insert(termID)
          self.learnedScoresByTermID[termID] = 1.0
          self.emitViewModel()
        }
      } catch {
        await MainActor.run {
          self.presenter.presentError("Mark fully known failed: \(error.localizedDescription)")
        }
      }
    }
  }

  private func emitViewModel() {
    var rows = allLoadedResults.map { result -> WordsListModels.WordRow in
      let termID = result.termID.rawValue
      let primarySpelling = result.spellings
        .filter { $0.isKanjiSpelling }
        .min(by: { $0.spellingRank < $1.spellingRank })?
        .spelling
        ?? result.spellings.first?.spelling
        ?? "?"

      let reading = result.spellings
        .filter { $0.isKanaSpelling }
        .min(by: { $0.spellingRank < $1.spellingRank })?
        .spelling
        ?? ""

      let definitionSummary = result.senses.first?.meaning ?? ""

      return .init(
        position: 0,
        termID: termID,
        frequencyRank: result.frequencyRank,
        primarySpelling: primarySpelling,
        reading: reading,
        definitionSummary: definitionSummary,
        isFullyKnown: fullyKnownTermIDs.contains(termID),
        learnedScore: learnedScoresByTermID[termID] ?? 0,
        cardCoverageCount: coverageCountsByTermID[termID] ?? 0
      )
    }

    switch activeFullyKnownFilter {
    case .all: break
    case .fullyKnownOnly: rows = rows.filter { $0.isFullyKnown }
    case .notFullyKnown: rows = rows.filter { !$0.isFullyKnown }
    }

    switch activeSortField {
    case .frequencyRank:
      break
    case .mostKnown:
      rows.sort { lhs, rhs in
        if lhs.isFullyKnown != rhs.isFullyKnown { return lhs.isFullyKnown }
        let lhsScore = lhs.isFullyKnown ? 2.0 : lhs.learnedScore
        let rhsScore = rhs.isFullyKnown ? 2.0 : rhs.learnedScore
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        return (lhs.frequencyRank ?? Int.max) < (rhs.frequencyRank ?? Int.max)
      }
    }

    rows = rows.enumerated().map { index, row in
      .init(
        position: index + 1,
        termID: row.termID,
        frequencyRank: row.frequencyRank,
        primarySpelling: row.primarySpelling,
        reading: row.reading,
        definitionSummary: row.definitionSummary,
        isFullyKnown: row.isFullyKnown,
        learnedScore: row.learnedScore,
        cardCoverageCount: row.cardCoverageCount
      )
    }

    presenter.presentViewModel(.init(
      rows: rows,
      isLoadingMore: isLoading,
      hasMorePages: hasMorePages,
      totalLoaded: allLoadedResults.count,
      activeSortField: activeSortField,
      activeFullyKnownFilter: activeFullyKnownFilter,
      searchQuery: searchQuery
    ))
  }
}
