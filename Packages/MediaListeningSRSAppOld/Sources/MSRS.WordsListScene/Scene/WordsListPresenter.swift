import Foundation

@MainActor
protocol WordsListDisplayer: AnyObject {
  func displayViewModel(_ viewModel: WordsListModels.ViewModel)
  func displayError(_ message: String)
}

@MainActor
final class WordsListPresenter {

  weak var displayer: WordsListDisplayer?

  func presentViewModel(_ viewModel: WordsListModels.ViewModel) {
    displayer?.displayViewModel(viewModel)
  }

  func presentError(_ message: String) {
    displayer?.displayError(message)
  }
}
