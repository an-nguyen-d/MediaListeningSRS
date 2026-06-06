import Foundation
import ElixirShared
import JML_JMLDatabaseClient
import JML_JMLSharedModels
import METG_SharedModels
#if targetEnvironment(macCatalyst)
import METG_METGDatabaseClient
#endif
import MSRS_ClipExportService
import MSRS_ClipStorageClient
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_Shared
import MSRS_SharedModels

@MainActor
protocol ProcessingQueueInteractorProtocol {
  func sendAction(_ action: ProcessingQueueModels.Action)
}

@MainActor
final class ProcessingQueueInteractor: ProcessingQueueInteractorProtocol {

  let presenter: ProcessingQueuePresenter
  private let mediaSourceID: MediaSourceModel.ID

  private let mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient
  private let jmlDatabaseClient: JMLDatabaseClient
  #if targetEnvironment(macCatalyst)
  private let metgDatabaseClient: METGDatabaseClient
  #endif
  private let srtParserClient: SRTParserClient
  private let clipExportService: ClipExportService
  private let clipStorageClient: ClipStorageClient
  private let exportedClipsDirectoryURL: URL

  private var observationTask: Task<Void, Never>?
  private var createAllTask: Task<Void, Never>?
  private var totalCandidateCount: Int = 0

  var onCreateAllProgress: ((_ completed: Int, _ total: Int) -> Void)?
  var onCreateAllFinished: ((_ createdCount: Int, _ errorCount: Int) -> Void)?

  init(
    presenter: ProcessingQueuePresenter,
    mediaSourceID: MediaSourceModel.ID,
    dependencies: ProcessingQueueModels.Dependencies
  ) {
    self.presenter = presenter
    self.mediaSourceID = mediaSourceID
    self.mediaListeningSRSDatabaseClient = dependencies.mediaListeningSRSDatabaseClient
    self.jmlDatabaseClient = dependencies.jmlDatabaseClient
    #if targetEnvironment(macCatalyst)
    self.metgDatabaseClient = dependencies.metgDatabaseClient
    #endif
    self.srtParserClient = dependencies.srtParserClient
    self.clipExportService = dependencies.clipExportService
    self.clipStorageClient = dependencies.clipStorageClient
    self.exportedClipsDirectoryURL = dependencies.exportedClipsDirectoryURL
  }

  deinit {
    observationTask?.cancel()
    createAllTask?.cancel()
  }

  func sendAction(_ action: ProcessingQueueModels.Action) {
    switch action {
    case .viewDidLoad:
      handleViewDidLoad()
    case .rowTapped(let id):
      presenter.presentNavigateToCandidateDetail(candidateID: id, mediaSourceID: mediaSourceID)
    case .createAllTapped:
      handleCreateAll()
    }
  }

  private func handleViewDidLoad() {
    observationTask?.cancel()
    let mediaSourceID = self.mediaSourceID
    observationTask = Task { [mediaListeningSRSDatabaseClient, jmlDatabaseClient, presenter] in
      do {
        let sourceResponse = try await mediaListeningSRSDatabaseClient.mediaSource.fetch(
          .init(id: mediaSourceID)
        )
        let title = await Self.resolveTitle(
          for: sourceResponse.model.jmlMediaReference,
          jmlDatabaseClient: jmlDatabaseClient
        )
        await MainActor.run { presenter.presentTitle(title) }

        let totalResponse = try await mediaListeningSRSDatabaseClient.mediaSourceCardCandidate
          .fetchTotalCandidateCountForSource(.init(mediaSourceID: mediaSourceID))
        let totalCount = totalResponse.totalCount

        await MainActor.run {
          self.totalCandidateCount = totalCount
        }

        let stream = try await mediaListeningSRSDatabaseClient.mediaSourceCardCandidate.observeForSource(
          .init(mediaSourceID: mediaSourceID)
        )
        for try await candidates in stream {
          await MainActor.run {
            let rows = candidates.map {
              ProcessingQueueModels.Row(id: $0.id, subtitleIndex: $0.subtitleIndex)
            }
            presenter.presentRows(rows, totalCandidateCount: totalCount)
          }
        }
      } catch {
        await MainActor.run {
          presenter.presentError("Failed to load candidates: \(error.localizedDescription)")
        }
      }
    }
  }

