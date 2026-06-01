import UIKit
import IYO_DictionaryClient
import MSRS_MediaListeningSRSDatabaseClient

public final class WordsListVC: UIViewController, WordsListDisplayer {

  private let contentView = WordsListView()
  private let interactor: WordsListInteractor

  public init(dependencies: WordsListModels.Dependencies) {
    let presenter = WordsListPresenter()
    self.interactor = WordsListInteractor(
      presenter: presenter,
      dictionaryClient: dependencies.dictionaryClient,
      mediaListeningSRSDatabaseClient: dependencies.mediaListeningSRSDatabaseClient
    )
    super.init(nibName: nil, bundle: nil)
    presenter.displayer = self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func loadView() {
    view = contentView
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    title = "Words"

    contentView.onSortChanged = { [weak self] field in
      self?.interactor.sendAction(.sortChanged(field))
    }
    contentView.onKnownFilterChanged = { [weak self] filter in
      self?.interactor.sendAction(.knownFilterChanged(filter))
    }
    contentView.onSearchQueryChanged = { [weak self] query in
      self?.interactor.sendAction(.searchQueryChanged(query))
    }
    contentView.onScrolledNearBottom = { [weak self] in
      self?.interactor.sendAction(.loadNextPage)
    }
    contentView.onMarkAsKnownTapped = { [weak self] termID in
      self?.interactor.sendAction(.markTermAsKnown(termID: termID))
    }

    interactor.sendAction(.viewDidLoad)
  }

  // MARK: - WordsListDisplayer

  func displayViewModel(_ viewModel: WordsListModels.ViewModel) {
    contentView.setViewModel(viewModel)
  }

  func displayError(_ message: String) {
    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
    alert.addAction(.init(title: "OK", style: .default))
    present(alert, animated: true)
  }
}
