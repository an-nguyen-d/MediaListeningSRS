import Foundation
import ElixirShared
import IYO_DictionaryClient
import IYO_DictionaryModels
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
protocol CandidateDetailInteractorProtocol {
  func sendAction(_ action: CandidateDetailModels.Action)
}

@MainActor
final class CandidateDetailInteractor: CandidateDetailInteractorProtocol {

  let presenter: CandidateDetailPresenter
  private let candidateID: MediaSourceCardCandidateModel.ID
  private let mediaSourceID: MediaSourceModel.ID

  private let mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient
  private let jmlDatabaseClient: JMLDatabaseClient
  #if targetEnvironment(macCatalyst)
  private let metgDatabaseClient: METGDatabaseClient
  #endif
  private let dictionaryClient: DictionaryClient
  private let srtParserClient: SRTParserClient
  private let clipExportService: ClipExportService
  private let clipStorageClient: ClipStorageClient
  private let exportedClipsDirectoryURL: URL

  private var videoFileURL: URL?
  private var subtitleSegmentsByIndex: [Int: SubtitleSegment] = [:]
  private var labelsBySubtitleIndex: [Int: [JapaneseTermLabelModel]] = [:]
  private var englishTranslationsByIndex: [Int: String] = [:]
  private var fullyKnownTermIDs: Set<Int64> = []
  private var termLinksBySubtitleIndex: [Int: [TermInflectionPair]] = [:]
  private var maxIndex: Int = 0
  private var startSubtitleIndex: Int = 0
  private var endSubtitleIndex: Int = 0
  private var customStartTime: TimeInterval = 0
  private var customEndTime: TimeInterval = 0

  #if targetEnvironment(macCatalyst)
  init(
    presenter: CandidateDetailPresenter,
    candidateID: MediaSourceCardCandidateModel.ID,
    mediaSourceID: MediaSourceModel.ID,
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    jmlDatabaseClient: JMLDatabaseClient,
    metgDatabaseClient: METGDatabaseClient,
    dictionaryClient: DictionaryClient,
    srtParserClient: SRTParserClient,
    clipExportService: ClipExportService,
    clipStorageClient: ClipStorageClient,
    exportedClipsDirectoryURL: URL
  ) {
    self.presenter = presenter
    self.candidateID = candidateID
    self.mediaSourceID = mediaSourceID
    self.mediaListeningSRSDatabaseClient = mediaListeningSRSDatabaseClient
    self.jmlDatabaseClient = jmlDatabaseClient
    self.metgDatabaseClient = metgDatabaseClient
    self.dictionaryClient = dictionaryClient
    self.srtParserClient = srtParserClient
    self.clipExportService = clipExportService
    self.clipStorageClient = clipStorageClient
    self.exportedClipsDirectoryURL = exportedClipsDirectoryURL
  }
  #else
  init(
    presenter: CandidateDetailPresenter,
    candidateID: MediaSourceCardCandidateModel.ID,
    mediaSourceID: MediaSourceModel.ID,
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    jmlDatabaseClient: JMLDatabaseClient,
    dictionaryClient: DictionaryClient,
    srtParserClient: SRTParserClient,
    clipExportService: ClipExportService,
    clipStorageClient: ClipStorageClient,
    exportedClipsDirectoryURL: URL
  ) {
    self.presenter = presenter
    self.candidateID = candidateID
    self.mediaSourceID = mediaSourceID
    self.mediaListeningSRSDatabaseClient = mediaListeningSRSDatabaseClient
    self.jmlDatabaseClient = jmlDatabaseClient
    self.dictionaryClient = dictionaryClient
    self.srtParserClient = srtParserClient
    self.clipExportService = clipExportService
    self.clipStorageClient = clipStorageClient
    self.exportedClipsDirectoryURL = exportedClipsDirectoryURL
  }
  #endif

  func sendAction(_ action: CandidateDetailModels.Action) {
    switch action {
    case .viewDidLoad:
      handleViewDidLoad()
    case .endSubtitleIndexChanged(let newEnd):
      handleEndSubtitleIndexChanged(newEnd)
    case .startTimeAdjusted(let delta):
      customStartTime = max(0, customStartTime + delta)
      if customEndTime < customStartTime { customEndTime = customStartTime + 0.1 }
      emitViewModel()
    case .endTimeAdjusted(let delta):
      customEndTime = max(customStartTime + 0.1, customEndTime + delta)
      emitViewModel()
    case .termTapped(let termID):
      handleTermTapped(termID)
    case .markTermAsFullyKnown(let termID):
      handleMarkTermAsFullyKnown(termID)
    case .skipTapped:
      handleSkipTapped()
    case .confirmTapped:
      handleConfirmTapped()
    }
  }

