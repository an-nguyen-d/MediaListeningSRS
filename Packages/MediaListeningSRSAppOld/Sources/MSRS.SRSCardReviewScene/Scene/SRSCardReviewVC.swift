import UIKit
import MSRS_Shared
import MSRS_SharedModels

public final class SRSCardReviewVC: UIViewController, SRSCardReviewDisplayer {

  private let contentView = SRSCardReviewView()
  private let interactor: SRSCardReviewInteractor
  private var richDictionaryPopup: RichDictionaryPopupController?

  public init(dependencies: SRSCardReviewModels.Dependencies) {
    let presenter = SRSCardReviewPresenter()
    self.interactor = SRSCardReviewInteractor(
      presenter: presenter,
      clipStorageClient: dependencies.clipStorageClient,
      mediaListeningSRSDatabaseClient: dependencies.mediaListeningSRSDatabaseClient,
      dictionaryClient: dependencies.dictionaryClient,
      japaneseParserClient: dependencies.japaneseParserClient,
      exportedClipsDirectoryURL: dependencies.exportedClipsDirectoryURL
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
    title = "Review"
    contentView.onReplayTapped = { [weak self] in
      self?.interactor.sendAction(.replayTapped)
    }
    contentView.onRevealBackTapped = { [weak self] in
      self?.interactor.sendAction(.revealBackTapped)
    }
    contentView.onGraded = { [weak self] grade in
      self?.interactor.sendAction(.gradedAndNext(grade))
    }
    contentView.onTermTapped = { [weak self] termID in
      self?.contentView.setSelectedTermID(termID)
      self?.interactor.sendAction(.termTapped(termID))
    }
    contentView.onFrontVideoVisibilityChanged = { [weak self] visibility in
      self?.interactor.sendAction(.frontVideoVisibilityChanged(visibility))
    }
    contentView.onPlaybackSpeedChanged = { [weak self] speed in
      self?.interactor.sendAction(.playbackSpeedChanged(speed))
    }
    contentView.onSubmitTypedAnswer = { [weak self] answer in
      self?.interactor.sendAction(.submitTypedAnswer(answer))
    }
    contentView.onTranscriptTappedAtCharacterIndex = { [weak self] charIndex in
      self?.interactor.sendAction(.transcriptTappedAtCharacterIndex(charIndex))
    }
    contentView.onAutoLoopVideoChanged = { [weak self] isOn in
      self?.interactor.sendAction(.autoLoopVideoChanged(isOn))
    }
    if navigationController?.presentingViewController != nil {
      navigationItem.leftBarButtonItem = UIBarButtonItem(
        barButtonSystemItem: .done,
        target: self,
        action: #selector(doneTapped)
      )
    }
    interactor.sendAction(.viewDidLoad)
  }

  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    becomeFirstResponder()
  }

  public override var canBecomeFirstResponder: Bool { true }

  public override var keyCommands: [UIKeyCommand]? {
    [
      UIKeyCommand(input: "t", modifierFlags: [], action: #selector(tPressed), discoverabilityTitle: "Toggle Thumbnail"),
      UIKeyCommand(input: " ", modifierFlags: [], action: #selector(spacePressed), discoverabilityTitle: "Play"),
      UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(returnPressed), discoverabilityTitle: "Reveal Back"),
      UIKeyCommand(input: "1", modifierFlags: [], action: #selector(failPressed), discoverabilityTitle: "Fail"),
      UIKeyCommand(input: "2", modifierFlags: [], action: #selector(passPressed), discoverabilityTitle: "Pass"),
    ]
  }

  @objc private func tPressed() {
    contentView.cycleFrontVideoVisibility()
  }

  @objc private func spacePressed() {
    interactor.sendAction(.replayTapped)
  }

  @objc private func returnPressed() {
    guard !contentView.isShowingBackSide else { return }
    interactor.sendAction(.revealBackTapped)
  }

  @objc private func failPressed() {
    guard contentView.isShowingBackSide else { return }
    interactor.sendAction(.gradedAndNext(.fail))
  }

  @objc private func passPressed() {
    guard contentView.isShowingBackSide else { return }
    interactor.sendAction(.gradedAndNext(.pass))
  }

  @objc private func doneTapped() {
    dismiss(animated: true)
  }

  // MARK: - SRSCardReviewDisplayer

  func displayCard(_ viewModel: SRSCardReviewModels.CardViewModel) {
    contentView.setCard(viewModel)
  }

  func displayRevealBack() {
    contentView.revealBack()
  }

  func displayReplay() {
    contentView.replay()
  }

  func displayDictionaryLookup(_ result: SRSCardReviewModels.DictionaryLookupResult) {
    let tappedWordFrame: CGRect?
    if let range = result.tappedRange {
      tappedWordFrame = contentView.boundingFrameForCharacterRange(range, in: view)
    } else {
      tappedWordFrame = contentView.boundingFrameForTermID(result.japaneseTermID, in: view)
    }
    guard let tappedWordFrame else { return }
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

  func displayClipDownloading() {
    contentView.showEmptyState(message: "Downloading clip…")
  }

  func displayEmptyDeck() {
    contentView.showEmptyState(message: "No cards to review yet.")
  }

  func displayDeckCompleted() {
    contentView.showEmptyState(message: "Deck complete.")
  }

  func displayLLMGradingStarted(userAnswer: String) {
    contentView.showLLMGradingStarted(userAnswer: userAnswer)
  }

  func displayLLMGradeResult(_ result: SRSCardReviewModels.LLMGradeResult) {
    contentView.showLLMGradeResult(result)
  }

  func displayLLMGradingError(_ message: String) {
    contentView.showLLMGradingError(message)
  }

  func displayError(_ message: String) {
    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
    alert.addAction(.init(title: "OK", style: .default))
    present(alert, animated: true)
  }
}
