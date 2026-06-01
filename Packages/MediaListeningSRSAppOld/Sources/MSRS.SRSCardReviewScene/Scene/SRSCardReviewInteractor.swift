import Foundation
import ElixirShared
import IYO_DictionaryClient
import IYO_DictionaryModels
import JML_JMLDatabaseClient
import JML_JMLSharedModels
import METG_METGDatabaseClient
import METG_SharedModels
import MSRS_ClipExportService
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
  private let jmlDatabaseClient: JMLDatabaseClient
  private let metgDatabaseClient: METGDatabaseClient
  private let dictionaryClient: DictionaryClient
  private let srtParserClient: SRTParserClient
  private let exportedClipsDirectoryURL: URL

  private var cards: [SRSCardModel] = []
  private var currentIndex: Int = 0

  private struct SourceCache {
    let videoFileURL: URL
    let subtitleSegmentsByIndex: [Int: SubtitleSegment]
    let englishTranslationsByIndex: [Int: String]
    let mwbtLabelsBySubtitleIndex: [Int: [JapaneseTermLabelModel]]
  }
  private var sourceCachesByID: [MediaSourceModel.ID: SourceCache] = [:]
  private var fullyKnownTermIDs: Set<Int64> = []
  private let studySessionTracker: StudySessionTracker
  private var currentTranscriptText: String = ""
  private var currentEnglishTranslationText: String?

  init(
    presenter: SRSCardReviewPresenter,
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    jmlDatabaseClient: JMLDatabaseClient,
    metgDatabaseClient: METGDatabaseClient,
    dictionaryClient: DictionaryClient,
    srtParserClient: SRTParserClient,
    exportedClipsDirectoryURL: URL
  ) {
    self.presenter = presenter
    self.mediaListeningSRSDatabaseClient = mediaListeningSRSDatabaseClient
    self.jmlDatabaseClient = jmlDatabaseClient
    self.metgDatabaseClient = metgDatabaseClient
    self.dictionaryClient = dictionaryClient
    self.srtParserClient = srtParserClient
    self.exportedClipsDirectoryURL = exportedClipsDirectoryURL
    self.studySessionTracker = StudySessionTracker(dbClient: mediaListeningSRSDatabaseClient)
  }

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
    guard currentIndex < cards.count else { return }
    let card = cards[currentIndex]
    cards[currentIndex].frontVideoVisibility = visibility
    Task { [mediaListeningSRSDatabaseClient] in
      try? await mediaListeningSRSDatabaseClient.srsCard.updateFrontVideoVisibility(
        .init(cardID: card.id, visibility: visibility)
      )
    }
  }

  private func handlePlaybackSpeedChanged(_ speed: Double) {
    guard currentIndex < cards.count else { return }
    let card = cards[currentIndex]
    cards[currentIndex].playbackSpeed = speed
    cards[currentIndex].consecutiveCorrectAtCurrentSpeed = 0
    Task { [mediaListeningSRSDatabaseClient] in
      try? await mediaListeningSRSDatabaseClient.srsCard.updatePlaybackSpeed(
        .init(cardID: card.id, speed: speed)
      )
    }
  }

  private func handleGraded(_ grade: SRSCardReviewModels.Grade) {
    guard currentIndex < cards.count else { return }
    let card = cards[currentIndex]
    // Map the 2-button grade onto FSRS Rating: fail → again (1), pass → good (3).
    // (FSRS supports 4 grades; we can refine to 4 buttons later without schema change.)
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
    Task { [mediaListeningSRSDatabaseClient, presenter] in
      do {
        let response = try await mediaListeningSRSDatabaseClient.srsCard.fetchDueCards(
          .init(asOf: Date())
        )
        guard !response.cards.isEmpty else {
          await MainActor.run { presenter.presentEmptyDeck() }
          return
        }
        await MainActor.run {
          self.cards = response.cards
          self.currentIndex = 0
          self.emitCurrentCard()
        }
      } catch {
        await MainActor.run {
          presenter.presentError("Failed to load deck: \(error.localizedDescription)")
        }
      }
    }
  }

  private func advanceToNextCard() {
    currentIndex += 1
    if currentIndex >= cards.count {
      presenter.presentDeckCompleted()
    } else {
      emitCurrentCard()
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
    guard currentIndex < cards.count else { return }
    let card = cards[currentIndex]
    Task { [weak self, mediaListeningSRSDatabaseClient] in
      guard let self else { return }
      do {
        let cache = try await self.ensureSourceCache(mediaSourceID: card.mediaSourceID)
        let intervals = try? await mediaListeningSRSDatabaseClient.srsCard.previewNextIntervals(
          .init(cardID: card.id)
        )
        let termLinksResp = try await mediaListeningSRSDatabaseClient.srsCard.fetchTermLinksForCard(
          .init(cardID: card.id)
        )
        var inflectionKeysByTermID: [Int64: String] = [:]
        for link in termLinksResp.termLinks {
          inflectionKeysByTermID[link.japaneseTermID] = link.inflectionKey
        }
        await MainActor.run {
          self.buildAndPresent(
            card: card,
            cache: cache,
            inflectionKeysByTermID: inflectionKeysByTermID,
            failIntervalSeconds: intervals?.failIntervalSeconds,
            passIntervalSeconds: intervals?.passIntervalSeconds
          )
        }
      } catch {
        await MainActor.run {
          self.presenter.presentError("Failed to load source data: \(error.localizedDescription)")
        }
      }
    }
  }

  private func buildAndPresent(
    card: SRSCardModel,
    cache: SourceCache,
    inflectionKeysByTermID: [Int64: String] = [:],
    failIntervalSeconds: TimeInterval? = nil,
    passIntervalSeconds: TimeInterval? = nil
  ) {
    var joinedParts: [String] = []
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
      joinedParts.append(text)
      runningUTF16Offset += textUTF16Length
      if index < card.subtitleIndexEnd {
        runningUTF16Offset += 1
      }
    }
    let transcriptText = joinedParts.joined(separator: "\n")
    let translationParts = (card.subtitleIndexStart...card.subtitleIndexEnd)
      .compactMap { cache.englishTranslationsByIndex[$0] }
    let translationText = translationParts.isEmpty ? nil : translationParts.joined(separator: "\n")

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
      cardPositionLabel: "\(currentIndex + 1) of \(cards.count)",
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

    // Merge any newly-relevant known IDs into the global cache (single source of truth).
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
}
