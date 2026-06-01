import Foundation
import Tagged

public struct StudySessionModel: Identifiable, Sendable, Equatable {

  public typealias ID = Tagged<(Self, id: ()), Int64>

  public let id: ID
  public let startedAt: Date
  public var endedAt: Date
  public var cardsReviewed: Int

  public init(
    id: ID,
    startedAt: Date,
    endedAt: Date,
    cardsReviewed: Int
  ) {
    self.id = id
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.cardsReviewed = cardsReviewed
  }
}
