import UIKit

@MainActor
protocol SRSCardReviewDisplayer: AnyObject {
  func displayCard(_ viewModel: SRSCardReviewModels.CardViewModel)
  func displayRevealBack()
  func displayReplay()
  func displayDictionaryLookup(_ result: SRSCardReviewModels.DictionaryLookupResult)
  func displayLLMGradingStarted(userAnswer: String)
  func displayLLMGradeResult(_ result: SRSCardReviewModels.LLMGradeResult)
  func displayLLMGradingError(_ message: String)
  func displayClipDownloading()
  func displayEmptyDeck()
  func displayDeckCompleted()
  func displayError(_ message: String)
}

@MainActor
final class SRSCardReviewPresenter {

  weak var displayer: SRSCardReviewDisplayer!

  func presentCard(_ viewModel: SRSCardReviewModels.CardViewModel) {
    displayer?.displayCard(viewModel)
  }

  func presentRevealBack() {
    displayer?.displayRevealBack()
  }

  func presentReplay() {
    displayer?.displayReplay()
  }

  func presentDictionaryLookup(_ result: SRSCardReviewModels.DictionaryLookupResult) {
    displayer?.displayDictionaryLookup(result)
  }

  func presentLLMGradingStarted(userAnswer: String) {
    displayer?.displayLLMGradingStarted(userAnswer: userAnswer)
  }

  func presentLLMGradeResult(_ result: SRSCardReviewModels.LLMGradeResult) {
    displayer?.displayLLMGradeResult(result)
  }

  func presentLLMGradingError(_ message: String) {
    displayer?.displayLLMGradingError(message)
  }

  func presentClipDownloading() {
    displayer?.displayClipDownloading()
  }

  func presentEmptyDeck() {
    displayer?.displayEmptyDeck()
  }

  func presentDeckCompleted() {
    displayer?.displayDeckCompleted()
  }

  func presentError(_ message: String) {
    displayer?.displayError(message)
  }
}
