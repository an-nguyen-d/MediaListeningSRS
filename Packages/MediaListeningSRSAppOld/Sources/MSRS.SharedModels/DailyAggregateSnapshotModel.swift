import Foundation
import Tagged

public struct DailyAggregateSnapshotModel: Identifiable, Sendable, Equatable {

  public typealias ID = Tagged<(Self, id: ()), Int64>

  public let id: ID
  public let snapshotDate: String
  public let totalActiveCards: Int
  public let newCardCount: Int
  public let learningCardCount: Int
  public let reviewCardCount: Int
  public let relearningCardCount: Int
  public let totalUniqueTermsCovered: Int
  public let totalFullyKnownTerms: Int

  public init(
    id: ID,
    snapshotDate: String,
    totalActiveCards: Int,
    newCardCount: Int,
    learningCardCount: Int,
    reviewCardCount: Int,
    relearningCardCount: Int,
    totalUniqueTermsCovered: Int,
    totalFullyKnownTerms: Int
  ) {
    self.id = id
    self.snapshotDate = snapshotDate
    self.totalActiveCards = totalActiveCards
    self.newCardCount = newCardCount
    self.learningCardCount = learningCardCount
    self.reviewCardCount = reviewCardCount
    self.relearningCardCount = relearningCardCount
    self.totalUniqueTermsCovered = totalUniqueTermsCovered
    self.totalFullyKnownTerms = totalFullyKnownTerms
  }
}
