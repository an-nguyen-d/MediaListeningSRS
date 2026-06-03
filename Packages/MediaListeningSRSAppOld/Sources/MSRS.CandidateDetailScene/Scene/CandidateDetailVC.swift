import UIKit
import MSRS_Shared
import MSRS_SharedModels

public final class CandidateDetailVC: UIViewController, CandidateDetailDisplayer {

  public var onDismiss: (() -> Void)?
  /// When set, in-panel Skip button taps route to this closure instead of firing skip directly.
  /// The host (e.g. ProcessingQueueVC) uses this to interpose the red confirmation popup.
  public var onSkipButtonTappedRequiresHostConfirmation: (() -> Void)?
  /// When set, in-panel Confirm-and-Make-Card button taps route to this closure instead of
  /// firing make-card directly. The host uses this to interpose the green confirmation popup.
  public var onConfirmButtonTappedRequiresHostConfirmation: (() -> Void)?

  private let contentView = CandidateDetailView()
  private let interactor: CandidateDetailInteractor
  private var richDictionaryPopup: RichDictionaryPopupController?
  private var lastTappedTermID: Int64?

  public init(
    candidateID: MediaSourceCardCandidateModel.ID,
    mediaSourceID: MediaSourceModel.ID,
    dependencies: CandidateDetailModels.Dependencies
  ) {
    let presenter = CandidateDetailPresenter()
    #if targetEnvironment(macCatalyst)
    self.interactor = CandidateDetailInteractor(
      presenter: presenter,
      candidateID: candidateID,
      mediaSourceID: mediaSourceID,
      mediaListeningSRSDatabaseClient: dependencies.mediaListeningSRSDatabaseClient,
      jmlDatabaseClient: dependencies.jmlDatabaseClient,
      metgDatabaseClient: dependencies.metgDatabaseClient,
      dictionaryClient: dependencies.dictionaryClient,
      srtParserClient: dependencies.srtParserClient,
      clipExportService: dependencies.clipExportService,
      clipStorageClient: dependencies.clipStorageClient,
      exportedClipsDirectoryURL: dependencies.exportedClipsDirectoryURL
    )
    #else
    self.interactor = CandidateDetailInteractor(
      presenter: presenter,
      candidateID: candidateID,
      mediaSourceID: mediaSourceID,
      mediaListeningSRSDatabaseClient: dependencies.mediaListeningSRSDatabaseClient,
      jmlDatabaseClient: dependencies.jmlDatabaseClient,
      dictionaryClient: dependencies.dictionaryClient,
      srtParserClient: dependencies.srtParserClient,
      clipExportService: dependencies.clipExportService,
      clipStorageClient: dependencies.clipStorageClient,
      exportedClipsDirectoryURL: dependencies.exportedClipsDirectoryURL
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
    contentView.onEndIndexChanged = { [weak self] newEnd in
      self?.interactor.sendAction(.endSubtitleIndexChanged(newEnd))
    }
    contentView.onStartTimeAdjusted = { [weak self] delta in
      self?.interactor.sendAction(.startTimeAdjusted(deltaSeconds: delta))
    }
    contentView.onEndTimeAdjusted = { [weak self] delta in
      self?.interactor.sendAction(.endTimeAdjusted(deltaSeconds: delta))
    }
    contentView.onTermTapped = { [weak self] termID in
      self?.lastTappedTermID = termID
      self?.contentView.setSelectedTermID(termID)
      self?.interactor.sendAction(.termTapped(termID))
    }
    contentView.onSkipTapped = { [weak self] in
      guard let self = self else { return }
      if let hostInterposer = self.onSkipButtonTappedRequiresHostConfirmation {
        hostInterposer()
      } else {
        self.interactor.sendAction(.skipTapped)
      }
    }
    contentView.onConfirmTapped = { [weak self] in
      guard let self = self else { return }
      if let hostInterposer = self.onConfirmButtonTappedRequiresHostConfirmation {
        hostInterposer()
      } else {
        self.interactor.sendAction(.confirmTapped)
      }
    }
    interactor.sendAction(.viewDidLoad)
  }

  // MARK: - External hooks (called by the embedding ProcessingQueueVC)

  public func togglePlayPauseFromHost() {
    contentView.toggleLoopActiveFromHost()
  }

  public func triggerSkipFromHost() {
    interactor.sendAction(.skipTapped)
  }

  public func triggerConfirmFromHost() {
    interactor.sendAction(.confirmTapped)
  }

  public func adjustStartTimeFromHost(delta: TimeInterval) {
    contentView.adjustStartTime(delta: delta)
  }

  public func adjustEndTimeFromHost(delta: TimeInterval) {
    contentView.adjustEndTime(delta: delta)
  }

  // MARK: - CandidateDetailDisplayer

  func displayVideoFile(url: URL) {
    contentView.setVideoFile(url: url)
  }

  func displayViewModel(_ viewModel: CandidateDetailModels.ViewModel) {
    contentView.setViewModel(viewModel)
  }

  func displayDictionaryLookup(_ result: CandidateDetailModels.DictionaryLookupResult) {
    guard let tappedWordFrame = contentView.boundingFrameForTermID(result.japaneseTermID, in: view) else {
      return
    }

    richDictionaryPopup?.dismiss()
    let popup = RichDictionaryPopupController(hostView: view)
    richDictionaryPopup = popup
    popup.show(
      viewModel: result.viewModel,
      tappedWordFrame: tappedWordFrame,
      isAlreadyFullyKnown: result.isAlreadyFullyKnown,
      onMarkAsFullyKnownTapped: { [weak self] in
        self?.interactor.sendAction(.markTermAsFullyKnown(result.japaneseTermID))
      },
      onDismiss: { [weak self] in
        self?.contentView.setSelectedTermID(nil)
        self?.richDictionaryPopup = nil
      }
    )
  }

  func displayError(_ message: String) {
    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
    alert.addAction(.init(title: "OK", style: .default))
    present(alert, animated: true)
  }

  func displayDismiss() {
    onDismiss?()
  }
}
