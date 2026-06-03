import Foundation
import ElixirShared
import IYO_DictionaryClient
import IYO_DictionaryModels
import IYO_DictionaryUIKit
import IYO_JapaneseModels
import IYO_JapaneseParserClient
import JML_JMLDatabaseClient
import JML_JMLSharedModels
#if targetEnvironment(macCatalyst)
import METG_METGDatabaseClient
import METG_SharedModels
#endif
import MSRS_ClipExportService
import MSRS_ClipStorageClient
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_Shared
import MSRS_SharedModels

@MainActor
protocol SRSCardReviewInteractorProtocol {
  func sendAction(_ action: SRSCardReviewModels.Action)
}

@MainActor
final class SRSCardReviewInteractor: SRSCardReviewInteractorProtocol {

  let presenter: SRSCardReviewPresenter
  private let mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient
  private let clipStorageClient: ClipStorageClient
  private let dictionaryClient: DictionaryClient
  private let japaneseParserClient: JapaneseParserClient
  private let exportedClipsDirectoryURL: URL

  #if targetEnvironment(macCatalyst)
  private let jmlDatabaseClient: JMLDatabaseClient
  private let metgDatabaseClient: METGDatabaseClient
  private let srtParserClient: SRTParserClient

  private struct SourceCache {
    let videoFileURL: URL
    let subtitleSegmentsByIndex: [Int: SubtitleSegment]
    let englishTranslationsByIndex: [Int: String]
    let mwbtLabelsBySubtitleIndex: [Int: [JapaneseTermLabelModel]]
  }
  private var sourceCachesByID: [MediaSourceModel.ID: SourceCache] = [:]
  #endif

  private static let batchSize = 5
  private static let prefetchCount = 2

  private var currentBatch: [SRSCardModel] = []
  private var currentBatchIndex: Int = 0
  private var totalReviewedCount: Int = 0

  private var fullyKnownTermIDs: Set<Int64> = []
  private let studySessionTracker: StudySessionTracker
  private var currentTranscriptText: String = ""
  private var currentEnglishTranslationText: String?

  #if targetEnvironment(macCatalyst)
  init(
    presenter: SRSCardReviewPresenter,
    clipStorageClient: ClipStorageClient,
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    jmlDatabaseClient: JMLDatabaseClient,
    metgDatabaseClient: METGDatabaseClient,
    dictionaryClient: DictionaryClient,
    japaneseParserClient: JapaneseParserClient,
    srtParserClient: SRTParserClient,
    exportedClipsDirectoryURL: URL
  ) {
    self.presenter = presenter
    self.clipStorageClient = clipStorageClient
    self.mediaListeningSRSDatabaseClient = mediaListeningSRSDatabaseClient
    self.jmlDatabaseClient = jmlDatabaseClient
    self.metgDatabaseClient = metgDatabaseClient
    self.dictionaryClient = dictionaryClient
    self.japaneseParserClient = japaneseParserClient
    self.srtParserClient = srtParserClient
    self.exportedClipsDirectoryURL = exportedClipsDirectoryURL
    self.studySessionTracker = StudySessionTracker(dbClient: mediaListeningSRSDatabaseClient)
  }
  #else
  init(
    presenter: SRSCardReviewPresenter,
    clipStorageClient: ClipStorageClient,
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    dictionaryClient: DictionaryClient,
    japaneseParserClient: JapaneseParserClient,
    exportedClipsDirectoryURL: URL
  ) {
    self.presenter = presenter
    self.clipStorageClient = clipStorageClient
    self.mediaListeningSRSDatabaseClient = mediaListeningSRSDatabaseClient
    self.dictionaryClient = dictionaryClient
    self.japaneseParserClient = japaneseParserClient
    self.exportedClipsDirectoryURL = exportedClipsDirectoryURL
    self.studySessionTracker = StudySessionTracker(dbClient: mediaListeningSRSDatabaseClient)
  }
  #endif

