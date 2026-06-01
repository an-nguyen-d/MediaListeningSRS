import Foundation
import GRDB
import MSRS_FSRS
import MSRS_SharedModels
import MSRS_MediaListeningSRSDatabaseClient

public enum MediaListeningSRSDatabaseError: Error {
  case recordNotFound(id: Int64)
}

public enum MediaListeningSRSDatabaseConfiguration: Sendable {
  case inMemory
  case file(path: String)
}

extension MediaListeningSRSDatabaseClient {

  public static func grdbValue(
    configuration: MediaListeningSRSDatabaseConfiguration,
    fsrsParameters: FSRSParameters = FSRSParameters()
  ) -> Self {
    let databaseWriter: any DatabaseWriter

    do {
      switch configuration {
      case .inMemory:
        let dbQueue = try DatabaseQueue()
        try Self.createMigrator().migrate(dbQueue)
        databaseWriter = dbQueue

      case .file(let path):
        let dbQueue = try DatabaseQueue(path: path)
        try Self.createMigrator().migrate(dbQueue)
        databaseWriter = dbQueue
      }
    } catch {
      fatalError("MediaListeningSRSDatabaseClient migration failed: \(error.localizedDescription)")
    }

    return MediaListeningSRSDatabaseClient(
      mediaSource: Self.mediaSourceEndpoints(databaseWriter: databaseWriter),
      mediaSourceCardCandidate: Self.mediaSourceCardCandidateEndpoints(databaseWriter: databaseWriter),
      srsCard: Self.srsCardEndpoints(databaseWriter: databaseWriter, fsrsParameters: fsrsParameters),
      japaneseTerm: Self.japaneseTermEndpoints(databaseWriter: databaseWriter),
      studySession: Self.studySessionEndpoints(databaseWriter: databaseWriter)
    )
  }

  private static func createMigrator() -> DatabaseMigrator {
    var migrator = DatabaseMigrator()

    migrator.registerMigration("1") { db in

      try db.create(table: "mediaSourceRecord") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("createdAt", .datetime).notNull()
        t.column("lastUpdatedAt", .datetime).notNull()
        t.column("jmlMediaReferenceType", .integer).notNull()
        t.column("jmlMediaReferenceID", .integer).notNull()
        t.uniqueKey(["jmlMediaReferenceType", "jmlMediaReferenceID"])
      }

      try db.create(table: "mediaSourceCardCandidateRecord") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("createdAt", .datetime).notNull()
        t.column("lastUpdatedAt", .datetime).notNull()
        t.column("mediaSourceID", .integer)
          .notNull()
          .references("mediaSourceRecord", onDelete: .cascade)
        t.column("subtitleIndex", .integer).notNull()
        t.column("isSkipped", .boolean).notNull().defaults(to: false)
        t.column("wasUsedInCard", .boolean).notNull().defaults(to: false)
        t.uniqueKey(["mediaSourceID", "subtitleIndex"])
      }

      try db.create(table: "srsCardRecord") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("createdAt", .datetime).notNull()
        t.column("lastUpdatedAt", .datetime).notNull()
        t.column("mediaSourceID", .integer)
          .notNull()
          .references("mediaSourceRecord", onDelete: .cascade)
        t.column("subtitleIndexStart", .integer).notNull()
        t.column("subtitleIndexEnd", .integer).notNull()
        t.column("clipStartTimeSeconds", .double).notNull()
        t.column("clipEndTimeSeconds", .double).notNull()
        t.column("clipRelativeFilePath", .text).notNull()

