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
    case .gradedAndNext(let grade, let listenCount):
      studySessionTracker.recordHeartbeat(isCardReview: true)
      handleGraded(grade, listenCount: listenCount)
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
    case .suspendCard:
      handleSuspendCard()
    case .showCardHistory:
      handleShowCardHistory()
    case .editTranscript:
      handleEditTranscript()
    case .updateTranscript(let newText):
      handleUpdateTranscript(newText)
    case .createReadingCard(let sourceCardID, let termID, let utf16Location, let utf16Length):
      handleCreateReadingCard(sourceCardID: sourceCardID, termID: termID, utf16Location: utf16Location, utf16Length: utf16Length)
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

  private func handleGraded(_ grade: SRSCardReviewModels.Grade, listenCount: Int) {
    guard currentBatchIndex < currentBatch.count else { return }
    let card = currentBatch[currentBatchIndex]
    let ratingRawValue: Int = (grade == .fail) ? 1 : 3
    let effectiveListenCount: Int? = card.cardType == .reading ? nil : listenCount
    Task { [mediaListeningSRSDatabaseClient, presenter] in
      do {
        let response = try await mediaListeningSRSDatabaseClient.srsCard.recordReview(
          .init(cardID: card.id, ratingRawValue: ratingRawValue, listenCount: effectiveListenCount)
        )
        let updated = response.updatedModel
        if card.cardType == .listening,
           grade == .pass,
           updated.playbackSpeed < 1.0,
           updated.consecutiveCorrectAtCurrentSpeed >= 2 {
          let newSpeed = min(1.0, (updated.playbackSpeed * 100 + 5).rounded() / 100)
          try? await mediaListeningSRSDatabaseClient.srsCard.updatePlaybackSpeed(
            .init(cardID: card.id, speed: newSpeed)
          )
        }
        await MainActor.run { self.advanceToNextCard() }
      } catch {
        await MainActor.run {
          presenter.presentError("Failed to record review: \(error.localizedDescription)")
        }
      }
    }
  }

  private func handleSuspendCard() {
    guard currentBatchIndex < currentBatch.count else { return }
    let card = currentBatch[currentBatchIndex]
    Task { [mediaListeningSRSDatabaseClient, presenter] in
      do {
        _ = try await mediaListeningSRSDatabaseClient.srsCard.suspendCard(
          .init(cardID: card.id)
        )
        await MainActor.run { self.advanceToNextCard() }
      } catch {
        await MainActor.run {
          presenter.presentError("Failed to suspend card: \(error.localizedDescription)")
        }
      }
    }
  }

  private func handleShowCardHistory() {
    guard currentBatchIndex < currentBatch.count else { return }
    let card = currentBatch[currentBatchIndex]
    Task { [mediaListeningSRSDatabaseClient, presenter] in
      do {
        let response = try await mediaListeningSRSDatabaseClient.srsCard.fetchReviewEventsForCard(
          .init(cardID: card.id)
        )
        await MainActor.run {
          presenter.presentCardHistory(response.events)
        }
      } catch {
        await MainActor.run {
          presenter.presentError("Failed to load history: \(error.localizedDescription)")
        }
      }
    }
  }

  private func handleEditTranscript() {
    guard currentBatchIndex < currentBatch.count else { return }
    let card = currentBatch[currentBatchIndex]
    presenter.presentEditTranscript(currentText: card.cachedTranscriptText)
  }

  private func handleUpdateTranscript(_ newText: String) {
    guard currentBatchIndex < currentBatch.count else { return }
    let card = currentBatch[currentBatchIndex]
    let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != card.cachedTranscriptText else { return }

    let adjustedRanges = Self.adjustLabelRanges(
      card.cachedLabelRanges,
      oldText: card.cachedTranscriptText,
      newText: trimmed
    )

    Task { [mediaListeningSRSDatabaseClient] in
      do {
        _ = try await mediaListeningSRSDatabaseClient.srsCard.batchUpdateCachedTranscripts(.init(
          updates: [.init(
            cardID: card.id,
            cachedTranscriptText: trimmed,
            cachedEnglishTranslation: card.cachedEnglishTranslation
          )]
        ))
        _ = try await mediaListeningSRSDatabaseClient.srsCard.batchUpdateCachedLabelRanges(.init(
          updates: [.init(
            cardID: card.id,
            labelRangesJSON: SRSCardLabelRange.encodeToJSON(adjustedRanges)
          )]
        ))
        await MainActor.run { [weak self] in
          guard let self, self.currentBatchIndex < self.currentBatch.count else { return }
          let existing = self.currentBatch[self.currentBatchIndex]
          self.currentBatch[self.currentBatchIndex] = SRSCardModel(
            id: existing.id,
            createdAt: existing.createdAt,
            lastUpdatedAt: Date(),
            mediaSourceID: existing.mediaSourceID,
            subtitleIndexStart: existing.subtitleIndexStart,
            subtitleIndexEnd: existing.subtitleIndexEnd,
            clipStartTimeSeconds: existing.clipStartTimeSeconds,
            clipEndTimeSeconds: existing.clipEndTimeSeconds,
            clipRelativeFilePath: existing.clipRelativeFilePath,
            cachedTranscriptText: trimmed,
            cachedEnglishTranslation: existing.cachedEnglishTranslation,
            cachedLabelRanges: adjustedRanges,
            frontVideoVisibility: existing.frontVideoVisibility,
            playbackSpeed: existing.playbackSpeed,
            consecutiveCorrectAtCurrentSpeed: existing.consecutiveCorrectAtCurrentSpeed,
            isSuspended: existing.isSuspended,
            cardType: existing.cardType,
            readingCardTargetWord: existing.readingCardTargetWord
          )
          self.emitCurrentCard()
        }
      } catch {
        await MainActor.run { [weak self] in
          self?.presenter.presentError("Failed to save transcript: \(error.localizedDescription)")
        }
      }
    }
  }

  static func adjustLabelRanges(
    _ ranges: [SRSCardLabelRange],
    oldText: String,
    newText: String
  ) -> [SRSCardLabelRange] {
    let oldUTF16 = Array(oldText.utf16)
    let newUTF16 = Array(newText.utf16)

    let deletions = Self.findDeletions(old: oldUTF16, new: newUTF16)
    guard !deletions.isEmpty else { return ranges }

    var result: [SRSCardLabelRange] = []
    for range in ranges {
      let rangeStart = range.utf16Location
      let rangeEnd = rangeStart + range.utf16Length

      var overlaps = false
      var totalShift = 0
      for deletion in deletions {
        let delEnd = deletion.location + deletion.length
        if deletion.location < rangeEnd && delEnd > rangeStart {
          overlaps = true
          break
        }
        if delEnd <= rangeStart {
          totalShift += deletion.length
        }
      }

      if overlaps { continue }

      result.append(.init(
        utf16Location: rangeStart - totalShift,
        utf16Length: range.utf16Length,
        termID: range.termID,
        inflectionKey: range.inflectionKey
      ))
    }
    return result
  }

  private static func findDeletions(
    old: [UTF16.CodeUnit],
    new: [UTF16.CodeUnit]
  ) -> [(location: Int, length: Int)] {
    var deletions: [(location: Int, length: Int)] = []
    var oi = 0
    var ni = 0

    while oi < old.count && ni < new.count {
      if old[oi] == new[ni] {
        oi += 1
        ni += 1
      } else {
        let delStart = oi
        while oi < old.count {
          if ni < new.count && old[oi] == new[ni] { break }
          oi += 1
        }
        deletions.append((location: delStart, length: oi - delStart))
      }
    }

    if oi < old.count {
      deletions.append((location: oi, length: old.count - oi))
    }

    return deletions
  }

  private func handleCreateReadingCard(
    sourceCardID: SRSCardModel.ID,
    termID: Int64,
    utf16Location: Int,
    utf16Length: Int
  ) {
    Task { [mediaListeningSRSDatabaseClient, presenter] in
      do {
        _ = try await mediaListeningSRSDatabaseClient.srsCard.createReadingCard(.init(
          sourceCardID: sourceCardID,
          targetTermID: termID,
          targetTermUTF16Location: utf16Location,
          targetTermUTF16Length: utf16Length
        ))
        await MainActor.run {
          presenter.presentReadingCardCreated()
        }
      } catch {
        await MainActor.run {
          presenter.presentError(error.localizedDescription)
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
    let currentCard = currentBatchIndex < currentBatch.count ? currentBatch[currentBatchIndex] : nil
    let isListeningCard = currentCard?.cardType == .listening

    let matchingLabelRange = currentCard?.cachedLabelRanges.first(where: { $0.termID == termID })
    let tappedRange: NSRange? = matchingLabelRange.map {
      NSRange(location: $0.utf16Location, length: $0.utf16Length)
    }

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
            isAlreadyFullyKnown: isKnownResp.isFullyKnown,
            tappedRange: tappedRange,
            showCreateReadingCardButton: isListeningCard,
            sourceCardID: isListeningCard ? currentCard?.id : nil
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
    Task { [weak self, mediaListeningSRSDatabaseClient, dictionaryClient, clipStorageClient, exportedClipsDirectoryURL] in
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

      var readingKana: String?
      var readingDefinition: String?
      if card.cardType == .reading, let target = card.readingCardTargetWord {
        let lookup = try? await dictionaryClient.lookupByID(.init(termID: Int(target.termID)))
        readingKana = lookup?.spellings
          .filter { $0.isKanaSpelling }
          .min(by: { $0.spellingRank < $1.spellingRank })?
          .spelling
        readingDefinition = lookup?.senses.first?.meaning
      }

      await MainActor.run {
        self.buildAndPresent(
          card: card,
          transcriptText: transcriptText,
          translationText: translationText,
          labeledRanges: labeledRanges,
          failIntervalSeconds: intervals?.failIntervalSeconds,
          passIntervalSeconds: intervals?.passIntervalSeconds,
          readingCardKana: readingKana,
          readingCardDefinition: readingDefinition
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
    passIntervalSeconds: TimeInterval? = nil,
    readingCardKana: String? = nil,
    readingCardDefinition: String? = nil
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
      passIntervalSeconds: passIntervalSeconds,
      cardType: card.cardType,
      readingCardTargetWord: card.readingCardTargetWord,
      readingCardKana: readingCardKana,
      readingCardDefinition: readingCardDefinition
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

    let currentCard = currentBatchIndex < currentBatch.count ? currentBatch[currentBatchIndex] : nil
    let isListeningCard = currentCard?.cardType == .listening

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
            tappedRange: tappedRange,
            showCreateReadingCardButton: isListeningCard,
            sourceCardID: isListeningCard ? currentCard?.id : nil
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