  func sendAction(_ action: SRSCardReviewModels.Action) {
    switch action {
    case .viewDidLoad:
      handleViewDidLoad()
    case .revealBackTapped:
      studySessionTracker.recordHeartbeat(isCardReview: false)
      presenter.presentRevealBack()
    case .replayTapped:
      presenter.presentReplay()
    case .termTapped(let termID):
      handleTermTapped(termID)
    case .markTermAsFullyKnown(let termID):
      handleMarkTermAsFullyKnown(termID)
    case .gradedAndNext(let grade):
      studySessionTracker.recordHeartbeat(isCardReview: true)
      handleGraded(grade)
    case .frontVideoVisibilityChanged(let visibility):
      handleFrontVideoVisibilityChanged(visibility)
    case .playbackSpeedChanged(let speed):
      handlePlaybackSpeedChanged(speed)
    case .submitTypedAnswer(let answer):
      studySessionTracker.recordHeartbeat(isCardReview: false)
      presenter.presentRevealBack()
      presenter.presentLLMGradingStarted(userAnswer: answer)
      handleLLMGrading(learnerAnswer: answer)
    case .transcriptTappedAtCharacterIndex(let index):
      handleTranscriptTappedAtCharacterIndex(index)
    case .autoLoopVideoChanged:
      persistSettings()
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
          self.emitCurrentCard()
        }
      } catch {
        await MainActor.run {
          presenter.presentError("Mark known failed: \(error.localizedDescription)")
        }
      }
    }
  }

  private func handleFrontVideoVisibilityChanged(_ visibility: SRSCardModel.FrontVideoVisibility) {
    guard currentBatchIndex < currentBatch.count else { return }
    let card = currentBatch[currentBatchIndex]
    currentBatch[currentBatchIndex].frontVideoVisibility = visibility
    Task { [mediaListeningSRSDatabaseClient] in
      try? await mediaListeningSRSDatabaseClient.srsCard.updateFrontVideoVisibility(
        .init(cardID: card.id, visibility: visibility)
      )
    }
  }

  private func handlePlaybackSpeedChanged(_ speed: Double) {
    guard currentBatchIndex < currentBatch.count else { return }
    let card = currentBatch[currentBatchIndex]
    currentBatch[currentBatchIndex].playbackSpeed = speed
    currentBatch[currentBatchIndex].consecutiveCorrectAtCurrentSpeed = 0
    Task { [mediaListeningSRSDatabaseClient] in
      try? await mediaListeningSRSDatabaseClient.srsCard.updatePlaybackSpeed(
        .init(cardID: card.id, speed: speed)
      )
    }
  }

  private func handleGraded(_ grade: SRSCardReviewModels.Grade) {
    guard currentBatchIndex < currentBatch.count else { return }
    let card = currentBatch[currentBatchIndex]
    let ratingRawValue: Int = (grade == .fail) ? 1 : 3
    Task { [mediaListeningSRSDatabaseClient, presenter] in
      do {
        _ = try await mediaListeningSRSDatabaseClient.srsCard.recordReview(
          .init(cardID: card.id, ratingRawValue: ratingRawValue)
        )
        await MainActor.run { self.advanceToNextCard() }
      } catch {
        await MainActor.run {
          presenter.presentError("Failed to record review: \(error.localizedDescription)")
        }
      }
    }
  }

  private func handleViewDidLoad() {
    fetchNextBatch()
  }

  private func advanceToNextCard() {
    totalReviewedCount += 1
    currentBatchIndex += 1
    if currentBatchIndex < currentBatch.count {
      emitCurrentCard()
    } else {
      fetchNextBatch()
    }
  }

  private func fetchNextBatch() {
    Task { [mediaListeningSRSDatabaseClient, presenter] in
      do {
        let response = try await mediaListeningSRSDatabaseClient.srsCard.fetchDueCards(
          .init(asOf: Date(), limit: Self.batchSize)
        )
        guard !response.cards.isEmpty else {
          await MainActor.run {
            if self.totalReviewedCount > 0 {
              presenter.presentDeckCompleted()
            } else {
              presenter.presentEmptyDeck()
            }
          }
          return
        }
        await MainActor.run {
          self.currentBatch = response.cards
          self.currentBatchIndex = 0
          self.emitCurrentCard()
        }
      } catch {
        await MainActor.run {
          presenter.presentError("Failed to load deck: \(error.localizedDescription)")
        }
      }
    }
  }

  private func handleTermTapped(_ termID: Int64) {
    Task { [dictionaryClient, mediaListeningSRSDatabaseClient, presenter] in
      do {
        guard let lookup = try await dictionaryClient.lookupByID(.init(termID: Int(termID))) else {
          await MainActor.run { presenter.presentError("No dictionary entry for term \(termID)") }
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

  private func emitCurrentCard() {
    guard currentBatchIndex < currentBatch.count else { return }
    let card = currentBatch[currentBatchIndex]
    Task { [weak self, mediaListeningSRSDatabaseClient, clipStorageClient, exportedClipsDirectoryURL] in
      guard let self else { return }
      let intervals = try? await mediaListeningSRSDatabaseClient.srsCard.previewNextIntervals(
        .init(cardID: card.id)
      )

      #if targetEnvironment(macCatalyst)
      do {
        let cache = try await self.ensureSourceCache(mediaSourceID: card.mediaSourceID)
        let termLinksResp = try await mediaListeningSRSDatabaseClient.srsCard.fetchTermLinksForCard(
          .init(cardID: card.id)
        )
        var inflectionKeysByTermID: [Int64: String] = [:]
        for link in termLinksResp.termLinks {
          inflectionKeysByTermID[link.japaneseTermID] = link.inflectionKey
        }
        let transcriptText = card.cachedTranscriptText
        let translationText = card.cachedEnglishTranslation.isEmpty ? nil : card.cachedEnglishTranslation

        var labeledRanges: [HighlightableTranscriptLabeledRange] = []
        var runningUTF16Offset: Int = 0
        for index in card.subtitleIndexStart...card.subtitleIndexEnd {
          guard let seg = cache.subtitleSegmentsByIndex[index] else { continue }
          let text = seg.text
          let textUTF16Length = text.utf16.count
          for label in cache.mwbtLabelsBySubtitleIndex[index] ?? [] {
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
              inflectionKey: inflectionKeysByTermID[termIDValue] ?? ""
            ))
          }
          runningUTF16Offset += textUTF16Length
          if index < card.subtitleIndexEnd {
            runningUTF16Offset += 1
          }
        }

        await MainActor.run {
          self.buildAndPresent(
            card: card,
            transcriptText: transcriptText,
            translationText: translationText,
            labeledRanges: labeledRanges,
            failIntervalSeconds: intervals?.failIntervalSeconds,
            passIntervalSeconds: intervals?.passIntervalSeconds
          )
        }
      } catch {
        await MainActor.run {
          self.presenter.presentError("Failed to load source data: \(error.localizedDescription)")
        }
      }

      #else
      let transcriptText = card.cachedTranscriptText
      let translationText = card.cachedEnglishTranslation.isEmpty ? nil : card.cachedEnglishTranslation

      let clipFileURL = exportedClipsDirectoryURL.appendingPathComponent(card.clipRelativeFilePath)
      if !FileManager.default.fileExists(atPath: clipFileURL.path) {
        await MainActor.run { self.presenter.presentClipDownloading() }
        let remotePath = "clips/\(card.clipRelativeFilePath)"
        do {
          _ = try await clipStorageClient.download(.init(
            remotePath: remotePath,
            localFileURL: clipFileURL
          ))
        } catch {
          await MainActor.run {
            self.presenter.presentError("Failed to download clip: \(error.localizedDescription)")
          }
          return
        }

        let thumbnailURL = clipFileURL.deletingPathExtension().appendingPathExtension("jpg")
        let thumbRemotePath = "clips/\(card.clipRelativeFilePath.replacingOccurrences(of: ".mp4", with: ".jpg"))"
        _ = try? await clipStorageClient.download(.init(
          remotePath: thumbRemotePath,
          localFileURL: thumbnailURL
        ))
      }

      await MainActor.run {
        self.buildAndPresent(
          card: card,
          transcriptText: transcriptText,
          translationText: translationText,
          labeledRanges: [],
          failIntervalSeconds: intervals?.failIntervalSeconds,
          passIntervalSeconds: intervals?.passIntervalSeconds
        )
        self.prefetchUpcomingCards()
      }
      #endif
    }
  }

  private func buildAndPresent(
    card: SRSCardModel,
    transcriptText: String,
    translationText: String?,
    labeledRanges: [HighlightableTranscriptLabeledRange],
    failIntervalSeconds: TimeInterval? = nil,
    passIntervalSeconds: TimeInterval? = nil
  ) {
    self.currentTranscriptText = transcriptText
    self.currentEnglishTranslationText = translationText

    let clipFileURL = exportedClipsDirectoryURL.appendingPathComponent(card.clipRelativeFilePath)
    let thumbnailFileURL = clipFileURL.deletingPathExtension().appendingPathExtension("jpg")

    let inflectionAnnotationsText = HighlightableTranscriptLabeledRange.buildInflectionAnnotationsText(
      transcriptText: transcriptText,
      labeledRanges: labeledRanges
    )

    presenter.presentCard(.init(
      cardID: card.id,
      videoFileURL: clipFileURL,
      clipStartTimeSeconds: 0,
      clipEndTimeSeconds: card.clipEndTimeSeconds - card.clipStartTimeSeconds,
      transcriptText: transcriptText,
      transcriptLabeledRanges: labeledRanges,
      inflectionAnnotationsText: inflectionAnnotationsText,
      englishTranslationText: translationText,
      cardPositionLabel: "#\(totalReviewedCount + currentBatchIndex + 1)",
      frontVideoVisibility: card.frontVideoVisibility,
      thumbnailFileURL: thumbnailFileURL,
      playbackSpeed: card.playbackSpeed,
      consecutiveCorrectAtCurrentSpeed: card.consecutiveCorrectAtCurrentSpeed,
      failIntervalSeconds: failIntervalSeconds,
      passIntervalSeconds: passIntervalSeconds
    ))
  }

  private func handleLLMGrading(learnerAnswer: String) {
    let transcript = currentTranscriptText
    let translation = currentEnglishTranslationText
    Task { [presenter] in
      do {
        let result = try await OllamaGradingHelper.grade(
          japaneseTranscript: transcript,
          englishTranslation: translation,
          learnerResponse: learnerAnswer
        )
        await MainActor.run {
          presenter.presentLLMGradeResult(.init(
            score: result.score,
            reasoning: result.reasoning
          ))
        }
      } catch {
        await MainActor.run {
          presenter.presentLLMGradingError(error.localizedDescription)
        }
      }
    }
  }

  // MARK: - On-tap prefix lookup

  private static let maxPrefixLookupResults = 5

  private func handleTranscriptTappedAtCharacterIndex(_ utf16Offset: Int) {
    let text = currentTranscriptText
    guard !text.isEmpty else { return }
    let nsText = text as NSString
    guard utf16Offset >= 0, utf16Offset < nsText.length else { return }

    let tappedChar = Character(UnicodeScalar(nsText.character(at: utf16Offset))!)
    if tappedChar.isNewline || tappedChar.isWhitespace || tappedChar.isASCII { return }

    let swiftIndex = String.Index(utf16Offset: utf16Offset, in: text)
    let remaining = String(text[swiftIndex...].prefix(15))
    guard !remaining.isEmpty else { return }

    Task { [japaneseParserClient, mediaListeningSRSDatabaseClient, presenter] in
      do {
        let response = try await japaneseParserClient.prefixDictionaryLookup(
          .init(text: remaining, maxResultCount: Self.maxPrefixLookupResults)
        )
        let topResults = Array(response.lookupResults.prefix(Self.maxPrefixLookupResults))
        guard let firstResult = topResults.first else { return }

        let termID = Int64(firstResult.dictionaryID)
        let surfaceUTF16Length = firstResult.surfaceText.utf16.count
        let tappedRange = NSRange(location: utf16Offset, length: surfaceUTF16Length)

        let resultVMs = topResults.map { result in
          IYomiDictionaryViewModelBridge.makeResultViewModel(
            from: result.dictionaryLookupResult,
            surfaceText: result.surfaceText,
            deinflectedText: result.deinflectedText,
            inflections: result.inflections,
            matchedTextLength: result.matchedTextLength
          )
        }
        let viewModel = DictionaryLookupViewModel(results: resultVMs)

        let isKnownResp = try await mediaListeningSRSDatabaseClient.japaneseTerm.isFullyKnown(
          .init(japaneseTermID: termID)
        )

        await MainActor.run {
          presenter.presentDictionaryLookup(.init(
            japaneseTermID: termID,
            viewModel: viewModel,
            isAlreadyFullyKnown: isKnownResp.isFullyKnown,
            tappedRange: tappedRange
          ))
        }
      } catch {
        await MainActor.run {
          presenter.presentError("Dictionary lookup failed: \(error.localizedDescription)")
        }
      }
    }
  }

  #if !targetEnvironment(macCatalyst)
  private func prefetchUpcomingCards() {
    let startIndex = currentBatchIndex + 1
    let endIndex = min(startIndex + Self.prefetchCount, currentBatch.count)
    guard startIndex < endIndex else { return }

    let upcoming = currentBatch[startIndex..<endIndex]
    let clipsDir = exportedClipsDirectoryURL
    let storageClient = clipStorageClient

    for card in upcoming {
      let clipFileURL = clipsDir.appendingPathComponent(card.clipRelativeFilePath)
      guard !FileManager.default.fileExists(atPath: clipFileURL.path) else { continue }

      Task.detached(priority: .utility) {
        let remotePath = "clips/\(card.clipRelativeFilePath)"
        _ = try? await storageClient.download(.init(
          remotePath: remotePath,
          localFileURL: clipFileURL
        ))
        let thumbRemotePath = "clips/\(card.clipRelativeFilePath.replacingOccurrences(of: ".mp4", with: ".jpg"))"
        let thumbnailURL = clipFileURL.deletingPathExtension().appendingPathExtension("jpg")
        _ = try? await storageClient.download(.init(
          remotePath: thumbRemotePath,
          localFileURL: thumbnailURL
        ))
      }
    }
  }
  #endif

  private func persistSettings() {
    let model = MSRSAppSettings.currentModel()
    Task { [mediaListeningSRSDatabaseClient] in
      try? await mediaListeningSRSDatabaseClient.appSettings.update(.init(model: model))
    }
  }

  // MARK: - Mac Catalyst source cache

  #if targetEnvironment(macCatalyst)
  private func ensureSourceCache(mediaSourceID: MediaSourceModel.ID) async throws -> SourceCache {
    if let cached = sourceCachesByID[mediaSourceID] { return cached }
    let sourceResp = try await mediaListeningSRSDatabaseClient.mediaSource.fetch(.init(id: mediaSourceID))
    let resolved = try await Self.resolveURLs(
      for: sourceResp.model.jmlMediaReference,
      jmlDatabaseClient: jmlDatabaseClient
    )
    let srtContent = try String(contentsOf: resolved.subtitleURL, encoding: .utf8)
    let segments = srtParserClient.parse(.init(content: srtContent))
    let segmentsByIndex = Dictionary(uniqueKeysWithValues: segments.map { ($0.index.rawValue, $0) })
    let translationsByIndex = Self.loadEnglishTranslationsIfPresent(subtitleURL: resolved.subtitleURL)
    let mwbtResp = try await metgDatabaseClient.mediaSubtitlesList.fetchByFileIDs(
      .init(fileIDs: [resolved.subtitleLocalizedLocalFileID])
    )
    var labelsBySubtitleIndex: [Int: [JapaneseTermLabelModel]] = [:]
    if let row = mwbtResp.subtitles.first {
      for label in row.labels {
        labelsBySubtitleIndex[label.subtitleIndex.rawValue, default: []].append(label)
      }
    }

    let cache = SourceCache(
      videoFileURL: resolved.videoURL,
      subtitleSegmentsByIndex: segmentsByIndex,
      englishTranslationsByIndex: translationsByIndex,
      mwbtLabelsBySubtitleIndex: labelsBySubtitleIndex
    )

    let allTermIDs = Set(labelsBySubtitleIndex.values.flatMap { $0 }.map { $0.japaneseTermID.rawValue })
    let knownResp = try await mediaListeningSRSDatabaseClient.japaneseTerm.fetchFullyKnownTermIDs(
      .init(japaneseTermIDs: Array(allTermIDs))
    )

    await MainActor.run {
      self.sourceCachesByID[mediaSourceID] = cache
      self.fullyKnownTermIDs.formUnion(knownResp.fullyKnownTermIDs)
    }
    return cache
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
        throw NSError(domain: "SRSCardReview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Movie URLs missing"])
      }
      return (videoURL, subtitleFile.url, subtitleFile.id)
    case .episode(let episodeID):
      guard let episode = try await jmlDatabaseClient.tvShowEpisode.fetch(.init(id: episodeID)),
            let videoURL = episode.japaneseVideoLocalURL,
            let subtitleFile = episode.japaneseSubtitleFile else {
        throw NSError(domain: "SRSCardReview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Episode URLs missing"])
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
  #endif
}
