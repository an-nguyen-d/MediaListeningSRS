import Foundation
import Tagged

public struct SRSCardModel: Identifiable, Sendable, Equatable {

  public typealias ID = Tagged<(Self, id: ()), Int64>
  public let id: ID

  public let createdAt: Date
  public var lastUpdatedAt: Date

  public let mediaSourceID: MediaSourceModel.ID

  public let subtitleIndexStart: Int
  public let subtitleIndexEnd: Int

  public let clipStartTimeSeconds: TimeInterval
  public let clipEndTimeSeconds: TimeInterval

  public let clipRelativeFilePath: String

  public init(
    id: ID,
    createdAt: Date,
    lastUpdatedAt: Date,
    mediaSourceID: MediaSourceModel.ID,
    subtitleIndexStart: Int,
    subtitleIndexEnd: Int,
    clipStartTimeSeconds: TimeInterval,
    clipEndTimeSeconds: TimeInterval,
    clipRelativeFilePath: String
  ) {
    self.id = id
    self.createdAt = createdAt
    self.lastUpdatedAt = lastUpdatedAt
    self.mediaSourceID = mediaSourceID
    self.subtitleIndexStart = subtitleIndexStart
    self.subtitleIndexEnd = subtitleIndexEnd
    self.clipStartTimeSeconds = clipStartTimeSeconds
    self.clipEndTimeSeconds = clipEndTimeSeconds
    self.clipRelativeFilePath = clipRelativeFilePath
  }
}
