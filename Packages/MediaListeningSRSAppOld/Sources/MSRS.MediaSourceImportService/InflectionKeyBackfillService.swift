import Foundation
import MSRS_SharedModels
import MSRS_Shared
import MSRS_MediaListeningSRSDatabaseClient
import JML_JMLDatabaseClient
import JML_JMLSharedModels
import METG_METGDatabaseClient
import ElixirShared
import IYO_JapaneseParserClient

public enum InflectionKeyBackfillService {

  private static let userDefaultsKey = "MSRS.InflectionKeyBackfill.completed"

  public static func backfillIfNeeded(
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    jmlDatabaseClient: JMLDatabaseClient,
    metgDatabaseClient: METGDatabaseClient,
    srtParserClient: SRTParserClient,
    japaneseParserClient: JapaneseParserClient
  ) async {
    guard !UserDefaults.standard.bool(forKey: userDefaultsKey) else { return }

    do {
      let sourcesStream = try await mediaListeningSRSDatabaseClient.mediaSource.observeAll(.init())
      var mediaSources: [MediaSourceModel] = []
      for try await batch in sourcesStream {
        mediaSources = batch
        break
      }

      guard !mediaSources.isEmpty else {
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        return
      }

      let prefixLookup: @Sendable (String) async throws -> [InflectionDerivationHelper.LookupResult] = { surfaceText in
        let response = try await japaneseParserClient.prefixDictionaryLookup(
          .init(text: surfaceText, maxResultCount: nil)
        )
        return response.lookupResults.map { result in
          InflectionDerivationHelper.LookupResult(
            dictionaryID: result.dictionaryID,
            inflectionKey: MSRSInflectionFormMapper.inflectionKey(from: result.inflections)
          )
        }
      }

      var sourceBackfillData: [MediaListeningSRSDatabaseClient.JapaneseTerm.SourceInflectionData] = []

      for source in mediaSources {
        guard let data = try await deriveForSource(
          source: source,
          jmlDatabaseClient: jmlDatabaseClient,
          metgDatabaseClient: metgDatabaseClient,
          srtParserClient: srtParserClient,
          prefixLookup: prefixLookup
        ) else { continue }
        sourceBackfillData.append(data)
      }

      if !sourceBackfillData.isEmpty {
        _ = try await mediaListeningSRSDatabaseClient.japaneseTerm.backfillInflectionKeys(
          .init(sourceData: sourceBackfillData)
        )
      }

      UserDefaults.standard.set(true, forKey: userDefaultsKey)
    } catch {
      assertionFailure("InflectionKeyBackfillService failed: \(error)")
    }
  }

  private static func deriveForSource(
    source: MediaSourceModel,
    jmlDatabaseClient: JMLDatabaseClient,
    metgDatabaseClient: METGDatabaseClient,
    srtParserClient: SRTParserClient,
    prefixLookup: @Sendable (_ surfaceText: String) async throws -> [InflectionDerivationHelper.LookupResult]
  ) async throws -> MediaListeningSRSDatabaseClient.JapaneseTerm.SourceInflectionData? {
    let subtitleFileID: LocalizedLocalFileModel.ID
    let subtitleFileURL: URL

    switch source.jmlMediaReference {
    case .movie(let movieID):
      guard let movie = try await jmlDatabaseClient.movie.fetch(.init(id: movieID)),
            let file = movie.japaneseSubtitleFile else { return nil }
      subtitleFileID = file.id
      subtitleFileURL = file.url

    case .episode(let episodeID):
      guard let episode = try await jmlDatabaseClient.tvShowEpisode.fetch(.init(id: episodeID)),
            let file = episode.japaneseSubtitleFile else { return nil }
      subtitleFileID = file.id
      subtitleFileURL = file.url
    }

    guard FileManager.default.fileExists(atPath: subtitleFileURL.path) else { return nil }

    let srtContent = try String(contentsOf: subtitleFileURL, encoding: .utf8)
    let segments = srtParserClient.parse(.init(content: srtContent))
    var segmentTextsByIndex: [Int: String] = [:]
    for segment in segments {
      segmentTextsByIndex[segment.index.rawValue] = segment.text
    }

    let mwbtResponse = try await metgDatabaseClient.mediaSubtitlesList.fetchByFileIDs(
      .init(fileIDs: [subtitleFileID])
    )
    guard let mwbtRow = mwbtResponse.subtitles.first else { return nil }

    let labelInfos: [InflectionDerivationHelper.LabelInfo] = mwbtRow.labels.map { label in
      InflectionDerivationHelper.LabelInfo(
        subtitleIndex: label.subtitleIndex.rawValue,
        utf16Range: label.range,
        japaneseTermID: label.japaneseTermID.rawValue
      )
    }

    let derivedPairsByIndex = await InflectionDerivationHelper.deriveInflectionPairs(
      labels: labelInfos,
      segmentTextsByIndex: segmentTextsByIndex,
      prefixLookup: prefixLookup
    )

    return .init(
      mediaSourceID: source.id,
      pairsBySubtitleIndex: derivedPairsByIndex
    )
  }
}
