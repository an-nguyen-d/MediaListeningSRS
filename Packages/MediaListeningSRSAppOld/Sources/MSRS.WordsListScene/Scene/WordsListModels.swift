import Foundation
import IYO_DictionaryClient
import MSRS_MediaListeningSRSDatabaseClient

public enum WordsListModels {

  public typealias Dependencies = HasDictionaryClient & HasMediaListeningSRSDatabaseClient

  public enum SortField: String, CaseIterable, Sendable {
    case frequencyRank = "Frequency"
    case mostKnown = "Most Known"
  }

  public enum FullyKnownFilter: String, CaseIterable, Sendable {
    case all = "All"
    case fullyKnownOnly = "Fully Known"
    case notFullyKnown = "Not Fully Known"
  }

  public enum Action {
    case viewDidLoad
    case loadNextPage
    case sortChanged(SortField)
    case fullyKnownFilterChanged(FullyKnownFilter)
    case searchQueryChanged(String)
    case markTermAsFullyKnown(termID: Int64)
  }

  public struct WordRow: Sendable {
    public let position: Int
    public let termID: Int64
    public let frequencyRank: Int?
    public let primarySpelling: String
    public let reading: String
    public let definitionSummary: String
    public let isFullyKnown: Bool
    public let learnedScore: Double
    public let cardCoverageCount: Int
  }

  public struct ViewModel: Sendable {
    public let rows: [WordRow]
    public let isLoadingMore: Bool
    public let hasMorePages: Bool
    public let totalLoaded: Int
    public let activeSortField: SortField
    public let activeFullyKnownFilter: FullyKnownFilter
    public let searchQuery: String
  }
}