  private func handleCreateAll() {
    guard createAllTask == nil else { return }
    let mediaSourceID = self.mediaSourceID
    createAllTask = Task { [
      mediaListeningSRSDatabaseClient, jmlDatabaseClient, srtParserClient,
      clipExportService, clipStorageClient, exportedClipsDirectoryURL,
      weak self
    ] in
      do {
        let stream = try await mediaListeningSRSDatabaseClient.mediaSourceCardCandidate.observeForSource(
          .init(mediaSourceID: mediaSourceID)
        )
        var candidates: [MediaSourceCardCandidateModel] = []
        for try await batch in stream {
          candidates = batch
          break
        }
        guard !candidates.isEmpty else {
          await MainActor.run { self?.finishCreateAll(created: 0, errors: 0) }
          return
        }

        let sourceResponse = try await mediaListeningSRSDatabaseClient.mediaSource.fetch(
          .init(id: mediaSourceID)
        )
        let resolved = try await Self.resolveURLs(
          for: sourceResponse.model.jmlMediaReference,
          jmlDatabaseClient: jmlDatabaseClient
        )
        let srtContent = try String(contentsOf: resolved.subtitleURL, encoding: .utf8)
        let segments = srtParserClient.parse(.init(content: srtContent))
        let segmentsByIndex = Dictionary(uniqueKeysWithValues: segments.map { ($0.index.rawValue, $0) })

        let translationsByIndex = Self.loadEnglishTranslationsIfPresent(subtitleURL: resolved.subtitleURL)

        var labelsBySubtitleIndex: [Int: [JapaneseTermLabelModel]] = [:]
        #if targetEnvironment(macCatalyst)
        let mwbtResp = try await self?.metgDatabaseClient.mediaSubtitlesList.fetchByFileIDs(
          .init(fileIDs: [resolved.subtitleLocalizedLocalFileID])
        )
        if let row = mwbtResp?.subtitles.first {
          for label in row.labels {
            labelsBySubtitleIndex[label.subtitleIndex.rawValue, default: []].append(label)
          }
        }
        #endif

        let termLinksResp = try await mediaListeningSRSDatabaseClient.mediaSourceCardCandidate.fetchTermLinksForSource(
          .init(mediaSourceID: mediaSourceID)
        )
        let termLinksBySubtitleIndex = termLinksResp.termLinksBySubtitleIndex

        let total = candidates.count
        await MainActor.run { self?.onCreateAllProgress?(0, total) }

        var createdCount = 0
        var errorCount = 0

        for (index, candidate) in candidates.enumerated() {
          if Task.isCancelled { break }

          let subtitleIndex = candidate.subtitleIndex
          guard let segment = segmentsByIndex[subtitleIndex] else {
            errorCount += 1
            await MainActor.run { self?.onCreateAllProgress?(index + 1, total) }
            continue
          }

          var japaneseTermLinks: Set<TermInflectionPair> = []
          for pair in termLinksBySubtitleIndex[subtitleIndex] ?? [] {
            japaneseTermLinks.insert(pair)
          }

          let transcriptText = segment.text
          let translationText = translationsByIndex[subtitleIndex] ?? ""

          let subtitleTextsByIndex: [Int: String] = [subtitleIndex: segment.text]
          var labelInputsByIndex: [Int: [SRSCardLabelRange.SubtitleLabelInput]] = [:]
          labelInputsByIndex[subtitleIndex] = (labelsBySubtitleIndex[subtitleIndex] ?? []).map { label in
            .init(
              range: label.range,
              termID: label.japaneseTermID.rawValue,
              inflectionKey: termLinksBySubtitleIndex[subtitleIndex]?
                .first(where: { $0.japaneseTermID == label.japaneseTermID.rawValue })?
                .inflectionKey ?? ""
            )
          }
          let labelRanges = SRSCardLabelRange.buildFromSubtitles(
            indexRange: subtitleIndex...subtitleIndex,
            subtitleTextsByIndex: subtitleTextsByIndex,
            labelsByIndex: labelInputsByIndex
          )

          let outputFileURL = exportedClipsDirectoryURL
            .appendingPathComponent("\(mediaSourceID.rawValue)", isDirectory: true)
            .appendingPathComponent("\(UUID().uuidString).mp4", isDirectory: false)

          do {
            let createResponse = try await mediaListeningSRSDatabaseClient.srsCard.create(.init(
              mediaSourceID: mediaSourceID,
              subtitleIndexStart: subtitleIndex,
              subtitleIndexEnd: subtitleIndex,
              clipStartTimeSeconds: segment.startTime,
              clipEndTimeSeconds: segment.endTime,
              clipRelativeFilePath: "",
              cachedTranscriptText: transcriptText,
              cachedEnglishTranslation: translationText,
              japaneseTermLinks: Array(japaneseTermLinks),
              labelRanges: labelRanges
            ))
            let cardID = createResponse.model.id

            await ClipExportManager.shared.enqueue(
              request: .init(
                sourceVideoFileURL: resolved.videoURL,
                startTimeSeconds: segment.startTime,
                endTimeSeconds: segment.endTime,
                outputFileURL: outputFileURL
              ),
              exportClip: clipExportService.exportClip,
              onComplete: { [clipStorageClient, exportedClipsDirectoryURL] exportedFileURL in
                let relativePath = exportedFileURL.path.replacingOccurrences(
                  of: exportedClipsDirectoryURL.path,
                  with: ""
                ).trimmingCharacters(in: CharacterSet(charactersIn: "/"))

                do {
                  _ = try await mediaListeningSRSDatabaseClient.srsCard.updateClipPath(.init(
                    cardID: cardID,
                    clipRelativeFilePath: relativePath
                  ))
                } catch {
                  print("[CreateAll] DB update failed for card \(cardID.rawValue): \(error)")
                  return
                }

                #if targetEnvironment(macCatalyst)
                let remotePath = "clips/\(relativePath)"
                do {
                  _ = try await clipStorageClient.upload(.init(
                    localFileURL: exportedFileURL,
                    remotePath: remotePath
                  ))
                } catch {
                  print("[CreateAll] Upload failed for \(remotePath): \(error)")
                }

                let thumbnailURL = exportedFileURL.deletingPathExtension().appendingPathExtension("jpg")
                if FileManager.default.fileExists(atPath: thumbnailURL.path) {
                  let thumbRemotePath = "clips/\(relativePath.replacingOccurrences(of: ".mp4", with: ".jpg"))"
                  do {
                    _ = try await clipStorageClient.upload(.init(
                      localFileURL: thumbnailURL,
                      remotePath: thumbRemotePath
                    ))
                  } catch {
                    print("[CreateAll] Thumbnail upload failed: \(error)")
                  }
                }
                #endif
              }
            )
            createdCount += 1
          } catch {
            errorCount += 1
            print("[CreateAll] Card creation failed for subtitle \(subtitleIndex): \(error)")
          }

          await MainActor.run { self?.onCreateAllProgress?(index + 1, total) }
        }

        await MainActor.run { self?.finishCreateAll(created: createdCount, errors: errorCount) }
      } catch {
        await MainActor.run {
          self?.presenter.presentError("Create all failed: \(error.localizedDescription)")
          self?.finishCreateAll(created: 0, errors: 0)
        }
      }
    }
  }

