import Foundation
import IYO_DictionaryClient
import IYO_DictionaryModels
import IYO_DictionaryUIKit
import IYO_JapaneseModels
import IYO_JapaneseParserClient
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

  private static let batchSize = 5

  private var currentBatch: [SRSCardModel] = []
  private var currentBatchIndex: Int = 0
  private var totalReviewedCount: Int = 0

  private var fullyKnownTermIDs: Set<Int64> = []
  private let studySessionTracker: StudySessionTracker
  private var currentTranscriptText: String = ""
  private var currentEnglishTranslationText: String?
  private var downloadsInProgress: Set<String> = []

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

      let transcriptText = card.cachedTranscriptText
      let translationText = card.cachedEnglishTranslation.isEmpty ? nil : card.cachedEnglishTranslation

      // Load fully-known state for terms in this card's label ranges
      let termIDs = Set(card.cachedLabelRanges.map(\.termID))
      if !termIDs.isEmpty {
        let knownResp = try? await mediaListeningSRSDatabaseClient.japaneseTerm.fetchFullyKnownTermIDs(
          .init(japaneseTermIDs: Array(termIDs))
        )
        if let knownIDs = knownResp?.fullyKnownTermIDs {
          await MainActor.run { self.fullyKnownTermIDs.formUnion(knownIDs) }
        }
      }

      let labeledRanges = card.cachedLabelRanges.toHighlightableRanges(
        fullyKnownTermIDs: self.fullyKnownTermIDs
      )

      #if !targetEnvironment(macCatalyst)
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
      #endif

      await MainActor.run {
        self.buildAndPresent(
          card: card,
          transcriptText: transcriptText,
          translationText: translationText,
          labeledRanges: labeledRanges,
          failIntervalSeconds: intervals?.failIntervalSeconds,
          passIntervalSeconds: intervals?.passIntervalSeconds
        )
        #if !targetEnvironment(macCatalyst)
        self.prefetchUpcomingCards()
        #endif
      }
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
    let prefetchCount = MSRSAppSettings.clipPrefetchCount
    guard prefetchCount > 0 else { return }
    let currentCardID = currentBatchIndex < currentBatch.count ? currentBatch[currentBatchIndex].id : nil
    let clipsDir = exportedClipsDirectoryURL
    let storageClient = clipStorageClient

    Task { [weak self, mediaListeningSRSDatabaseClient] in
      guard let self else { return }
      let fetchLimit = prefetchCount + 1
      let response = try? await mediaListeningSRSDatabaseClient.srsCard.fetchDueCards(
        .init(asOf: Date(), limit: fetchLimit)
      )
      guard let cards = response?.cards else { return }

      let upcoming = cards.filter { $0.id != currentCardID }
        .prefix(prefetchCount)

      await MainActor.run {
        for card in upcoming {
          let relativePath = card.clipRelativeFilePath
          let clipFileURL = clipsDir.appendingPathComponent(relativePath)
          guard !FileManager.default.fileExists(atPath: clipFileURL.path),
                !self.downloadsInProgress.contains(relativePath) else { continue }
          self.downloadsInProgress.insert(relativePath)

          Task.detached(priority: .utility) { [weak self] in
            let remotePath = "clips/\(relativePath)"
            _ = try? await storageClient.download(.init(
              remotePath: remotePath,
              localFileURL: clipFileURL
            ))
            let thumbRemotePath = "clips/\(relativePath.replacingOccurrences(of: ".mp4", with: ".jpg"))"
            let thumbnailURL = clipFileURL.deletingPathExtension().appendingPathExtension("jpg")
            _ = try? await storageClient.download(.init(
              remotePath: thumbRemotePath,
              localFileURL: thumbnailURL
            ))
            await MainActor.run { [weak self] in
              self?.downloadsInProgress.remove(relativePath)
            }
          }
        }
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
}
