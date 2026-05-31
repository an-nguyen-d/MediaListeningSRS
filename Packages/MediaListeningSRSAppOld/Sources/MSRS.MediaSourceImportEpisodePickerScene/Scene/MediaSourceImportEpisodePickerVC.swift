import UIKit
import JML_JMLSharedModels
import MSRS_SharedModels

public final class MediaSourceImportEpisodePickerVC: UIViewController, MediaSourceImportEpisodePickerDisplayer, UISearchResultsUpdating {

  public var onImportSucceeded: ((MediaSourceModel.ID) -> Void)?

  private let contentView = MediaSourceImportEpisodePickerView()
  private let interactor: MediaSourceImportEpisodePickerInteractor
  private let searchController = UISearchController(searchResultsController: nil)

  public init(
    seriesID: TVShowSeriesModel.ID,
    seriesTitle: String,
    dependencies: MediaSourceImportEpisodePickerModels.Dependencies
  ) {
    let presenter = MediaSourceImportEpisodePickerPresenter()
    self.interactor = MediaSourceImportEpisodePickerInteractor(
      presenter: presenter,
      seriesID: seriesID,
      jmlDatabaseClient: dependencies.jmlDatabaseClient,
      metgDatabaseClient: dependencies.metgDatabaseClient,
      mediaSourceImportService: dependencies.mediaSourceImportService
    )
    super.init(nibName: nil, bundle: nil)
    presenter.displayer = self
    title = seriesTitle
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func loadView() {
    view = contentView
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    searchController.searchResultsUpdater = self
    searchController.obscuresBackgroundDuringPresentation = false
    searchController.searchBar.placeholder = "Search episodes"
    navigationItem.searchController = searchController
    navigationItem.hidesSearchBarWhenScrolling = false
    contentView.onRowTapped = { [weak self] row in
      self?.interactor.sendAction(.episodeTapped(row.mediaReference))
    }
    interactor.sendAction(.viewDidLoad)
  }

  // MARK: - UISearchResultsUpdating

  public func updateSearchResults(for searchController: UISearchController) {
    let text = searchController.searchBar.text ?? ""
    interactor.sendAction(.searchTextChanged(text))
  }

  // MARK: - Displayer

  func displayState(_ state: MediaSourceImportEpisodePickerModels.DisplayState) {
    contentView.setState(state)
  }

  func displayImportError(_ message: String) {
    let alert = UIAlertController(title: "Import failed", message: message, preferredStyle: .alert)
    alert.addAction(.init(title: "OK", style: .default))
    present(alert, animated: true)
  }

  func displayImportSucceeded(createdSourceID: MediaSourceModel.ID, candidateCount: Int) {
    let alert = UIAlertController(
      title: "Imported",
      message: "Created MediaSource with \(candidateCount) candidate(s)",
      preferredStyle: .alert
    )
    alert.addAction(.init(title: "OK", style: .default) { [weak self] _ in
      self?.onImportSucceeded?(createdSourceID)
    })
    present(alert, animated: true)
  }
}
