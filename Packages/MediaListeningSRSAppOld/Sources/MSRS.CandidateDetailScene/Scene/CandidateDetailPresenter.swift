import Foundation
import UIKit

@MainActor
protocol CandidateDetailDisplayer: AnyObject {
  func displayVideoFile(url: URL)
  func displayViewModel(_ viewModel: CandidateDetailModels.ViewModel)
  func displayDictionaryLookup(_ result: CandidateDetailModels.DictionaryLookupResult)
  func displayError(_ message: String)
  func displayDismiss()
}

@MainActor
final class CandidateDetailPresenter {

  weak var displayer: CandidateDetailDisplayer!

  func presentVideoFile(url: URL) {
    displayer?.displayVideoFile(url: url)
  }

  func presentViewModel(_ viewModel: CandidateDetailModels.ViewModel) {
    displayer?.displayViewModel(viewModel)
  }

  func presentDictionaryLookup(_ result: CandidateDetailModels.DictionaryLookupResult) {
    displayer?.displayDictionaryLookup(result)
  }

  func presentError(_ message: String) {
    displayer?.displayError(message)
  }

  func presentDismiss() {
    displayer?.displayDismiss()
  }
}
