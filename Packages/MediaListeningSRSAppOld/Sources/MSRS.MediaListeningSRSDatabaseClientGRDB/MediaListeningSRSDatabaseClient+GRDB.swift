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
      studySession: Self.studySessionEndpoints(databaseWriter: databaseWriter),
      dailySnapshot: Self.dailySnapshotEndpoints(databaseWriter: databaseWriter),
      appSettings: Self.appSettingsEndpoints(databaseWriter: databaseWriter),
      close: { @Sendable in
        try (databaseWriter as? DatabaseQueue)?.close()
      }
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

    migrator.registerMigration("6") { db in
      try db.create(table: "dailyAggregateSnapshotRecord") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("snapshotDate", .text).notNull().unique()
        t.column("totalActiveCards", .integer).notNull()
        t.column("newCardCount", .integer).notNull()
        t.column("learningCardCount", .integer).notNull()
        t.column("reviewCardCount", .integer).notNull()
        t.column("relearningCardCount", .integer).notNull()
        t.column("totalUniqueTermsCovered", .integer).notNull()
        t.column("totalFullyKnownTerms", .integer).notNull()
      }

      try db.create(table: "dailyCardSnapshotRecord") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("aggregateSnapshotID", .integer)
          .notNull()
          .references("dailyAggregateSnapshotRecord", onDelete: .cascade)
        t.column("cardID", .integer).notNull()
        t.column("stateRawValue", .integer).notNull()
        t.column("stability", .double).notNull()
        t.column("difficulty", .double).notNull()
        t.column("repCount", .integer).notNull()
        t.column("lapseCount", .integer).notNull()
        t.column("dueDate", .datetime)
      }
      try db.create(
        index: "idx_dcs_aggregateSnapshotID",
        on: "dailyCardSnapshotRecord",
        columns: ["aggregateSnapshotID"]
      )
    }

    migrator.registerMigration("7") { db in

      // Recreate srsCardJapaneseTermLinkRecord with inflectionKey column
      // and updated unique constraint: (cardID, japaneseTermID, inflectionKey)
      try db.execute(sql: """
        CREATE TABLE srsCardJapaneseTermLinkRecord_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cardID INTEGER NOT NULL REFERENCES srsCardRecord(id) ON DELETE CASCADE,
          japaneseTermID INTEGER NOT NULL,
          inflectionKey TEXT NOT NULL DEFAULT '',
          UNIQUE(cardID, japaneseTermID, inflectionKey)
        )
      """)
      try db.execute(sql: """
        INSERT INTO srsCardJapaneseTermLinkRecord_new (id, cardID, japaneseTermID, inflectionKey)
        SELECT id, cardID, japaneseTermID, '' FROM srsCardJapaneseTermLinkRecord
      """)
      try db.execute(sql: "DROP TABLE srsCardJapaneseTermLinkRecord")
      try db.execute(sql: "ALTER TABLE srsCardJapaneseTermLinkRecord_new RENAME TO srsCardJapaneseTermLinkRecord")
      try db.create(index: "idx_scjtl_termID",
                    on: "srsCardJapaneseTermLinkRecord",
                    columns: ["japaneseTermID"])

      // Recreate mediaSourceCardCandidateJapaneseTermLinkRecord with inflectionKey
      // and updated unique constraint: (candidateID, japaneseTermID, inflectionKey)
      try db.execute(sql: """
        CREATE TABLE mediaSourceCardCandidateJapaneseTermLinkRecord_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          candidateID INTEGER NOT NULL REFERENCES mediaSourceCardCandidateRecord(id) ON DELETE CASCADE,
          japaneseTermID INTEGER NOT NULL,
          inflectionKey TEXT NOT NULL DEFAULT '',
          UNIQUE(candidateID, japaneseTermID, inflectionKey)
        )
      """)
      try db.execute(sql: """
        INSERT INTO mediaSourceCardCandidateJapaneseTermLinkRecord_new (id, candidateID, japaneseTermID, inflectionKey)
        SELECT id, candidateID, japaneseTermID, '' FROM mediaSourceCardCandidateJapaneseTermLinkRecord
      """)
      try db.execute(sql: "DROP TABLE mediaSourceCardCandidateJapaneseTermLinkRecord")
      try db.execute(sql: "ALTER TABLE mediaSourceCardCandidateJapaneseTermLinkRecord_new RENAME TO mediaSourceCardCandidateJapaneseTermLinkRecord")
      try db.create(index: "idx_msccjtl_termID",
                    on: "mediaSourceCardCandidateJapaneseTermLinkRecord",
                    columns: ["japaneseTermID"])

      // Recreate japaneseTermCardCoverageRecord with inflectionKey
      // and updated unique constraint: (japaneseTermID, inflectionKey)
      try db.execute(sql: """
        CREATE TABLE japaneseTermCardCoverageRecord_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          japaneseTermID INTEGER NOT NULL,
          inflectionKey TEXT NOT NULL DEFAULT '',
          cardCoverageCount INTEGER NOT NULL DEFAULT 0,
          UNIQUE(japaneseTermID, inflectionKey)
        )
      """)
      try db.execute(sql: """
        INSERT INTO japaneseTermCardCoverageRecord_new (japaneseTermID, inflectionKey, cardCoverageCount)
        SELECT japaneseTermID, '', COUNT(DISTINCT cardID)
        FROM srsCardJapaneseTermLinkRecord
        GROUP BY japaneseTermID
      """)
      try db.execute(sql: "DROP TABLE japaneseTermCardCoverageRecord")
      try db.execute(sql: "ALTER TABLE japaneseTermCardCoverageRecord_new RENAME TO japaneseTermCardCoverageRecord")
      try db.create(index: "idx_jtccr_termID",
                    on: "japaneseTermCardCoverageRecord",
                    columns: ["japaneseTermID"])
    }

    migrator.registerMigration("8") { db in
      try db.alter(table: "srsCardRecord") { t in
        t.add(column: "cachedTranscriptText", .text).notNull().defaults(to: "")
        t.add(column: "cachedEnglishTranslation", .text).notNull().defaults(to: "")
      }
    }

    migrator.registerMigration("9") { db in
      try db.alter(table: "appSettingsRecord") { t in
        t.add(column: "desiredRetention", .double).notNull().defaults(to: 0.9)
        t.add(column: "showFrontTranscript", .boolean).notNull().defaults(to: true)
        t.add(column: "minimumCardCoverageCount", .integer).notNull().defaults(to: 50)
        t.add(column: "studySessionInactivityTimeout", .integer).notNull().defaults(to: 300)
        t.add(column: "requireSkipOrMakeCardConfirmation", .boolean).notNull().defaults(to: true)
        t.add(column: "autoLoopVideo", .boolean).notNull().defaults(to: false)
        t.add(column: "llmGradingPrompt", .text).notNull().defaults(to: "")
      }
    }

    migrator.registerMigration("10") { db in
      try db.alter(table: "appSettingsRecord") { t in
        t.add(column: "syncIntervalSeconds", .integer).notNull().defaults(to: 60)
      }
    }

    migrator.registerMigration("11") { db in
      try db.alter(table: "srsCardRecord") { t in
        t.add(column: "cachedLabelRangesJSON", .text).notNull().defaults(to: "")
      }
    }

    migrator.registerMigration("12") { db in
      try db.alter(table: "appSettingsRecord") { t in
        t.add(column: "candidatePlayDelay", .double).notNull().defaults(to: 0)
      }
    }

    migrator.registerMigration("13") { db in
      try db.alter(table: "srsCardRecord") { t in
        t.add(column: "isSuspended", .boolean).notNull().defaults(to: false)
      }
    }

    return migrator
  }
}
