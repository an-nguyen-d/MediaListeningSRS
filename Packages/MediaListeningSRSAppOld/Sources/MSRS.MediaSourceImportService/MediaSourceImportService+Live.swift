import Foundation
import MSRS_SharedModels
import MSRS_MediaListeningSRSDatabaseClient
import JML_JMLDatabaseClient
import JML_JMLSharedModels
import METG_METGDatabaseClient

extension MediaSourceImportService {

  public static func liveValue(
    jmlDatabaseClient: JMLDatabaseClient,
    metgDatabaseClient: METGDatabaseClient,
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient
  ) -> Self {
    .init(
      import: { request in

        // 1. Resolve JML media reference to the Japanese subtitle sidecar file ID.
        let japaneseSubtitleFileID: LocalizedLocalFileModel.ID
        switch request.jmlMediaReference {
        case .movie(let movieID):
          guard let movie = try await jmlDatabaseClient.movie.fetch(.init(id: movieID)) else {
            throw MediaSourceImportError.jmlMediaNotFound
          }
          guard let fileID = movie.japaneseSubtitleFile?.id else {
            throw MediaSourceImportError.jmlMediaHasNoJapaneseSubtitleFile
          }
          japaneseSubtitleFileID = fileID

        case .episode(let episodeID):
          guard let episode = try await jmlDatabaseClient.tvShowEpisode.fetch(.init(id: episodeID)) else {
            throw MediaSourceImportError.jmlMediaNotFound
          }
          guard let fileID = episode.japaneseSubtitleFile?.id else {
            throw MediaSourceImportError.jmlMediaHasNoJapaneseSubtitleFile
          }
          japaneseSubtitleFileID = fileID
        }

        // 2. Live-fetch MWBT subtitle row + labels.
        let mwbtResponse = try await metgDatabaseClient.mediaSubtitlesList.fetchByFileIDs(
          .init(fileIDs: [japaneseSubtitleFileID])
        )
        guard let mwbtRow = mwbtResponse.subtitles.first else {
          throw MediaSourceImportError.mediaNotTaggedInMWBT
        }

        // 3. Every non-disabled subtitle index with at least one tagged word becomes a candidate.
        let disabledIndexes: Set<Int> = Set(mwbtRow.subtitle.disabledIndexes.map { $0.rawValue })
        var termIDsByIndex: [Int: Set<Int64>] = [:]
        for label in mwbtRow.labels {
          let idx = label.subtitleIndex.rawValue
          if disabledIndexes.contains(idx) { continue }
          termIDsByIndex[idx, default: []].insert(label.japaneseTermID.rawValue)
        }

        guard !termIDsByIndex.isEmpty else {
          throw MediaSourceImportError.noTaggedNonDisabledSegments
        }

        // 4. Insert the MediaSource.
        let createMediaSourceResponse = try await mediaListeningSRSDatabaseClient.mediaSource.create(
          .init(jmlMediaReference: request.jmlMediaReference)
        )

        // 5. Bulk-insert candidates + their term-link rows.
        let candidateInputs: [MediaListeningSRSDatabaseClient.MediaSourceCardCandidate.BulkCreate.CandidateInput] =
          termIDsByIndex.keys.sorted().map { subtitleIndex in
            let termIDs = Array(termIDsByIndex[subtitleIndex] ?? [])
            return .init(subtitleIndex: subtitleIndex, japaneseTermIDs: termIDs)
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
