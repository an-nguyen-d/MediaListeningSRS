import Foundation
import Tagged

public struct MediaSourceCardCandidateModel: Identifiable, Sendable, Equatable {

  public typealias ID = Tagged<(Self, id: ()), Int64>
  public let id: ID

  public let createdAt: Date
  public var lastUpdatedAt: Date

  public let mediaSourceID: MediaSourceModel.ID
  public let subtitleIndex: Int

  public var isSkipped: Bool
  public var wasUsedInCard: Bool
  public var isAutoFiltered: Bool

  public init(
    id: ID,
    createdAt: Date,
    lastUpdatedAt: Date,
    mediaSourceID: MediaSourceModel.ID,
    subtitleIndex: Int,
    isSkipped: Bool,
    wasUsedInCard: Bool,
    isAutoFiltered: Bool
  ) {
    self.id = id
    self.createdAt = createdAt
    self.lastUpdatedAt = lastUpdatedAt
    self.mediaSourceID = mediaSourceID
    self.subtitleIndex = subtitleIndex
    self.isSkipped = isSkipped
    self.wasUsedInCard = wasUsedInCard
    self.isAutoFiltered = isAutoFiltered
  }
}
