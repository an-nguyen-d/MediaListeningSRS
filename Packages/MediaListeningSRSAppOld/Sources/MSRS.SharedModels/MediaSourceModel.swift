import Foundation
import Tagged
import JML_JMLSharedModels

public struct MediaSourceModel: Identifiable, Sendable, Equatable {

  public typealias ID = Tagged<(Self, id: ()), Int64>
  public let id: ID

  public let createdAt: Date
  public var lastUpdatedAt: Date

  public var jmlMediaReference: JMLMediaReference

  public init(
    id: ID,
    createdAt: Date,
    lastUpdatedAt: Date,
    jmlMediaReference: JMLMediaReference
  ) {
    self.id = id
    self.createdAt = createdAt
    self.lastUpdatedAt = lastUpdatedAt
    self.jmlMediaReference = jmlMediaReference
  }

  public enum JMLMediaReference: Hashable, Sendable, Equatable {
    case movie(MovieModel.ID)
    case episode(TVShowEpisodeModel.ID)
  }
}