  private func handleMarkTermAsFullyKnown(_ termID: Int64) {
    Task { [mediaListeningSRSDatabaseClient, presenter] in
      do {
        _ = try await mediaListeningSRSDatabaseClient.japaneseTerm.markAsFullyKnown(
          .init(japaneseTermID: termID)
        )
        await MainActor.run {
          self.fullyKnownTermIDs.insert(termID)
          self.emitViewModel()
        }
      } catch {
        await MainActor.run {
          presenter.presentError("Mark known failed: \(error.localizedDescription)")
        }
      }
    }
  }

  private func handleViewDidLoad() {
    let candidateID = self.candidateID
    let mediaSourceID = self.mediaSourceID
    Task { [mediaListeningSRSDatabaseClient, jmlDatabaseClient, srtParserClient, presenter] in
      do {
        let candidatesStream = try await mediaListeningSRSDatabaseClient.mediaSourceCardCandidate.observeForSource(
          .init(mediaSourceID: mediaSourceID)
        )
        var candidates: [MediaSourceCardCandidateModel] = []
        for try await batch in candidatesStream {
          candidates = batch
          break
        }
        guard let candidate = candidates.first(where: { $0.id == candidateID }) else {
          await MainActor.run { presenter.presentError("Candidate not found") }
          return
        }

        let mediaSourceResponse = try await mediaListeningSRSDatabaseClient.mediaSource.fetch(
          .init(id: mediaSourceID)
        )

        let resolved = try await Self.resolveURLs(
          for: mediaSourceResponse.model.jmlMediaReference,
          jmlDatabaseClient: jmlDatabaseClient
        )

        let srtContent = try String(contentsOf: resolved.subtitleURL, encoding: .utf8)
        let segments = srtParserClient.parse(.init(content: srtContent))
        let segmentsByIndex = Dictionary(uniqueKeysWithValues: segments.map { ($0.index.rawValue, $0) })
        let maxIndex = segments.map(\.index.rawValue).max() ?? candidate.subtitleIndex

        guard let firstSegment = segmentsByIndex[candidate.subtitleIndex] else {
          await MainActor.run {
            presenter.presentError("Subtitle index \(candidate.subtitleIndex) not in .srt")
          }
          return
        }

        let translationsByIndex = Self.loadEnglishTranslationsIfPresent(
          subtitleURL: resolved.subtitleURL
        )

        var labelsBySubtitleIndex: [Int: [JapaneseTermLabelModel]] = [:]
        #if targetEnvironment(macCatalyst)
        let mwbtResp = try await metgDatabaseClient.mediaSubtitlesList.fetchByFileIDs(
          .init(fileIDs: [resolved.subtitleLocalizedLocalFileID])
        )
        if let row = mwbtResp.subtitles.first {
          for label in row.labels {
            labelsBySubtitleIndex[label.subtitleIndex.rawValue, default: []].append(label)
          }
        }
        #endif

        let allTermIDs = Set(labelsBySubtitleIndex.values.flatMap { $0 }.map { $0.japaneseTermID.rawValue })
        let knownResp = try await mediaListeningSRSDatabaseClient.japaneseTerm.fetchFullyKnownTermIDs(
          .init(japaneseTermIDs: Array(allTermIDs))
        )

        let termLinksResp = try await mediaListeningSRSDatabaseClient.mediaSourceCardCandidate.fetchTermLinksForSource(
          .init(mediaSourceID: mediaSourceID)
        )

        await MainActor.run {
          self.videoFileURL = resolved.videoURL
          self.subtitleSegmentsByIndex = segmentsByIndex
          self.labelsBySubtitleIndex = labelsBySubtitleIndex
          self.englishTranslationsByIndex = translationsByIndex
          self.fullyKnownTermIDs = knownResp.fullyKnownTermIDs
          self.termLinksBySubtitleIndex = termLinksResp.termLinksBySubtitleIndex
          self.maxIndex = maxIndex
          self.startSubtitleIndex = candidate.subtitleIndex
          self.endSubtitleIndex = candidate.subtitleIndex
          self.customStartTime = firstSegment.startTime
          self.customEndTime = firstSegment.endTime
          presenter.presentVideoFile(url: resolved.videoURL)
          self.emitViewModel()
        }
      } catch {
        await MainActor.run { presenter.presentError("Failed to load: \(error.localizedDescription)") }
      }
    }
  }

  private func handleEndSubtitleIndexChanged(_ newEnd: Int) {
    let clamped = max(startSubtitleIndex, min(newEnd, maxIndex))
    endSubtitleIndex = clamped
    if let endSeg = subtitleSegmentsByIndex[clamped] {
      customEndTime = endSeg.endTime
    }
    if let startSeg = subtitleSegmentsByIndex[startSubtitleIndex] {
      customStartTime = startSeg.startTime
    }
    emitViewModel()
  }

