import UIKit
import JML_JMLSharedModels
import MSRS_MediaSourceImportEpisodePickerScene
import MSRS_SharedModels

public final class MediaSourceImportPickerVC: UIViewController, MediaSourceImportPickerDisplayer, UISearchResultsUpdating {

  public var onImportSucceeded: ((MediaSourceModel.ID) -> Void)?

  private let contentView = MediaSourceImportPickerView()
  private let interactor: MediaSourceImportPickerInteractor
  private let dependencies: MediaSourceImportPickerModels.Dependencies
  private let searchController = UISearchController(searchResultsController: nil)

  public init(dependencies: MediaSourceImportPickerModels.Dependencies) {
    self.dependencies = dependencies
    let presenter = MediaSourceImportPickerPresenter()
    #if targetEnvironment(macCatalyst)
    self.interactor = MediaSourceImportPickerInteractor(
      presenter: presenter,
      jmlDatabaseClient: dependencies.jmlDatabaseClient,
      metgDatabaseClient: dependencies.metgDatabaseClient,
      mediaSourceImportService: dependencies.mediaSourceImportService
    )
    #else
    self.interactor = MediaSourceImportPickerInteractor(
      presenter: presenter,
      jmlDatabaseClient: dependencies.jmlDatabaseClient,
      mediaSourceImportService: dependencies.mediaSourceImportService
    )
    #endif
    super.init(nibName: nil, bundle: nil)
    presenter.displayer = self
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func loadView() {
    view = contentView
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    title = "Import from JML"

    searchController.searchResultsUpdater = self
    searchController.obscuresBackgroundDuringPresentation = false
    searchController.searchBar.placeholder = "Search series or movies"
    navigationItem.searchController = searchController
    navigationItem.hidesSearchBarWhenScrolling = false

    contentView.onRowTapped = { [weak self] row in
      self?.interactor.sendAction(.rowTapped(row))
    }
    interactor.sendAction(.viewDidLoad)
  }

  // MARK: - UISearchResultsUpdating

  public func updateSearchResults(for searchController: UISearchController) {
    let text = searchController.searchBar.text ?? ""
    interactor.sendAction(.searchTextChanged(text))
  }

  // MARK: - Displayer

  func displayState(_ state: MediaSourceImportPickerModels.DisplayState) {
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

  func displayNavigateToEpisodePicker(seriesID: TVShowSeriesModel.ID, seriesTitle: String) {
    let episodePicker = MediaSourceImportEpisodePickerVC(
      seriesID: seriesID,
      seriesTitle: seriesTitle,
      dependencies: dependencies
    )
    episodePicker.onImportSucceeded = { [weak self] createdSourceID in
      self?.navigationController?.popToViewController(self!, animated: false)
      self?.onImportSucceeded?(createdSourceID)
    }
    navigationController?.pushViewController(episodePicker, animated: true)
  }
}
