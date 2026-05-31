import Foundation
import GRDB
import MSRS_FSRS
import MSRS_SharedModels
import MSRS_MediaListeningSRSDatabaseClient

extension MediaListeningSRSDatabaseClient {

  internal static func srsCardEndpoints(
    databaseWriter: DatabaseWriter,
    fsrsParameters: FSRSParameters
  ) -> SRSCard {
    .init(
      create: { request in
        try await databaseWriter.write { db in
          let now = Date()
          var record = SRSCardRecord(
            id: nil,
            createdAt: now,
            lastUpdatedAt: now,
            mediaSourceID: request.mediaSourceID.rawValue,
            subtitleIndexStart: request.subtitleIndexStart,
            subtitleIndexEnd: request.subtitleIndexEnd,
            clipStartTimeSeconds: request.clipStartTimeSeconds,
            clipEndTimeSeconds: request.clipEndTimeSeconds,
            clipRelativeFilePath: request.clipRelativeFilePath
          )
          try record.insert(db)
          guard let cardID = record.id else {
            return .init(model: GRDBMapper.SRSCard.mapToModel(from: record))
          }

          let uniqueTermIDs = Set(request.japaneseTermIDs)
          for termID in uniqueTermIDs {
            var link = SRSCardJapaneseTermLinkRecord(
              id: nil,
              cardID: cardID,
              japaneseTermID: termID
            )
            try link.insert(db)
          }

          // Hide every candidate whose subtitle index falls within this card's range so
          // the processing queue moves to the next un-processed candidate.
          try db.execute(sql: """
            UPDATE mediaSourceCardCandidateRecord
            SET wasUsedInCard = 1, lastUpdatedAt = ?
            WHERE mediaSourceID = ?
              AND subtitleIndex BETWEEN ? AND ?
          """, arguments: [
            Date(),
            request.mediaSourceID.rawValue,
            request.subtitleIndexStart,
            request.subtitleIndexEnd
          ])

          return .init(model: GRDBMapper.SRSCard.mapToModel(from: record))
        }
      },
      delete: { request in
        try await databaseWriter.write { db in
          let didDelete = try SRSCardRecord.deleteOne(db, key: request.id.rawValue)
          guard didDelete else {
            throw MediaListeningSRSDatabaseError.recordNotFound(id: request.id.rawValue)
          }
          return .init()
        }
      },
      observeForSource: { request in
        AsyncThrowingStream { continuation in
          Task { @MainActor in
            let token = ValueObservation
              .tracking { db in
                try SRSCardRecord
                  .filter(Column("mediaSourceID") == request.mediaSourceID.rawValue)
                  .order(Column("createdAt").asc)
                  .fetchAll(db)
              }
              .start(
                in: databaseWriter,
                onError: { continuation.finish(throwing: $0) },
                onChange: { records in
                  let models = records.map { GRDBMapper.SRSCard.mapToModel(from: $0) }
                  continuation.yield(models)
                }
              )
            continuation.onTermination = { _ in token.cancel() }
          }
        }
      },
      observeAll: { _ in
        AsyncThrowingStream { continuation in
          Task { @MainActor in
            let token = ValueObservation
              .tracking { db in
                try SRSCardRecord
                  .order(Column("createdAt").asc)
                  .fetchAll(db)
              }
              .start(
                in: databaseWriter,
                onError: { continuation.finish(throwing: $0) },
                onChange: { records in
                  let models = records.map { GRDBMapper.SRSCard.mapToModel(from: $0) }
                  continuation.yield(models)
                }
              )
            continuation.onTermination = { _ in token.cancel() }
          }
        }
      },
      recordReview: { request in
        try await databaseWriter.write { db in
          guard var record = try SRSCardRecord.fetchOne(db, key: request.cardID.rawValue) else {
            throw MediaListeningSRSDatabaseError.recordNotFound(id: request.cardID.rawValue)
          }
          guard let rating = Rating(rawValue: request.ratingRawValue), rating != .manual else {
            throw NSError(
              domain: "MediaListeningSRSDatabaseClient.SRSCard.recordReview",
              code: 1,
              userInfo: [NSLocalizedDescriptionKey: "Invalid rating raw value \(request.ratingRawValue)"]
            )
          }
          let now = Date()

          let cardState = CardState(rawValue: record.stateRawValue) ?? .new
          let currentCard = Card(
            due: record.dueDate ?? now,
            stability: record.stability,
            difficulty: record.difficulty,
            elapsedDays: record.elapsedDays,
            scheduledDays: record.scheduledDays,
            reps: record.repCount,
            lapses: record.lapseCount,
            state: cardState,
            lastReview: record.lastReviewDate
          )

          var reviewParameters = fsrsParameters
          if let userRetention = UserDefaults.standard.object(forKey: "MSRS.Settings.desiredRetention") as? Double {
            reviewParameters = FSRSParameters(
              requestRetention: userRetention,
              maximumInterval: fsrsParameters.maximumInterval,
              w: fsrsParameters.w,
              enableFuzz: fsrsParameters.enableFuzz,
              enableShortTerm: fsrsParameters.enableShortTerm
            )
          }
          let fsrs = FSRS(parameters: reviewParameters)
          let result = try fsrs.next(card: currentCard, now: now, grade: rating)
          let updatedFSRSCard = result.card

          record.stateRawValue = updatedFSRSCard.state.rawValue
          record.stability = updatedFSRSCard.stability
          record.difficulty = updatedFSRSCard.difficulty
          record.elapsedDays = updatedFSRSCard.elapsedDays
          record.scheduledDays = updatedFSRSCard.scheduledDays
          record.repCount = updatedFSRSCard.reps
          record.lapseCount = updatedFSRSCard.lapses
          record.lastReviewDate = updatedFSRSCard.lastReview
          record.dueDate = updatedFSRSCard.due
          record.lastUpdatedAt = now
          try record.update(db)

          var event = SRSReviewEventRecord(
            id: nil,
            cardID: request.cardID.rawValue,
            ratingRawValue: rating.rawValue,
            stabilityAfterReview: updatedFSRSCard.stability,
            difficultyAfterReview: updatedFSRSCard.difficulty,
            dueDateAfterReview: updatedFSRSCard.due,
            occurredAt: now
          )
          try event.insert(db)

          return .init(
            updatedModel: GRDBMapper.SRSCard.mapToModel(from: record),
            nextDueDate: updatedFSRSCard.due
          )
        }
      },
      fetchDueCards: { request in
        try await databaseWriter.read { db in
          // 1) Overdue cards (have been reviewed, due date in the past) — most overdue first
          // 2) New cards (never reviewed, dueDate is NULL) — oldest created first
          let records = try SRSCardRecord.fetchAll(db, sql: """
            SELECT * FROM srsCardRecord
            WHERE dueDate IS NULL OR dueDate <= ?
            ORDER BY
              CASE WHEN dueDate IS NOT NULL THEN 0 ELSE 1 END,
              CASE WHEN dueDate IS NOT NULL THEN dueDate END ASC,
              createdAt ASC
          """, arguments: [request.asOf])
          return .init(cards: records.map { GRDBMapper.SRSCard.mapToModel(from: $0) })
        }
      }
    )
  }
}
