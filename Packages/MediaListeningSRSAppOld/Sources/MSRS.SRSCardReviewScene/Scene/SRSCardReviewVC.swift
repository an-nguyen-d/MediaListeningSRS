import UIKit
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_Shared
import MSRS_SharedModels

public final class SRSCardReviewVC: UIViewController, SRSCardReviewDisplayer {

  private let contentView = SRSCardReviewView()
  private let interactor: SRSCardReviewInteractor
  private var richDictionaryPopup: RichDictionaryPopupController?
  private var pendingGradeOverlayColor: UIColor?

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
      guard let self else { return }
      self.interactor.sendAction(.gradedAndNext(grade, listenCount: self.contentView.listenCount))
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
    contentView.onDismissReview = { [weak self] in
      self?.dismiss(animated: true)
    }
    contentView.onSuspendCard = { [weak self] in
      self?.showSuspendConfirmation()
    }
    contentView.onShowCardHistory = { [weak self] in
      self?.interactor.sendAction(.showCardHistory)
    }
    contentView.onEditTranscript = { [weak self] in
      self?.interactor.sendAction(.editTranscript)
    }
    if contentView.isCondensedMode {
      navigationController?.setNavigationBarHidden(true, animated: false)
    } else if navigationController?.presentingViewController != nil {
      navigationItem.leftBarButtonItem = UIBarButtonItem(
        barButtonSystemItem: .done,
        target: self,
        action: #selector(doneTapped)
      )
    }
    interactor.sendAction(.viewDidLoad)
    observeGlobalHotkeys()
  }

  private func observeGlobalHotkeys() {
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(returnPressed), name: GlobalHotkey.commandOptionQ, object: nil)
    nc.addObserver(self, selector: #selector(failPressed), name: GlobalHotkey.commandOptionW, object: nil)
    nc.addObserver(self, selector: #selector(hardPressed), name: GlobalHotkey.commandOptionE, object: nil)
    nc.addObserver(self, selector: #selector(mediumPressed), name: GlobalHotkey.commandOptionR, object: nil)
    nc.addObserver(self, selector: #selector(easyPressed), name: GlobalHotkey.commandOptionT, object: nil)
    nc.addObserver(self, selector: #selector(speedDownPressed), name: GlobalHotkey.commandOptionY, object: nil)
    nc.addObserver(self, selector: #selector(speedUpPressed), name: GlobalHotkey.commandOptionU, object: nil)
    nc.addObserver(self, selector: #selector(spacePressed), name: GlobalHotkey.commandOptionI, object: nil)
  }

  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    becomeFirstResponder()
  }

  public override var canBecomeFirstResponder: Bool { true }

  public override var keyCommands: [UIKeyCommand]? {
    var commands: [UIKeyCommand] = [
      UIKeyCommand(input: "t", modifierFlags: [], action: #selector(tPressed), discoverabilityTitle: "Toggle Thumbnail"),
      UIKeyCommand(input: " ", modifierFlags: [], action: #selector(spacePressed), discoverabilityTitle: "Play"),
      UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(returnPressed), discoverabilityTitle: "Reveal Back"),
    ]
    if MSRSAppSettings.numpadHotkeysEnabled {
      commands.append(contentsOf: [
        UIKeyCommand(input: "7", modifierFlags: [], action: #selector(returnPressed), discoverabilityTitle: "Reveal Back (Numpad)"),
        UIKeyCommand(input: "4", modifierFlags: [], action: #selector(failPressed), discoverabilityTitle: "Fail (Numpad)"),
        UIKeyCommand(input: "5", modifierFlags: [], action: #selector(hardPressed), discoverabilityTitle: "Hard (Numpad)"),
        UIKeyCommand(input: "6", modifierFlags: [], action: #selector(mediumPressed), discoverabilityTitle: "Medium (Numpad)"),
        UIKeyCommand(input: "+", modifierFlags: [], action: #selector(easyPressed), discoverabilityTitle: "Easy (Numpad)"),
        UIKeyCommand(input: "1", modifierFlags: [], action: #selector(speedDownPressed), discoverabilityTitle: "Speed −0.1 (Numpad)"),
        UIKeyCommand(input: "2", modifierFlags: [], action: #selector(spacePressed), discoverabilityTitle: "Play/Pause (Numpad)"),
        UIKeyCommand(input: "3", modifierFlags: [], action: #selector(speedUpPressed), discoverabilityTitle: "Speed +0.1 (Numpad)"),
      ])
    } else {
      commands.append(contentsOf: [
        UIKeyCommand(input: "1", modifierFlags: [], action: #selector(failPressed), discoverabilityTitle: "Fail"),
        UIKeyCommand(input: "2", modifierFlags: [], action: #selector(hardPressed), discoverabilityTitle: "Hard"),
        UIKeyCommand(input: "3", modifierFlags: [], action: #selector(mediumPressed), discoverabilityTitle: "Medium"),
        UIKeyCommand(input: "4", modifierFlags: [], action: #selector(easyPressed), discoverabilityTitle: "Easy"),
      ])
    }
    return commands
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
    if MSRSAppSettings.reviewFeedbackEffectsEnabled {
      ReviewSoundPlayer.play(.failCard)
      pendingGradeOverlayColor = .systemRed
    }
    interactor.sendAction(.gradedAndNext(.fail, listenCount: contentView.listenCount))
  }

  @objc private func hardPressed() {
    if MSRSAppSettings.reviewFeedbackEffectsEnabled {
      ReviewSoundPlayer.play(.passCard)
      pendingGradeOverlayColor = .systemOrange
    }
    interactor.sendAction(.gradedAndNext(.hard, listenCount: contentView.listenCount))
  }

  @objc private func mediumPressed() {
    if MSRSAppSettings.reviewFeedbackEffectsEnabled {
      ReviewSoundPlayer.play(.passCard)
      pendingGradeOverlayColor = .systemGreen
    }
    interactor.sendAction(.gradedAndNext(.medium, listenCount: contentView.listenCount))
  }

  @objc private func easyPressed() {
    if MSRSAppSettings.reviewFeedbackEffectsEnabled {
      ReviewSoundPlayer.play(.passCard)
      pendingGradeOverlayColor = .systemGreen
    }
    interactor.sendAction(.gradedAndNext(.easy, listenCount: contentView.listenCount))
  }

  @objc private func speedDownPressed() {
    contentView.handleSpeedDelta(-0.1)
  }

  @objc private func speedUpPressed() {
    contentView.handleSpeedDelta(0.1)
  }

  private func showSuspendConfirmation() {
    let alert = UIAlertController(
      title: "Suspend Card",
      message: "This card will be removed from review. Are you sure?",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Suspend", style: .destructive) { [weak self] _ in
      self?.interactor.sendAction(.suspendCard)
    })
    present(alert, animated: true)
  }

  @objc private func doneTapped() {
    dismiss(animated: true)
  }

  // MARK: - SRSCardReviewDisplayer

  func displayCard(_ viewModel: SRSCardReviewModels.CardViewModel) {
    let overlayColor = pendingGradeOverlayColor
    pendingGradeOverlayColor = nil
    let effectsEnabled = MSRSAppSettings.reviewFeedbackEffectsEnabled
    if effectsEnabled {
      ReviewSoundPlayer.play(.showCard)
    }
    contentView.setCard(viewModel)
    if effectsEnabled, let overlayColor {
      showGradeOverlay(color: overlayColor)
    }
  }

  private func showGradeOverlay(color: UIColor) {
    let overlay = UIView()
    overlay.backgroundColor = color.withAlphaComponent(0.45)
    overlay.frame = view.bounds
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.isUserInteractionEnabled = false
    view.addSubview(overlay)
    UIView.animate(withDuration: 1.0, delay: 0, options: .curveEaseOut) {
      overlay.alpha = 0
    } completion: { _ in
      overlay.removeFromSuperview()
    }
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
      showCreateReadingCardButton: result.showCreateReadingCardButton,
      onMarkAsFullyKnownTapped: { [weak self] in
        self?.interactor.sendAction(.markTermAsFullyKnown(result.japaneseTermID))
      },
      onCreateReadingCardTapped: result.showCreateReadingCardButton ? { [weak self] in
        guard let sourceCardID = result.sourceCardID,
              let range = result.tappedRange else { return }
        self?.interactor.sendAction(.createReadingCard(
          sourceCardID: sourceCardID,
          termID: result.japaneseTermID,
          utf16Location: range.location,
          utf16Length: range.length
        ))
      } : nil,
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

  func displayCardHistory(_ events: [MediaListeningSRSDatabaseClient.SRSCard.RecentReviewEvent]) {
    let historyVC = CardReviewHistoryVC(events: events)
    let nav = UINavigationController(rootViewController: historyVC)
    nav.modalPresentationStyle = .fullScreen
    present(nav, animated: true)
  }

  func displayEditTranscript(currentText: String) {
    let editor = TranscriptEditorVC(currentText: currentText) { [weak self] newText in
      self?.interactor.sendAction(.updateTranscript(newText))
    }
    editor.modalPresentationStyle = .fullScreen
    present(editor, animated: true)
  }

  func displayReadingCardCreated() {
    let toast = UILabel()
    toast.text = "  Reading card created  "
    toast.textColor = .white
    toast.backgroundColor = .systemGreen
    toast.textAlignment = .center
    toast.font = .systemFont(ofSize: 15, weight: .semibold)
    toast.layer.cornerRadius = 8
    toast.clipsToBounds = true
    toast.alpha = 0
    toast.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(toast)
    NSLayoutConstraint.activate([
      toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
      toast.heightAnchor.constraint(equalToConstant: 36),
    ])
    UIView.animate(withDuration: 0.25) { toast.alpha = 1 }
    UIView.animate(withDuration: 0.3, delay: 1.5, options: .curveEaseOut) {
      toast.alpha = 0
    } completion: { _ in
      toast.removeFromSuperview()
    }
  }
}
