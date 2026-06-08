import Foundation
import GRDB
import MSRS_FSRS
import MSRS_Shared
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
            clipRelativeFilePath: request.clipRelativeFilePath,
            cachedTranscriptText: request.cachedTranscriptText,
            cachedEnglishTranslation: request.cachedEnglishTranslation,
            cachedLabelRangesJSON: SRSCardLabelRange.encodeToJSON(request.labelRanges)
          )
          try record.insert(db)
          guard let cardID = record.id else {
            return .init(model: GRDBMapper.SRSCard.mapToModel(from: record))
          }

          let uniqueLinks = Set(request.japaneseTermLinks)
          for link in uniqueLinks {
            var record = SRSCardJapaneseTermLinkRecord(
              id: nil,
              cardID: cardID,
              japaneseTermID: link.japaneseTermID,
              inflectionKey: link.inflectionKey
            )
            try record.insert(db)
          }

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

          for link in uniqueLinks {
            try db.execute(sql: """
              INSERT INTO japaneseTermCardCoverageRecord (japaneseTermID, inflectionKey, cardCoverageCount)
              VALUES (?, ?, 1)
              ON CONFLICT(japaneseTermID, inflectionKey) DO UPDATE SET cardCoverageCount = cardCoverageCount + 1
            """, arguments: [link.japaneseTermID, link.inflectionKey])
          }

          let coverageThreshold = CandidateValidityFilterService.readCoverageThreshold(db: db)
          try CandidateValidityFilterService.cascadeAutoFilter(
            changedPairs: uniqueLinks,
            coverageThreshold: coverageThreshold,
            db: db
          )

          return .init(model: GRDBMapper.SRSCard.mapToModel(from: record))
        }
      },
      createReadingCard: { request in
        try await databaseWriter.write { db in
          guard let sourceRecord = try SRSCardRecord.fetchOne(db, key: request.sourceCardID.rawValue) else {
            throw MediaListeningSRSDatabaseError.recordNotFound(id: request.sourceCardID.rawValue)
          }

          let existingCount = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM srsCardRecord
            WHERE cardType = 2
              AND clipRelativeFilePath = ?
              AND targetTermID = ?
              AND targetTermUTF16Location = ?
          """, arguments: [
            sourceRecord.clipRelativeFilePath,
            request.targetTermID,
            request.targetTermUTF16Location
          ]) ?? 0
          if existingCount > 0 {
            throw NSError(
              domain: "MediaListeningSRSDatabaseClient.SRSCard.createReadingCard",
              code: 2,
              userInfo: [NSLocalizedDescriptionKey: "A reading card for this word already exists"]
            )
          }

          let minDueDate: Date? = try Date.fetchOne(db, sql: """
            SELECT MIN(dueDate) FROM srsCardRecord
            WHERE dueDate IS NOT NULL AND isSuspended = 0
          """)
          let newDueDate = minDueDate.map { $0.addingTimeInterval(-1) } ?? Date.distantPast

          let now = Date()
          var newRecord = SRSCardRecord(
            id: nil,
            createdAt: now,
            lastUpdatedAt: now,
            mediaSourceID: sourceRecord.mediaSourceID,
            subtitleIndexStart: sourceRecord.subtitleIndexStart,
            subtitleIndexEnd: sourceRecord.subtitleIndexEnd,
            clipStartTimeSeconds: sourceRecord.clipStartTimeSeconds,
            clipEndTimeSeconds: sourceRecord.clipEndTimeSeconds,
            clipRelativeFilePath: sourceRecord.clipRelativeFilePath,
            cachedTranscriptText: sourceRecord.cachedTranscriptText,
            cachedEnglishTranslation: sourceRecord.cachedEnglishTranslation,
            cachedLabelRangesJSON: sourceRecord.cachedLabelRangesJSON
          )
          newRecord.cardType = 2
          newRecord.dueDate = newDueDate
          newRecord.targetTermID = request.targetTermID
          newRecord.targetTermUTF16Location = request.targetTermUTF16Location
          newRecord.targetTermUTF16Length = request.targetTermUTF16Length
          try newRecord.insert(db)

          if let newCardID = newRecord.id {
            try db.execute(sql: """
              INSERT INTO srsCardJapaneseTermLinkRecord (cardID, japaneseTermID, inflectionKey)
              SELECT ?, japaneseTermID, inflectionKey
              FROM srsCardJapaneseTermLinkRecord
              WHERE cardID = ?
            """, arguments: [newCardID, request.sourceCardID.rawValue])
          }

          return .init(model: GRDBMapper.SRSCard.mapToModel(from: newRecord))
        }
      },
      delete: { request in
        try await databaseWriter.write { db in
          guard let record = try SRSCardRecord.fetchOne(db, key: request.id.rawValue) else {
            throw MediaListeningSRSDatabaseError.recordNotFound(id: request.id.rawValue)
          }
          let cardType = record.cardType

          let linkRows = try Row.fetchAll(db, sql: """
            SELECT japaneseTermID, inflectionKey FROM srsCardJapaneseTermLinkRecord WHERE cardID = ?
          """, arguments: [request.id.rawValue])
          let links = linkRows.compactMap { row -> TermInflectionPair? in
            guard let termID: Int64 = row["japaneseTermID"],
                  let key: String = row["inflectionKey"] else { return nil }
            return TermInflectionPair(japaneseTermID: termID, inflectionKey: key)
          }

          let didDelete = try SRSCardRecord.deleteOne(db, key: request.id.rawValue)
          guard didDelete else {
            throw MediaListeningSRSDatabaseError.recordNotFound(id: request.id.rawValue)
          }

          if cardType == 1 {
            for link in links {
              try db.execute(sql: """
                UPDATE japaneseTermCardCoverageRecord
                SET cardCoverageCount = MAX(0, cardCoverageCount - 1)
                WHERE japaneseTermID = ? AND inflectionKey = ?
              """, arguments: [link.japaneseTermID, link.inflectionKey])
            }
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
      // Candidate validity cascade is intentionally not triggered here. See CandidateValidityFilterService.
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

          let reviewParameters = Self.fsrsParametersWithDBRetention(
            base: fsrsParameters, db: db
          )
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
          if rating == .good || rating == .easy {
            record.consecutiveCorrectAtCurrentSpeed += 1
          } else {
            record.consecutiveCorrectAtCurrentSpeed = 0
          }
          record.lastUpdatedAt = now
          try record.update(db)

          var event = SRSReviewEventRecord(
            id: nil,
            cardID: request.cardID.rawValue,
            ratingRawValue: rating.rawValue,
            stabilityAfterReview: updatedFSRSCard.stability,
            difficultyAfterReview: updatedFSRSCard.difficulty,
            dueDateAfterReview: updatedFSRSCard.due,
            occurredAt: now,
            listenCount: request.listenCount
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
          let baseSql = """
            SELECT * FROM srsCardRecord
            WHERE clipRelativeFilePath != ''
              AND isSuspended = 0
              AND (dueDate IS NULL OR dueDate <= ?)
            ORDER BY
              CASE WHEN dueDate IS NOT NULL THEN 0 ELSE 1 END,
              CASE WHEN dueDate IS NOT NULL THEN dueDate END ASC,
              createdAt ASC
          """
          let records: [SRSCardRecord]
          if let limit = request.limit {
            records = try SRSCardRecord.fetchAll(db, sql: baseSql + "\nLIMIT ?", arguments: [request.asOf, limit])
          } else {
            records = try SRSCardRecord.fetchAll(db, sql: baseSql, arguments: [request.asOf])
          }
          return .init(cards: records.map { GRDBMapper.SRSCard.mapToModel(from: $0) })
        }
      },
      updateFrontVideoVisibility: { request in
        try await databaseWriter.write { db in
          guard var record = try SRSCardRecord.fetchOne(db, key: request.cardID.rawValue) else {
            throw MediaListeningSRSDatabaseError.recordNotFound(id: request.cardID.rawValue)
          }
          record.frontVideoVisibilityRawValue = request.visibility.rawValue
          record.lastUpdatedAt = Date()
          try record.update(db)
          return .init()
        }
      },
      updatePlaybackSpeed: { request in
        try await databaseWriter.write { db in
          guard var record = try SRSCardRecord.fetchOne(db, key: request.cardID.rawValue) else {
            throw MediaListeningSRSDatabaseError.recordNotFound(id: request.cardID.rawValue)
          }
          record.playbackSpeed = request.speed
          record.consecutiveCorrectAtCurrentSpeed = 0
          record.lastUpdatedAt = Date()
          try record.update(db)
          return .init()
        }
      },
      updateClipPath: { request in
        try await databaseWriter.write { db in
          guard var record = try SRSCardRecord.fetchOne(db, key: request.cardID.rawValue) else {
            throw MediaListeningSRSDatabaseError.recordNotFound(id: request.cardID.rawValue)
          }
          record.clipRelativeFilePath = request.clipRelativeFilePath
          record.lastUpdatedAt = Date()
          try record.update(db)
          return .init()
        }
      },
      previewNextIntervals: { request in
        try await databaseWriter.read { db in
          guard let record = try SRSCardRecord.fetchOne(db, key: request.cardID.rawValue) else {
            throw MediaListeningSRSDatabaseError.recordNotFound(id: request.cardID.rawValue)
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

          let reviewParameters = Self.fsrsParametersWithDBRetention(
            base: fsrsParameters, db: db
          )
          let fsrs = FSRS(parameters: reviewParameters)
          let preview = fsrs.repeat(card: currentCard, now: now)

          let failDue = preview[.again]?.card.due ?? now
          let hardDue = preview[.hard]?.card.due ?? now
          let mediumDue = preview[.good]?.card.due ?? now
          let easyDue = preview[.easy]?.card.due ?? now

          return .init(
            failIntervalSeconds: max(0, failDue.timeIntervalSince(now)),
            hardIntervalSeconds: max(0, hardDue.timeIntervalSince(now)),
            mediumIntervalSeconds: max(0, mediumDue.timeIntervalSince(now)),
            easyIntervalSeconds: max(0, easyDue.timeIntervalSince(now))
          )
        }
      },
      fetchTermLinksForCard: { request in
        try await databaseWriter.read { db in
          let rows = try Row.fetchAll(db, sql: """
            SELECT japaneseTermID, inflectionKey
            FROM srsCardJapaneseTermLinkRecord
            WHERE cardID = ?
          """, arguments: [request.cardID.rawValue])
          let links = rows.compactMap { row -> TermInflectionPair? in
            guard let termID: Int64 = row["japaneseTermID"],
                  let key: String = row["inflectionKey"] else { return nil }
            return TermInflectionPair(japaneseTermID: termID, inflectionKey: key)
          }
          return .init(termLinks: links)
        }
      },
      batchUpdateCachedTranscripts: { request in
        try await databaseWriter.write { db in
          var count = 0
          for update in request.updates {
            try db.execute(sql: """
              UPDATE srsCardRecord
              SET cachedTranscriptText = ?, cachedEnglishTranslation = ?, lastUpdatedAt = ?
              WHERE id = ?
            """, arguments: [
              update.cachedTranscriptText,
              update.cachedEnglishTranslation,
              Date(),
              update.cardID.rawValue
            ])
            count += db.changesCount
          }
          return .init(updatedCount: count)
        }
      },
      batchUpdateCachedLabelRanges: { request in
        try await databaseWriter.write { db in
          var count = 0
          for update in request.updates {
            try db.execute(sql: """
              UPDATE srsCardRecord
              SET cachedLabelRangesJSON = ?, lastUpdatedAt = ?
              WHERE id = ?
            """, arguments: [
              update.labelRangesJSON,
              Date(),
              update.cardID.rawValue
            ])
            count += db.changesCount
          }
          return .init(updatedCount: count)
        }
      },
      fetchAllCards: { _ in
        try await databaseWriter.read { db in
          let records = try SRSCardRecord.fetchAll(db, sql: """
            SELECT * FROM srsCardRecord ORDER BY createdAt ASC
          """)
          return .init(cards: records.map { GRDBMapper.SRSCard.mapToModel(from: $0) })
        }
      },
      fetchCardsWithEmptyClipPath: { _ in
        try await databaseWriter.read { db in
          let records = try SRSCardRecord.fetchAll(db, sql: """
            SELECT * FROM srsCardRecord
            WHERE clipRelativeFilePath = ''
            ORDER BY mediaSourceID ASC, subtitleIndexStart ASC
          """)
          return .init(cards: records.map { GRDBMapper.SRSCard.mapToModel(from: $0) })
        }
      },
      countDueCards: { request in
        try await databaseWriter.read { db in
          let count = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM srsCardRecord
            WHERE clipRelativeFilePath != ''
              AND isSuspended = 0
              AND (dueDate IS NULL OR dueDate <= ?)
          """, arguments: [request.asOf]) ?? 0
          return .init(count: count)
        }
      },
      fetchCardStateCounts: { request in
        try await databaseWriter.read { db in
          let stateCounts = try Row.fetchAll(db, sql: """
            SELECT stateRawValue, COUNT(*) as cnt
            FROM srsCardRecord
            WHERE isSuspended = 0
            GROUP BY stateRawValue
          """)
          var countsByState: [Int: Int] = [:]
          for row in stateCounts {
            guard let state: Int = row["stateRawValue"],
                  let cnt: Int = row["cnt"] else { continue }
            countsByState[state] = cnt
          }

          let suspendedCount = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM srsCardRecord WHERE isSuspended = 1
          """) ?? 0

          let dueNowCount = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM srsCardRecord
            WHERE clipRelativeFilePath != ''
              AND isSuspended = 0
              AND (dueDate IS NULL OR dueDate <= ?)
          """, arguments: [request.asOf]) ?? 0

          let totalActive = countsByState.values.reduce(0, +)

          return .init(
            totalCards: totalActive + suspendedCount,
            newCount: countsByState[0, default: 0],
            learningCount: countsByState[1, default: 0],
            reviewCount: countsByState[2, default: 0],
            relearningCount: countsByState[3, default: 0],
            suspendedCount: suspendedCount,
            dueNowCount: dueNowCount
          )
        }
      },
      suspendCard: { request in
        try await databaseWriter.write { db in
          guard var record = try SRSCardRecord.fetchOne(db, key: request.cardID.rawValue) else {
            throw MediaListeningSRSDatabaseError.recordNotFound(id: request.cardID.rawValue)
          }
          record.isSuspended = true
          record.lastUpdatedAt = Date()
          try record.update(db)
          return .init()
        }
      },
      fetchRecentReviewEvents: { request in
        try await databaseWriter.read { db in
          let rows = try Row.fetchAll(db, sql: """
            SELECT e.cardID, e.ratingRawValue, e.occurredAt, e.listenCount,
                   c.cachedTranscriptText
            FROM srsReviewEventRecord e
            JOIN srsCardRecord c ON c.id = e.cardID
            ORDER BY e.occurredAt DESC
            LIMIT ?
          """, arguments: [request.limit])
          let events: [MediaListeningSRSDatabaseClient.SRSCard.RecentReviewEvent] = rows.map { row in
            .init(
              cardID: .init(rawValue: row["cardID"]),
              ratingRawValue: row["ratingRawValue"],
              occurredAt: row["occurredAt"],
              listenCount: row["listenCount"],
              cachedTranscriptText: row["cachedTranscriptText"]
            )
          }
          return .init(events: events)
        }
      },
      fetchReviewEventsForCard: { request in
        try await databaseWriter.read { db in
          let rows = try Row.fetchAll(db, sql: """
            SELECT e.cardID, e.ratingRawValue, e.occurredAt, e.listenCount,
                   c.cachedTranscriptText
            FROM srsReviewEventRecord e
            JOIN srsCardRecord c ON c.id = e.cardID
            WHERE e.cardID = ?
            ORDER BY e.occurredAt DESC
          """, arguments: [request.cardID.rawValue])
          let events: [MediaListeningSRSDatabaseClient.SRSCard.RecentReviewEvent] = rows.map { row in
            .init(
              cardID: .init(rawValue: row["cardID"]),
              ratingRawValue: row["ratingRawValue"],
              occurredAt: row["occurredAt"],
              listenCount: row["listenCount"],
              cachedTranscriptText: row["cachedTranscriptText"]
            )
          }
          return .init(events: events)
        }
      }
    )
  }

  private static func fsrsParametersWithDBRetention(
    base: FSRSParameters, db: Database
  ) -> FSRSParameters {
    guard let record = try? AppSettingsRecord.fetchOne(db),
          record.desiredRetention != base.requestRetention else {
      return base
    }
    return FSRSParameters(
      requestRetention: record.desiredRetention,
      maximumInterval: base.maximumInterval,
      w: base.w,
      enableFuzz: base.enableFuzz,
      enableShortTerm: base.enableShortTerm
    )
  }
}
