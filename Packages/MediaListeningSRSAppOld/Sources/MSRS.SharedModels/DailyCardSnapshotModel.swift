import Foundation
import Tagged

public struct DailyCardSnapshotModel: Identifiable, Sendable, Equatable {

  public typealias ID = Tagged<(Self, id: ()), Int64>

  public let id: ID
  public let aggregateSnapshotID: DailyAggregateSnapshotModel.ID
  public let cardID: SRSCardModel.ID
  public let stateRawValue: Int
  public let stability: Double
  public let difficulty: Double
  public let repCount: Int
  public let lapseCount: Int
  public let dueDate: Date?

  public init(
    id: ID,
    aggregateSnapshotID: DailyAggregateSnapshotModel.ID,
    cardID: SRSCardModel.ID,
    stateRawValue: Int,
    stability: Double,
    difficulty: Double,
    repCount: Int,
    lapseCount: Int,
    dueDate: Date?
  ) {
    self.id = id
    self.aggregateSnapshotID = aggregateSnapshotID
    self.cardID = cardID
    self.stateRawValue = stateRawValue
    self.stability = stability
    self.difficulty = difficulty
    self.repCount = repCount
    self.lapseCount = lapseCount
    self.dueDate = dueDate
  }
}