  private func finishCreateAll(created: Int, errors: Int) {
    createAllTask = nil
    onCreateAllFinished?(created, errors)
  }

  private static func resolveURLs(
    for reference: MediaSourceModel.JMLMediaReference,
    jmlDatabaseClient: JMLDatabaseClient
  ) async throws -> (videoURL: URL, subtitleURL: URL, subtitleLocalizedLocalFileID: LocalizedLocalFileModel.ID) {
    switch reference {
    case .movie(let movieID):
      guard let movie = try await jmlDatabaseClient.movie.fetch(.init(id: movieID)),
            let videoURL = movie.japaneseVideoLocalURL,
            let subtitleFile = movie.japaneseSubtitleFile else {
        throw NSError(
          domain: "ProcessingQueue",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Movie video or subtitle URL missing"]
        )
      }
      return (videoURL, subtitleFile.url, subtitleFile.id)
    case .episode(let episodeID):
      guard let episode = try await jmlDatabaseClient.tvShowEpisode.fetch(.init(id: episodeID)),
            let videoURL = episode.japaneseVideoLocalURL,
            let subtitleFile = episode.japaneseSubtitleFile else {
        throw NSError(
          domain: "ProcessingQueue",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Episode video or subtitle URL missing"]
        )
      }
      return (videoURL, subtitleFile.url, subtitleFile.id)
    }
  }

  private static func loadEnglishTranslationsIfPresent(subtitleURL: URL) -> [Int: String] {
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

  private static func resolveTitle(
    for reference: MediaSourceModel.JMLMediaReference,
    jmlDatabaseClient: JMLDatabaseClient
  ) async -> String {
    switch reference {
    case .movie(let movieID):
      guard let movie = try? await jmlDatabaseClient.movie.fetch(.init(id: movieID)) else {
        return "Movie"
      }
      return movie.titleEnglish
        ?? movie.titleJapaneseRomanized
        ?? movie.titleJapanese
        ?? "Movie"

    case .episode(let episodeID):
      guard let episode = try? await jmlDatabaseClient.tvShowEpisode.fetch(.init(id: episodeID)) else {
        return "Episode"
      }
      let epNumber = episode.indexInSeason + 1
      let epName = episode.titleEnglish ?? episode.titleJapaneseRomanized ?? episode.titleJapanese

      guard let season = try? await jmlDatabaseClient.tvShowSeason.fetch(.init(id: episode.seasonID)) else {
        if let epName { return "E\(epNumber) – \(epName)" }
        return "Episode \(epNumber)"
      }
      let seasonNumber = season.indexInSeries + 1

      guard let series = try? await jmlDatabaseClient.tvShowSeries.fetch(.init(id: season.seriesID)) else {
        if let epName { return "S\(seasonNumber)E\(epNumber) – \(epName)" }
        return "S\(seasonNumber)E\(epNumber)"
      }
      let seriesName = series.titleEnglish ?? series.titleJapaneseRomanized ?? series.titleJapanese ?? "Series"

      if let epName {
        return "\(seriesName) S\(seasonNumber)E\(epNumber) – \(epName)"
      }
      return "\(seriesName) S\(seasonNumber)E\(epNumber)"
    }
  }
}
