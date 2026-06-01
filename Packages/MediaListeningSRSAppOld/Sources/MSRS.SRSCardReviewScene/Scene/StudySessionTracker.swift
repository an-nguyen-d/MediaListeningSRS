import Foundation
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_Shared
import MSRS_SharedModels

@MainActor
final class StudySessionTracker {

  private let dbClient: MediaListeningSRSDatabaseClient
  private let inactivityThreshold: TimeInterval

  private var currentSessionID: StudySessionModel.ID?
  private var lastHeartbeatDate: Date?
  private var cardsReviewedCount: Int = 0
  private var isBootstrapping: Bool = false
  private var isCreatingSession: Bool = false

  init(dbClient: MediaListeningSRSDatabaseClient) {
    self.dbClient = dbClient
    self.inactivityThreshold = TimeInterval(MSRSAppSettings.studySessionInactivityTimeout)
  }

  func recordHeartbeat(isCardReview: Bool) {
    let now = Date()

    if isCardReview {
      cardsReviewedCount += 1
    }

    if let lastTime = lastHeartbeatDate,
       now.timeIntervalSince(lastTime) > inactivityThreshold {
      currentSessionID = nil
      cardsReviewedCount = isCardReview ? 1 : 0
    }

    lastHeartbeatDate = now

    if let sessionID = currentSessionID {
      updateSession(sessionID: sessionID, endedAt: now)
    } else if !isCreatingSession && !isBootstrapping {
      bootstrap(now: now)
    }
  }

  private func bootstrap(now: Date) {
    isBootstrapping = true
    Task { [weak self, dbClient] in
      do {
        let response = try await dbClient.studySession.fetchMostRecent(.init())
        await MainActor.run {
          guard let self else { return }
          self.isBootstrapping = false

          if let model = response.model,
             now.timeIntervalSince(model.endedAt) <= self.inactivityThreshold {
            self.currentSessionID = model.id
            self.cardsReviewedCount += model.cardsReviewed
            if let latestTime = self.lastHeartbeatDate {
              self.updateSession(sessionID: model.id, endedAt: latestTime)
            }
          } else {
            self.createNewSession(startedAt: now)
          }
        }
      } catch {
        await MainActor.run {
          self?.isBootstrapping = false
          self?.createNewSession(startedAt: now)
        }
      }
    }
  }

  private func createNewSession(startedAt: Date) {
    guard !isCreatingSession else { return }
    isCreatingSession = true
    let cardsReviewed = cardsReviewedCount
    Task { [weak self, dbClient] in
      do {
        let response = try await dbClient.studySession.createSession(
          .init(startedAt: startedAt, endedAt: startedAt, cardsReviewed: cardsReviewed)
        )
        await MainActor.run {
          guard let self else { return }
          self.isCreatingSession = false
          self.currentSessionID = response.model.id
          if let latestTime = self.lastHeartbeatDate, latestTime > startedAt {
            self.updateSession(sessionID: response.model.id, endedAt: latestTime)
          }
        }
      } catch {
        await MainActor.run { self?.isCreatingSession = false }
      }
    }
  }

  private func updateSession(sessionID: StudySessionModel.ID, endedAt: Date) {
    let cardsReviewed = cardsReviewedCount
    Task { [dbClient] in
      try? await dbClient.studySession.updateSession(
        .init(id: sessionID, endedAt: endedAt, cardsReviewed: cardsReviewed)
      )
    }
  }
}