  private func handleTermTapped(_ termID: Int64) {
    Task { [dictionaryClient, mediaListeningSRSDatabaseClient, presenter] in
      do {
        guard let lookup = try await dictionaryClient.lookupByID(.init(termID: Int(termID))) else {
          await MainActor.run {
            presenter.presentError("No dictionary entry for term \(termID)")
          }
          return
        }
        let viewModel = IYomiDictionaryViewModelBridge.makeLookupViewModel(from: lookup)
        let isKnownResp = try await mediaListeningSRSDatabaseClient.japaneseTerm.isFullyKnown(
          .init(japaneseTermID: termID)
        )
        await MainActor.run {
          presenter.presentDictionaryLookup(.init(
            japaneseTermID: termID,
            viewModel: viewModel,
            isAlreadyFullyKnown: isKnownResp.isFullyKnown
          ))
        }
      } catch {
        await MainActor.run {
          presenter.presentError("Dictionary lookup failed: \(error.localizedDescription)")
        }
      }
    }
  }

  private func handleSkipTapped() {
    let candidateID = self.candidateID
    Task { [mediaListeningSRSDatabaseClient, presenter] in
      do {
        _ = try await mediaListeningSRSDatabaseClient.mediaSourceCardCandidate.setSkipped(
          .init(id: candidateID, isSkipped: true)
        )
        await MainActor.run { presenter.presentDismiss() }
      } catch {
        await MainActor.run { presenter.presentError("Skip failed: \(error.localizedDescription)") }
      }
    }
  }

  private func handleConfirmTapped() {
    guard let videoFileURL = self.videoFileURL else {
      presenter.presentError("Video URL not resolved")
      return
    }
    let mediaSourceID = self.mediaSourceID
    let startIndex = self.startSubtitleIndex
    let endIndex = self.endSubtitleIndex
    let startTime = self.customStartTime
    let endTime = self.customEndTime

    var japaneseTermLinks: Set<TermInflectionPair> = []
    for index in startIndex...endIndex {
      for pair in termLinksBySubtitleIndex[index] ?? [] {
        japaneseTermLinks.insert(pair)
      }
    }

    let transcriptParts = (startIndex...endIndex).compactMap { subtitleSegmentsByIndex[$0]?.text }
    let transcriptText = transcriptParts.joined(separator: "\n")
    let translationParts = (startIndex...endIndex).compactMap { englishTranslationsByIndex[$0] }
    let translationText = translationParts.joined(separator: "\n")

    var subtitleTextsByIndex: [Int: String] = [:]
    var labelInputsByIndex: [Int: [SRSCardLabelRange.SubtitleLabelInput]] = [:]
    for index in startIndex...endIndex {
      guard let seg = subtitleSegmentsByIndex[index] else { continue }
      subtitleTextsByIndex[index] = seg.text
      labelInputsByIndex[index] = (labelsBySubtitleIndex[index] ?? []).map { label in
        .init(
          range: label.range,
          termID: label.japaneseTermID.rawValue,
          inflectionKey: termLinksBySubtitleIndex[index]?
            .first(where: { $0.japaneseTermID == label.japaneseTermID.rawValue })?
            .inflectionKey ?? ""
        )
      }
    }
    let labelRanges = SRSCardLabelRange.buildFromSubtitles(
      indexRange: startIndex...endIndex,
      subtitleTextsByIndex: subtitleTextsByIndex,
      labelsByIndex: labelInputsByIndex
    )

    let outputFileURL = exportedClipsDirectoryURL
      .appendingPathComponent("\(mediaSourceID.rawValue)", isDirectory: true)
      .appendingPathComponent("\(UUID().uuidString).mp4", isDirectory: false)

    Task { [mediaListeningSRSDatabaseClient, clipExportService, clipStorageClient, exportedClipsDirectoryURL, presenter] in
      do {
        let createResponse = try await mediaListeningSRSDatabaseClient.srsCard.create(.init(
          mediaSourceID: mediaSourceID,
          subtitleIndexStart: startIndex,
          subtitleIndexEnd: endIndex,
          clipStartTimeSeconds: startTime,
          clipEndTimeSeconds: endTime,
          clipRelativeFilePath: "",
          cachedTranscriptText: transcriptText,
          cachedEnglishTranslation: translationText,
          japaneseTermLinks: Array(japaneseTermLinks),
          labelRanges: labelRanges
        ))
        let cardID = createResponse.model.id

        await MainActor.run { presenter.presentDismiss() }

        await ClipExportManager.shared.enqueue(
          request: .init(
            sourceVideoFileURL: videoFileURL,
            startTimeSeconds: startTime,
            endTimeSeconds: endTime,
            outputFileURL: outputFileURL
          ),
          exportClip: clipExportService.exportClip,
          onComplete: { exportedFileURL in
            let relativePath = exportedFileURL.path.replacingOccurrences(
              of: exportedClipsDirectoryURL.path,
              with: ""
            ).trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            do {
              _ = try await mediaListeningSRSDatabaseClient.srsCard.updateClipPath(.init(
                cardID: cardID,
                clipRelativeFilePath: relativePath
              ))
              print("[ClipExportManager] Clip ready for card \(cardID.rawValue): \(relativePath)")
            } catch {
              print("[ClipExportManager] DB update failed for card \(cardID.rawValue): \(error)")
              return
            }

            #if targetEnvironment(macCatalyst)
            let remotePath = "clips/\(relativePath)"
            do {
              _ = try await clipStorageClient.upload(.init(
                localFileURL: exportedFileURL,
                remotePath: remotePath
              ))
              print("[ClipStorage] Uploaded \(remotePath)")
            } catch {
              print("[ClipStorage] Upload failed for \(remotePath): \(error)")
            }

            let thumbnailURL = exportedFileURL.deletingPathExtension().appendingPathExtension("jpg")
            if FileManager.default.fileExists(atPath: thumbnailURL.path) {
              let thumbRemotePath = "clips/\(relativePath.replacingOccurrences(of: ".mp4", with: ".jpg"))"
              do {
                _ = try await clipStorageClient.upload(.init(
                  localFileURL: thumbnailURL,
                  remotePath: thumbRemotePath
                ))
                print("[ClipStorage] Uploaded thumbnail \(thumbRemotePath)")
              } catch {
                print("[ClipStorage] Thumbnail upload failed: \(error)")
              }
            }
            #endif
          }
        )
      } catch {
        await MainActor.run {
          presenter.presentError("Card creation failed: \(error.localizedDescription)")
        }
      }
    }
  }

