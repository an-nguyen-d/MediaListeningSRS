import Foundation
import ElixirShared
import IYO_DictionaryClient
import IYO_DictionaryModels
import IYO_JapaneseParserClient
import JML_JMLDatabaseClient
import JML_JMLSharedModels
import METG_METGDatabaseClient
import METG_SharedModels
import MSRS_ClipExportService
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
  private let metgDatabaseClient: METGDatabaseClient
  private let dictionaryClient: DictionaryClient
  private let japaneseParserClient: JapaneseParserClient
  private let srtParserClient: SRTParserClient
  private let clipExportService: ClipExportService
  private let exportedClipsDirectoryURL: URL

  private var videoFileURL: URL?
  private var subtitleSegmentsByIndex: [Int: SubtitleSegment] = [:]
  private var labelsBySubtitleIndex: [Int: [JapaneseTermLabelModel]] = [:]
  private var englishTranslationsByIndex: [Int: String] = [:]
  private var fullyKnownTermIDs: Set<Int64> = []
  private var inflectionKeysByLabel: [Int64: String] = [:]
  private var maxIndex: Int = 0
  private var startSubtitleIndex: Int = 0
  private var endSubtitleIndex: Int = 0
  private var customStartTime: TimeInterval = 0
  private var customEndTime: TimeInterval = 0

  init(
    presenter: CandidateDetailPresenter,
    candidateID: MediaSourceCardCandidateModel.ID,
    mediaSourceID: MediaSourceModel.ID,
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    jmlDatabaseClient: JMLDatabaseClient,
    metgDatabaseClient: METGDatabaseClient,
    dictionaryClient: DictionaryClient,
    japaneseParserClient: JapaneseParserClient,
    srtParserClient: SRTParserClient,
    clipExportService: ClipExportService,
    exportedClipsDirectoryURL: URL
  ) {
    self.presenter = presenter
    self.candidateID = candidateID
    self.mediaSourceID = mediaSourceID
    self.mediaListeningSRSDatabaseClient = mediaListeningSRSDatabaseClient
    self.jmlDatabaseClient = jmlDatabaseClient
    self.metgDatabaseClient = metgDatabaseClient
    self.dictionaryClient = dictionaryClient
    self.japaneseParserClient = japaneseParserClient
    self.srtParserClient = srtParserClient
    self.clipExportService = clipExportService
    self.exportedClipsDirectoryURL = exportedClipsDirectoryURL
  }

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
    Task { [
      mediaListeningSRSDatabaseClient,
      jmlDatabaseClient,
      metgDatabaseClient,
      srtParserClient,
      japaneseParserClient,
      presenter
    ] in
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

        let mwbtResp = try await metgDatabaseClient.mediaSubtitlesList.fetchByFileIDs(
          .init(fileIDs: [resolved.subtitleLocalizedLocalFileID])
        )
        var labelsBySubtitleIndex: [Int: [JapaneseTermLabelModel]] = [:]
        if let row = mwbtResp.subtitles.first {
          for label in row.labels {
            labelsBySubtitleIndex[label.subtitleIndex.rawValue, default: []].append(label)
          }
        }

        // Pre-fetch fully-known status for every tagged word across the source.
        let allTermIDs = Set(labelsBySubtitleIndex.values.flatMap { $0 }.map { $0.japaneseTermID.rawValue })
        let knownResp = try await mediaListeningSRSDatabaseClient.japaneseTerm.fetchFullyKnownTermIDs(
          .init(japaneseTermIDs: Array(allTermIDs))
        )

        // Derive inflection keys for all labels.
        let allLabelInfos: [InflectionDerivationHelper.LabelInfo] = labelsBySubtitleIndex.flatMap { (idx, labels) in
          labels.map { label in
            InflectionDerivationHelper.LabelInfo(
              subtitleIndex: idx,
              utf16Range: label.range,
              japaneseTermID: label.japaneseTermID.rawValue
            )
          }
        }
        var segTexts: [Int: String] = [:]
        for (idx, seg) in segmentsByIndex { segTexts[idx] = seg.text }

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
          labels: allLabelInfos,
          segmentTextsByIndex: segTexts,
          prefixLookup: prefixLookup
        )
        var inflectionKeysByLabel: [Int64: String] = [:]
        for (_, pairs) in derivedPairsByIndex {
          for pair in pairs {
            inflectionKeysByLabel[pair.japaneseTermID] = pair.inflectionKey
          }
        }

        await MainActor.run {
          self.videoFileURL = resolved.videoURL
          self.subtitleSegmentsByIndex = segmentsByIndex
          self.labelsBySubtitleIndex = labelsBySubtitleIndex
          self.englishTranslationsByIndex = translationsByIndex
          self.fullyKnownTermIDs = knownResp.fullyKnownTermIDs
          self.inflectionKeysByLabel = inflectionKeysByLabel
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

    var labelInfos: [InflectionDerivationHelper.LabelInfo] = []
    var segmentTextsByIndex: [Int: String] = [:]
    for index in startIndex...endIndex {
      if let seg = subtitleSegmentsByIndex[index] {
        segmentTextsByIndex[index] = seg.text
      }
      for label in labelsBySubtitleIndex[index] ?? [] {
        labelInfos.append(.init(
          subtitleIndex: index,
          utf16Range: label.range,
          japaneseTermID: label.japaneseTermID.rawValue
        ))
      }
    }

    let outputFileURL = exportedClipsDirectoryURL
      .appendingPathComponent("\(mediaSourceID.rawValue)", isDirectory: true)
      .appendingPathComponent("\(UUID().uuidString).mp4", isDirectory: false)

    Task { [mediaListeningSRSDatabaseClient, clipExportService, japaneseParserClient, exportedClipsDirectoryURL, presenter] in
      do {
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
        let japaneseTermLinks = Array(Set(derivedPairsByIndex.values.flatMap { $0 }))

        _ = try await clipExportService.exportClip(.init(
          sourceVideoFileURL: videoFileURL,
          startTimeSeconds: startTime,
          endTimeSeconds: endTime,
          outputFileURL: outputFileURL
        ))

        let relativePath = outputFileURL.path.replacingOccurrences(
          of: exportedClipsDirectoryURL.path,
          with: ""
        ).trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        _ = try await mediaListeningSRSDatabaseClient.srsCard.create(.init(
          mediaSourceID: mediaSourceID,
          subtitleIndexStart: startIndex,
          subtitleIndexEnd: endIndex,
          clipStartTimeSeconds: startTime,
          clipEndTimeSeconds: endTime,
          clipRelativeFilePath: relativePath,
          japaneseTermLinks: japaneseTermLinks
        ))

        await MainActor.run { presenter.presentDismiss() }
      } catch {
        await MainActor.run {
          presenter.presentError("Confirm failed: \(error.localizedDescription)")
        }
      }
    }
  }

  private func emitViewModel() {
    let startSeg = subtitleSegmentsByIndex[startSubtitleIndex]
    let endSeg = subtitleSegmentsByIndex[endSubtitleIndex]

    var joinedParts: [String] = []
    var labeledRanges: [HighlightableTranscriptLabeledRange] = []
    var runningUTF16Offset: Int = 0
    for index in startSubtitleIndex...endSubtitleIndex {
      guard let seg = subtitleSegmentsByIndex[index] else { continue }
      let text = seg.text
      let textUTF16Length = text.utf16.count
      for label in labelsBySubtitleIndex[index] ?? [] {
        let length = label.range.upperBound - label.range.lowerBound
        guard label.range.lowerBound >= 0,
              label.range.lowerBound + length <= textUTF16Length else { continue }
        let termIDValue = label.japaneseTermID.rawValue
        labeledRanges.append(.init(
          range: NSRange(
            location: runningUTF16Offset + label.range.lowerBound,
            length: length
          ),
          termID: termIDValue,
          isFullyKnown: fullyKnownTermIDs.contains(termIDValue),
          inflectionKey: inflectionKeysByLabel[termIDValue] ?? ""
        ))
      }
      joinedParts.append(text)
      runningUTF16Offset += textUTF16Length
      if index < endSubtitleIndex {
        runningUTF16Offset += 1
      }
    }
    let joinedText = joinedParts.joined(separator: "\n")

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
