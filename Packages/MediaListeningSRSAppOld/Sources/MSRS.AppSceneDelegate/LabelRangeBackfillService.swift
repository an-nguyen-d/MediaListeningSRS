#if targetEnvironment(macCatalyst)
import Foundation
import ElixirShared
import JML_JMLDatabaseClient
import JML_JMLSharedModels
import METG_METGDatabaseClient
import METG_SharedModels
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_Shared
import MSRS_SharedModels

enum LabelRangeBackfillService {

  private static let userDefaultsKey = "MSRS.LabelRangeBackfill.completed"

  static func backfillIfNeeded(
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    jmlDatabaseClient: JMLDatabaseClient,
    metgDatabaseClient: METGDatabaseClient,
    srtParserClient: SRTParserClient
  ) async {
    guard !UserDefaults.standard.bool(forKey: userDefaultsKey) else { return }

    do {
      let allCardsResp = try await mediaListeningSRSDatabaseClient.srsCard.fetchAllCards(.init())
      let cardsWithoutLabels = allCardsResp.cards.filter { $0.cachedLabelRanges.isEmpty }

      guard !cardsWithoutLabels.isEmpty else {
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        return
      }

      print("[LabelRangeBackfill] \(cardsWithoutLabels.count) cards need label range backfill")

      let cardsBySourceID = Dictionary(grouping: cardsWithoutLabels, by: \.mediaSourceID)
      var updates: [MediaListeningSRSDatabaseClient.SRSCard.BatchUpdateCachedLabelRanges.CardLabelRangesData] = []

      for (mediaSourceID, cards) in cardsBySourceID {
        guard let sourceData = try await resolveSourceData(
          mediaSourceID: mediaSourceID,
          mediaListeningSRSDatabaseClient: mediaListeningSRSDatabaseClient,
          jmlDatabaseClient: jmlDatabaseClient,
          metgDatabaseClient: metgDatabaseClient,
          srtParserClient: srtParserClient
        ) else { continue }

        let termLinksResp = try await mediaListeningSRSDatabaseClient.mediaSourceCardCandidate.fetchTermLinksForSource(
          .init(mediaSourceID: mediaSourceID)
        )

        for card in cards {
          var subtitleTextsByIndex: [Int: String] = [:]
          var labelInputsByIndex: [Int: [SRSCardLabelRange.SubtitleLabelInput]] = [:]
          for index in card.subtitleIndexStart...card.subtitleIndexEnd {
            guard let seg = sourceData.segmentsByIndex[index] else { continue }
            subtitleTextsByIndex[index] = seg.text
            labelInputsByIndex[index] = (sourceData.labelsBySubtitleIndex[index] ?? []).map { label in
              .init(
                range: label.range,
                termID: label.japaneseTermID.rawValue,
                inflectionKey: termLinksResp.termLinksBySubtitleIndex[index]?
                  .first(where: { $0.japaneseTermID == label.japaneseTermID.rawValue })?
                  .inflectionKey ?? ""
              )
            }
          }

          let labelRanges = SRSCardLabelRange.buildFromSubtitles(
            indexRange: card.subtitleIndexStart...card.subtitleIndexEnd,
            subtitleTextsByIndex: subtitleTextsByIndex,
            labelsByIndex: labelInputsByIndex
          )

          guard !labelRanges.isEmpty else { continue }
          updates.append(.init(
            cardID: card.id,
            labelRangesJSON: SRSCardLabelRange.encodeToJSON(labelRanges)
          ))
        }
      }

      if !updates.isEmpty {
        _ = try await mediaListeningSRSDatabaseClient.srsCard.batchUpdateCachedLabelRanges(
          .init(updates: updates)
        )
        print("[LabelRangeBackfill] Updated \(updates.count) cards")
      }

      UserDefaults.standard.set(true, forKey: userDefaultsKey)
      print("[LabelRangeBackfill] Backfill complete")
    } catch {
      assertionFailure("LabelRangeBackfillService failed: \(error)")
    }
  }

  private struct SourceData {
    let segmentsByIndex: [Int: SubtitleSegment]
    let labelsBySubtitleIndex: [Int: [JapaneseTermLabelModel]]
  }

  private static func resolveSourceData(
    mediaSourceID: MediaSourceModel.ID,
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    jmlDatabaseClient: JMLDatabaseClient,
    metgDatabaseClient: METGDatabaseClient,
    srtParserClient: SRTParserClient
  ) async throws -> SourceData? {
    let sourceResp = try await mediaListeningSRSDatabaseClient.mediaSource.fetch(.init(id: mediaSourceID))
    let resolved = try await resolveURLs(
      for: sourceResp.model.jmlMediaReference,
      jmlDatabaseClient: jmlDatabaseClient
    )

    let srtContent = try String(contentsOf: resolved.subtitleURL, encoding: .utf8)
    let segments = srtParserClient.parse(.init(content: srtContent))
    let segmentsByIndex = Dictionary(uniqueKeysWithValues: segments.map { ($0.index.rawValue, $0) })

    let mwbtResp = try await metgDatabaseClient.mediaSubtitlesList.fetchByFileIDs(
      .init(fileIDs: [resolved.subtitleLocalizedLocalFileID])
    )
    var labelsBySubtitleIndex: [Int: [JapaneseTermLabelModel]] = [:]
    if let row = mwbtResp.subtitles.first {
      for label in row.labels {
        labelsBySubtitleIndex[label.subtitleIndex.rawValue, default: []].append(label)
      }
    }

    return SourceData(segmentsByIndex: segmentsByIndex, labelsBySubtitleIndex: labelsBySubtitleIndex)
  }

  private static func resolveURLs(
    for reference: MediaSourceModel.JMLMediaReference,
    jmlDatabaseClient: JMLDatabaseClient
  ) async throws -> (subtitleURL: URL, subtitleLocalizedLocalFileID: LocalizedLocalFileModel.ID) {
    switch reference {
    case .movie(let movieID):
      guard let movie = try await jmlDatabaseClient.movie.fetch(.init(id: movieID)),
            let subtitleFile = movie.japaneseSubtitleFile else {
        throw NSError(domain: "LabelRangeBackfill", code: 1, userInfo: [NSLocalizedDescriptionKey: "Movie subtitle missing"])
      }
      return (subtitleFile.url, subtitleFile.id)
    case .episode(let episodeID):
      guard let episode = try await jmlDatabaseClient.tvShowEpisode.fetch(.init(id: episodeID)),
            let subtitleFile = episode.japaneseSubtitleFile else {
        throw NSError(domain: "LabelRangeBackfill", code: 1, userInfo: [NSLocalizedDescriptionKey: "Episode subtitle missing"])
      }
      return (subtitleFile.url, subtitleFile.id)
    }
  }
}
#endif