  private func emitViewModel() {
    let startSeg = subtitleSegmentsByIndex[startSubtitleIndex]
    let endSeg = subtitleSegmentsByIndex[endSubtitleIndex]

    var subtitleTextsByIndex: [Int: String] = [:]
    var labelInputsByIndex: [Int: [SRSCardLabelRange.SubtitleLabelInput]] = [:]
    var joinedParts: [String] = []
    for index in startSubtitleIndex...endSubtitleIndex {
      guard let seg = subtitleSegmentsByIndex[index] else { continue }
      subtitleTextsByIndex[index] = seg.text
      labelInputsByIndex[index] = (labelsBySubtitleIndex[index] ?? []).map { label in
        .init(
          range: label.range,
          termID: label.japaneseTermID.rawValue,
          inflectionKey: termLinksBySubtitleIndex[index]?
            .first(where: { $0.japaneseTermID == label.japaneseTermID.rawValue })?
            .inflectionKey ?? ""
        )
      }
      joinedParts.append(seg.text)
    }
    let joinedText = joinedParts.joined(separator: "\n")

    let cardLabelRanges = SRSCardLabelRange.buildFromSubtitles(
      indexRange: startSubtitleIndex...endSubtitleIndex,
      subtitleTextsByIndex: subtitleTextsByIndex,
      labelsByIndex: labelInputsByIndex
    )
    let labeledRanges = cardLabelRanges.toHighlightableRanges(fullyKnownTermIDs: fullyKnownTermIDs)

    let translationParts = (startSubtitleIndex...endSubtitleIndex)
      .compactMap { englishTranslationsByIndex[$0] }
    let translationText = translationParts.isEmpty ? nil : translationParts.joined(separator: "\n")

    let inflectionAnnotations = HighlightableTranscriptLabeledRange.buildInflectionAnnotationsText(
      transcriptText: joinedText,
      labeledRanges: labeledRanges
    )

    presenter.presentViewModel(.init(
      subtitleIndexStart: startSubtitleIndex,
      subtitleIndexEnd: endSubtitleIndex,
      subtitleText: joinedText,
      labeledRanges: labeledRanges,
      inflectionAnnotationsText: inflectionAnnotations,
      englishTranslationText: translationText,
      defaultStartTime: startSeg?.startTime ?? 0,
      defaultEndTime: endSeg?.endTime ?? 0,
      customStartTime: customStartTime,
      customEndTime: customEndTime,
      maxAvailableEndIndex: maxIndex
    ))
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
          domain: "CandidateDetail",
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
          domain: "CandidateDetail",
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
}
