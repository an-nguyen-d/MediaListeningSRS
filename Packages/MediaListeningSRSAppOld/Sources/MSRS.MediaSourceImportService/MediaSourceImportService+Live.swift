import Foundation
import MSRS_SharedModels
import MSRS_Shared
import MSRS_MediaListeningSRSDatabaseClient
import JML_JMLDatabaseClient
import JML_JMLSharedModels
import METG_METGDatabaseClient
import ElixirShared
import IYO_JapaneseParserClient

extension MediaSourceImportService {

  public static func liveValue(
    jmlDatabaseClient: JMLDatabaseClient,
    metgDatabaseClient: METGDatabaseClient,
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    srtParserClient: SRTParserClient,
    japaneseParserClient: JapaneseParserClient
  ) -> Self {
    .init(
      import: { request in

        // 1. Resolve JML media reference to the Japanese subtitle sidecar file.
        let japaneseSubtitleFileID: LocalizedLocalFileModel.ID
        let subtitleFileURL: URL
        switch request.jmlMediaReference {
        case .movie(let movieID):
          guard let movie = try await jmlDatabaseClient.movie.fetch(.init(id: movieID)) else {
            throw MediaSourceImportError.jmlMediaNotFound
          }
          guard let file = movie.japaneseSubtitleFile else {
            throw MediaSourceImportError.jmlMediaHasNoJapaneseSubtitleFile
          }
          japaneseSubtitleFileID = file.id
          subtitleFileURL = file.url

        case .episode(let episodeID):
          guard let episode = try await jmlDatabaseClient.tvShowEpisode.fetch(.init(id: episodeID)) else {
            throw MediaSourceImportError.jmlMediaNotFound
          }
          guard let file = episode.japaneseSubtitleFile else {
            throw MediaSourceImportError.jmlMediaHasNoJapaneseSubtitleFile
          }
          japaneseSubtitleFileID = file.id
          subtitleFileURL = file.url
        }

        // 2. Live-fetch MWBT subtitle row + labels.
        let mwbtResponse = try await metgDatabaseClient.mediaSubtitlesList.fetchByFileIDs(
          .init(fileIDs: [japaneseSubtitleFileID])
        )
        guard let mwbtRow = mwbtResponse.subtitles.first else {
          throw MediaSourceImportError.mediaNotTaggedInMWBT
        }

        // 3. Load and parse the SRT file for segment texts.
        let srtContent = try String(contentsOf: subtitleFileURL, encoding: .utf8)
        let segments = srtParserClient.parse(.init(content: srtContent))
        var segmentTextsByIndex: [Int: String] = [:]
        for segment in segments {
          segmentTextsByIndex[segment.index.rawValue] = segment.text
        }

        // 4. Build label infos from non-disabled MWBT labels and derive inflection pairs.
        let disabledIndexes: Set<Int> = Set(mwbtRow.subtitle.disabledIndexes.map { $0.rawValue })
        let labelInfos: [InflectionDerivationHelper.LabelInfo] = mwbtRow.labels.compactMap { label in
          let idx = label.subtitleIndex.rawValue
          guard !disabledIndexes.contains(idx) else { return nil }
          return InflectionDerivationHelper.LabelInfo(
            subtitleIndex: idx,
            utf16Range: label.range,
            japaneseTermID: label.japaneseTermID.rawValue
          )
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

        let derivedPairsByIndex = await InflectionDerivationHelper.deriveInflectionPairs(
          labels: labelInfos,
          segmentTextsByIndex: segmentTextsByIndex,
          prefixLookup: prefixLookup
        )

        var termPairsByIndex: [Int: Set<TermInflectionPair>] = [:]
        for (idx, pairs) in derivedPairsByIndex {
          termPairsByIndex[idx] = Set(pairs)
        }

        guard !termPairsByIndex.isEmpty else {
          throw MediaSourceImportError.noTaggedNonDisabledSegments
        }

        // 5. Filter out segments where every tagged pair is invalid (known OR coverage >= threshold).
        let allPairs = Array(Set(termPairsByIndex.values.flatMap { $0 }))
        let coverageThresholdValue = UserDefaults.standard.integer(
          forKey: "MSRS.Settings.minimumCardCoverageCount"
        )
        let effectiveCoverageThreshold = coverageThresholdValue > 0 ? coverageThresholdValue : 50
        let invalidResponse = try await mediaListeningSRSDatabaseClient.japaneseTerm
          .fetchInvalidTermPairs(.init(
            termPairs: allPairs,
            coverageThreshold: effectiveCoverageThreshold
          ))
        termPairsByIndex = termPairsByIndex.filter { (_, pairs) in
          pairs.contains { !invalidResponse.invalidPairs.contains($0) }
        }

        guard !termPairsByIndex.isEmpty else {
          throw MediaSourceImportError.noTaggedNonDisabledSegments
        }

        // 6. Insert the MediaSource.
        let createMediaSourceResponse = try await mediaListeningSRSDatabaseClient.mediaSource.create(
          .init(jmlMediaReference: request.jmlMediaReference)
        )

        // 7. Bulk-insert candidates + their term-link rows.
        let candidateInputs: [MediaListeningSRSDatabaseClient.MediaSourceCardCandidate.BulkCreate.CandidateInput] =
          termPairsByIndex.keys.sorted().map { subtitleIndex in
            let pairs = Array(termPairsByIndex[subtitleIndex] ?? [])
            return .init(subtitleIndex: subtitleIndex, termLinks: pairs)
          }

        let bulkCreateResponse = try await mediaListeningSRSDatabaseClient.mediaSourceCardCandidate.bulkCreate(
          .init(
            mediaSourceID: createMediaSourceResponse.model.id,
            candidates: candidateInputs
          )
        )

        return .init(
          createdMediaSource: createMediaSourceResponse.model,
          createdCandidates: bulkCreateResponse.createdModels
        )
      }
    )
  }

}