        // FSRS scheduling state. cardType reserved for future review modes (only .listening = 1 for now).
        t.column("cardType", .integer).notNull().defaults(to: 1)
        t.column("stateRawValue", .integer).notNull().defaults(to: 0)
        t.column("stability", .double).notNull().defaults(to: 0)
        t.column("difficulty", .double).notNull().defaults(to: 0)
        t.column("elapsedDays", .double).notNull().defaults(to: 0)
        t.column("scheduledDays", .double).notNull().defaults(to: 0)
        t.column("repCount", .integer).notNull().defaults(to: 0)
        t.column("lapseCount", .integer).notNull().defaults(to: 0)
        t.column("lastReviewDate", .datetime)
        t.column("dueDate", .datetime)
      }

      // Many-to-many: candidate → words. (Frequency rank is fetched fresh from iYomi at popup
      // tap time — no need to cache it here.)
      try db.create(table: "mediaSourceCardCandidateJapaneseTermLinkRecord") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("candidateID", .integer)
          .notNull()
          .references("mediaSourceCardCandidateRecord", onDelete: .cascade)
        t.column("japaneseTermID", .integer).notNull()
        t.uniqueKey(["candidateID", "japaneseTermID"])
      }
      try db.create(index: "idx_msccjtl_termID",
                    on: "mediaSourceCardCandidateJapaneseTermLinkRecord",
                    columns: ["japaneseTermID"])

      // Many-to-many: card → words. Drives `LearnedTermService` score computation.
      try db.create(table: "srsCardJapaneseTermLinkRecord") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("cardID", .integer)
          .notNull()
          .references("srsCardRecord", onDelete: .cascade)
        t.column("japaneseTermID", .integer).notNull()
        t.uniqueKey(["cardID", "japaneseTermID"])
      }
      try db.create(index: "idx_scjtl_termID",
                    on: "srsCardJapaneseTermLinkRecord",
                    columns: ["japaneseTermID"])

      try db.create(table: "srsReviewEventRecord") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("cardID", .integer)
          .notNull()
          .references("srsCardRecord", onDelete: .cascade)
        t.column("ratingRawValue", .integer).notNull()
        t.column("stabilityAfterReview", .double).notNull()
        t.column("difficultyAfterReview", .double).notNull()
        t.column("dueDateAfterReview", .datetime).notNull()
        t.column("occurredAt", .datetime).notNull()
      }
      try db.create(index: "idx_sre_cardID",
                    on: "srsReviewEventRecord",
                    columns: ["cardID"])

      // Single-row settings table (legacy mastery thresholds, no longer used by new scoring).
      try db.create(table: "appSettingsRecord") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("masteryMinimumCardsCount", .integer).notNull().defaults(to: 10)
        t.column("masteryMinimumStability", .double).notNull().defaults(to: 30)
      }
      try db.execute(sql: """
        INSERT INTO appSettingsRecord (masteryMinimumCardsCount, masteryMinimumStability)
        VALUES (10, 30)
      """)

      // Manually-marked known words.
      try db.create(table: "knownJapaneseTermRecord") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("japaneseTermID", .integer).notNull().unique()
        t.column("manuallyMarkedAt", .datetime).notNull()
      }
      try db.create(index: "idx_kjt_termID",
                    on: "knownJapaneseTermRecord",
                    columns: ["japaneseTermID"])
    }

    migrator.registerMigration("2") { db in

      try db.create(table: "japaneseTermCardCoverageRecord") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("japaneseTermID", .integer).notNull().unique()
        t.column("cardCoverageCount", .integer).notNull().defaults(to: 0)
      }
      try db.create(index: "idx_jtccr_termID",
                    on: "japaneseTermCardCoverageRecord",
                    columns: ["japaneseTermID"])

      try db.alter(table: "mediaSourceCardCandidateRecord") { t in
        t.add(column: "isAutoFiltered", .boolean).notNull().defaults(to: false)
      }

      try db.execute(sql: """
        INSERT INTO japaneseTermCardCoverageRecord (japaneseTermID, cardCoverageCount)
        SELECT japaneseTermID, COUNT(DISTINCT cardID)
        FROM srsCardJapaneseTermLinkRecord
        GROUP BY japaneseTermID
      """)
    }

    migrator.registerMigration("3") { db in
      try db.alter(table: "srsCardRecord") { t in
        t.add(column: "frontVideoVisibilityRawValue", .integer).notNull().defaults(to: 0)
      }
    }

    migrator.registerMigration("4") { db in
      try db.alter(table: "srsCardRecord") { t in
        t.add(column: "playbackSpeed", .double).notNull().defaults(to: 1.0)
        t.add(column: "consecutiveCorrectAtCurrentSpeed", .integer).notNull().defaults(to: 0)
      }
    }

    migrator.registerMigration("5") { db in
      try db.create(table: "studySessionRecord") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("startedAt", .datetime).notNull()
        t.column("endedAt", .datetime).notNull()
        t.column("cardsReviewed", .integer).notNull().defaults(to: 0)
      }
      try db.create(
        index: "idx_ssr_startedAt",
        on: "studySessionRecord",
        columns: ["startedAt"]
      )
    }

    return migrator
  }
}
