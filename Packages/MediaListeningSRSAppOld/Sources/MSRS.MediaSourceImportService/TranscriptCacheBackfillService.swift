import Foundation
import MSRS_SharedModels
import MSRS_Shared
import MSRS_MediaListeningSRSDatabaseClient
import JML_JMLDatabaseClient
import JML_JMLSharedModels
import ElixirShared

public enum TranscriptCacheBackfillService {

  private static let userDefaultsKey = "MSRS.TranscriptCacheBackfill.completed"

  public static func backfillIfNeeded(
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    jmlDatabaseClient: JMLDatabaseClient,
    srtParserClient: SRTParserClient
  ) async {
    guard !UserDefaults.standard.bool(forKey: userDefaultsKey) else { return }

    do {
      let cardsStream = try await mediaListeningSRSDatabaseClient.srsCard.observeAll(.init())
      var allCards: [SRSCardModel] = []
      for try await batch in cardsStream {
        allCards = batch
        break
      }

      let cardsNeedingBackfill = allCards.filter { $0.cachedTranscriptText.isEmpty }
      guard !cardsNeedingBackfill.isEmpty else {
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        return
      }

      let cardsByMediaSourceID = Dictionary(grouping: cardsNeedingBackfill, by: \.mediaSourceID)
      var updates: [MediaListeningSRSDatabaseClient.SRSCard.BatchUpdateCachedTranscripts.CardTranscriptData] = []

      for (mediaSourceID, cards) in cardsByMediaSourceID {
        guard let sourceData = try await resolveSourceData(
          mediaSourceID: mediaSourceID,
          mediaListeningSRSDatabaseClient: mediaListeningSRSDatabaseClient,
          jmlDatabaseClient: jmlDatabaseClient,
          srtParserClient: srtParserClient
        ) else { continue }

        for card in cards {
          let transcriptParts = (card.subtitleIndexStart...card.subtitleIndexEnd)
            .compactMap { sourceData.segmentTextsByIndex[$0] }
          let transcriptText = transcriptParts.joined(separator: "\n")

          let translationParts = (card.subtitleIndexStart...card.subtitleIndexEnd)
            .compactMap { sourceData.translationsByIndex[$0] }
          let translationText = translationParts.joined(separator: "\n")

          updates.append(.init(
            cardID: card.id,
            cachedTranscriptText: transcriptText,
            cachedEnglishTranslation: translationText
          ))
        }
      }

      if !updates.isEmpty {
        _ = try await mediaListeningSRSDatabaseClient.srsCard.batchUpdateCachedTranscripts(
          .init(updates: updates)
        )
        print("[TranscriptCacheBackfill] Backfilled \(updates.count) cards")
      }

      UserDefaults.standard.set(true, forKey: userDefaultsKey)
    } catch {
      assertionFailure("TranscriptCacheBackfillService failed: \(error)")
    }
  }

  private struct SourceData {
    let segmentTextsByIndex: [Int: String]
    let translationsByIndex: [Int: String]
  }

  private static func resolveSourceData(
    mediaSourceID: MediaSourceModel.ID,
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    jmlDatabaseClient: JMLDatabaseClient,
    srtParserClient: SRTParserClient
  ) async throws -> SourceData? {
    let sourceResp = try await mediaListeningSRSDatabaseClient.mediaSource.fetch(.init(id: mediaSourceID))
    let subtitleURL: URL

    switch sourceResp.model.jmlMediaReference {
    case .movie(let movieID):
      guard let movie = try await jmlDatabaseClient.movie.fetch(.init(id: movieID)),
            let file = movie.japaneseSubtitleFile else { return nil }
      subtitleURL = file.url
    case .episode(let episodeID):
      guard let episode = try await jmlDatabaseClient.tvShowEpisode.fetch(.init(id: episodeID)),
            let file = episode.japaneseSubtitleFile else { return nil }
      subtitleURL = file.url
    }

    guard FileManager.default.fileExists(atPath: subtitleURL.path) else { return nil }

    let srtContent = try String(contentsOf: subtitleURL, encoding: .utf8)
    let segments = srtParserClient.parse(.init(content: srtContent))
    var segmentTextsByIndex: [Int: String] = [:]
    for segment in segments {
      segmentTextsByIndex[segment.index.rawValue] = segment.text
    }

    let translationsByIndex = loadEnglishTranslations(subtitleURL: subtitleURL)

    return SourceData(
      segmentTextsByIndex: segmentTextsByIndex,
      translationsByIndex: translationsByIndex
    )
  }

  private static func loadEnglishTranslations(subtitleURL: URL) -> [Int: String] {
    let base = subtitleURL.deletingPathExtension().path
    let candidatePath = "\(base)-translation_en-gpt5mini.json"
    let candidateURL = URL(fileURLWithPath: candidatePath)
    guard FileManager.default.fileExists(atPath: candidateURL.path),
          let data = try? Data(contentsOf: candidateURL),
          let stringMap = try? JSONDecoder().decode([String: String].self, from: data) else {
      return [:]
    }
    var result: [Int: String] = [:]
    for (key, value) in stringMap {
      if let intKey = Int(key) { result[intKey] = value }
    }
    return result
  }
}
