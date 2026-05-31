import UIKit

@MainActor
protocol SRSCardReviewDisplayer: AnyObject {
  func displayCard(_ viewModel: SRSCardReviewModels.CardViewModel)
  func displayRevealBack()
  func displayReplay()
  func displayDictionaryLookup(_ result: SRSCardReviewModels.DictionaryLookupResult)
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
