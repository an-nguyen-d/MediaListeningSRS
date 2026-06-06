import UIKit
import JML_JMLDatabaseClient
import MSRS_MediaSourceImportPickerScene
import MSRS_ProcessingQueueScene
import MSRS_SettingsScene
import MSRS_SharedModels
import MSRS_SRSCardReviewScene

public final class MediaSourcesListVC: UIViewController, MediaSourcesListDisplayer {

  private let contentView = MediaSourcesListView()
  private let interactor: MediaSourcesListInteractor
  private let dependencies: MediaSourcesListModels.Dependencies

  public init(dependencies: MediaSourcesListModels.Dependencies) {
    self.dependencies = dependencies
    let presenter = MediaSourcesListPresenter()
    self.interactor = MediaSourcesListInteractor(
      presenter: presenter,
      mediaListeningSRSDatabaseClient: dependencies.mediaListeningSRSDatabaseClient,
      jmlDatabaseClient: dependencies.jmlDatabaseClient
    )
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
    title = "MediaListening SRS"
    navigationItem.rightBarButtonItems = [
      UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped)),
      UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(settingsTapped)),
    ]
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: "Review All",
      style: .plain,
      target: self,
      action: #selector(reviewAllTapped)
    )
    contentView.onRowTapped = { [weak self] id in
      self?.interactor.sendAction(.rowTapped(id))
    }
    interactor.sendAction(.viewDidLoad)
  }

  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    interactor.sendAction(.viewWillAppear)
  }

  @objc private func addTapped() {
    interactor.sendAction(.addTapped)
  }

  @objc private func reviewAllTapped() {
    interactor.sendAction(.reviewAllTapped)
  }

  @objc private func settingsTapped() {
    let settingsVC = SettingsVC(
      mediaListeningSRSDatabaseClient: dependencies.mediaListeningSRSDatabaseClient,
      elixirSyncClient: dependencies.elixirSyncClient
    )
    navigationController?.pushViewController(settingsVC, animated: true)
  }

  // MARK: - MediaSourcesListDisplayer

  func displayDueCardCount(_ count: Int) {
    navigationItem.leftBarButtonItem?.title = count > 0 ? "Review All (\(count))" : "Review All"
  }

  func displayRows(_ rows: [MediaSourcesListModels.Row]) {
    contentView.setRows(rows)
  }

  func displayError(_ message: String) {
    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
    alert.addAction(.init(title: "OK", style: .default))
    present(alert, animated: true)
  }

  func displayNavigateToImportPicker() {
    let pickerVC = MediaSourceImportPickerVC(dependencies: dependencies)
    pickerVC.onImportSucceeded = { _ in }
    let nav = UINavigationController(rootViewController: pickerVC)
    pickerVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .cancel,
      target: self,
      action: #selector(dismissImportPicker)
    )
    nav.modalPresentationStyle = .formSheet
    present(nav, animated: true)
  }

  @objc private func dismissImportPicker() {
    dismiss(animated: true)
  }

  func displayNavigateToReviewAll() {
    let reviewVC = SRSCardReviewVC(dependencies: dependencies)
    let nav = UINavigationController(rootViewController: reviewVC)
    nav.modalPresentationStyle = .fullScreen
    present(nav, animated: true)
  }

  func displayNavigateToProcessingQueue(mediaSourceID: MediaSourceModel.ID) {
    let queueVC = ProcessingQueueVC(
      mediaSourceID: mediaSourceID,
      dependencies: dependencies
    )
    navigationController?.pushViewController(queueVC, animated: true)
  }
}
