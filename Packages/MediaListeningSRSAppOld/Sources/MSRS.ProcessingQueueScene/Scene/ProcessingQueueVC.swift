import UIKit
import JML_JMLDatabaseClient
import MSRS_CandidateDetailScene
import MSRS_Shared
import MSRS_SharedModels

public final class ProcessingQueueVC: UIViewController, ProcessingQueueDisplayer {

  private let contentView = ProcessingQueueView()
  private let interactor: ProcessingQueueInteractor
  private let mediaSourceID: MediaSourceModel.ID
  private let dependencies: ProcessingQueueModels.Dependencies

  private var currentDetailVC: CandidateDetailVC?
  private var currentDetailVCCandidateID: MediaSourceCardCandidateModel.ID?
  /// Cached subtitle index of the currently-embedded candidate. Used to pick the next item
  /// after a skip/make-card removes the current one from the queue.
  private var currentDetailVCSubtitleIndex: Int?

  private static let instructionsUserDefaultsKeyPrefix = "MSRS.ProcessingQueue.instructions"

  private weak var activeConfirmationPopup: PopupOverlayView?
  private var pendingConfirmAction: (() -> Void)?

  public init(
    mediaSourceID: MediaSourceModel.ID,
    dependencies: ProcessingQueueModels.Dependencies
  ) {
    self.mediaSourceID = mediaSourceID
    self.dependencies = dependencies
    let presenter = ProcessingQueuePresenter()
    self.interactor = ProcessingQueueInteractor(
      presenter: presenter,
      mediaSourceID: mediaSourceID,
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
    contentView.onRowTapped = { [weak self] id in
      self?.interactor.sendAction(.rowTapped(id))
    }
    contentView.onInstructionsSaveRequested = { [weak self] text in
      self?.saveInstructions(text)
    }
    loadInstructions()
    interactor.sendAction(.viewDidLoad)
    showPlaceholder()
  }

  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    becomeFirstResponder()
  }

  public override var canBecomeFirstResponder: Bool { true }

  public override var keyCommands: [UIKeyCommand]? {
    if contentView.isEditingInstructions { return nil }
    var commands: [UIKeyCommand] = [
      UIKeyCommand(input: " ", modifierFlags: [], action: #selector(spacePressed), discoverabilityTitle: "Toggle Play/Pause"),
      UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(prevRowPressed), discoverabilityTitle: "Previous Subtitle"),
      UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(prevRowPressed), discoverabilityTitle: "Previous Subtitle"),
      UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(nextRowPressed), discoverabilityTitle: "Next Subtitle"),
      UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(nextRowPressed), discoverabilityTitle: "Next Subtitle"),
      UIKeyCommand(input: "y", modifierFlags: [], action: #selector(yPressed), discoverabilityTitle: "Make Card"),
      UIKeyCommand(input: "n", modifierFlags: [], action: #selector(nPressed), discoverabilityTitle: "Skip"),
      // Start time: Option+A (−0.3), Option+Shift+A (−1.0), Option+D (+0.3), Option+Shift+D (+1.0)
      UIKeyCommand(input: "a", modifierFlags: .alternate, action: #selector(startEarlierSmall), discoverabilityTitle: "Start −0.3s"),
      UIKeyCommand(input: "a", modifierFlags: [.alternate, .shift], action: #selector(startEarlierLarge), discoverabilityTitle: "Start −1.0s"),
      UIKeyCommand(input: "d", modifierFlags: .alternate, action: #selector(startLaterSmall), discoverabilityTitle: "Start +0.3s"),
      UIKeyCommand(input: "d", modifierFlags: [.alternate, .shift], action: #selector(startLaterLarge), discoverabilityTitle: "Start +1.0s"),
      // End time: Cmd+A (−0.3), Cmd+Shift+A (−1.0), Cmd+D (+0.3), Cmd+Shift+D (+1.0)
      UIKeyCommand(input: "a", modifierFlags: .command, action: #selector(endEarlierSmall), discoverabilityTitle: "End −0.3s"),
      UIKeyCommand(input: "a", modifierFlags: [.command, .shift], action: #selector(endEarlierLarge), discoverabilityTitle: "End −1.0s"),
      UIKeyCommand(input: "d", modifierFlags: .command, action: #selector(endLaterSmall), discoverabilityTitle: "End +0.3s"),
      UIKeyCommand(input: "d", modifierFlags: [.command, .shift], action: #selector(endLaterLarge), discoverabilityTitle: "End +1.0s"),
    ]
    if pendingConfirmAction != nil {
      commands.append(UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(enterPressed), discoverabilityTitle: "Confirm"))
    }
    return commands
  }

  // MARK: - Hotkey handlers

  @objc private func spacePressed() {
    currentDetailVC?.togglePlayPauseFromHost()
  }

  @objc private func prevRowPressed() {
    guard let adjacent = contentView.rowIDAdjacentTo(currentDetailVCCandidateID, direction: -1) else { return }
    interactor.sendAction(.rowTapped(adjacent))
  }

  @objc private func nextRowPressed() {
    guard let adjacent = contentView.rowIDAdjacentTo(currentDetailVCCandidateID, direction: 1) else { return }
    interactor.sendAction(.rowTapped(adjacent))
  }

  @objc private func yPressed() {
    guard currentDetailVCCandidateID != nil else { return }
    if MSRSAppSettings.requireSkipOrMakeCardConfirmation {
      askMakeCardConfirmation(for: currentDetailVCCandidateID!)
    } else {
      currentDetailVC?.triggerConfirmFromHost()
    }
  }

  @objc private func nPressed() {
    guard currentDetailVCCandidateID != nil else { return }
    if MSRSAppSettings.requireSkipOrMakeCardConfirmation {
      askSkipConfirmation(for: currentDetailVCCandidateID!)
    } else {
      currentDetailVC?.triggerSkipFromHost()
    }
  }

  @objc private func enterPressed() {
    pendingConfirmAction?()
  }

  @objc private func startEarlierSmall() { currentDetailVC?.adjustStartTimeFromHost(delta: -0.3) }
  @objc private func startEarlierLarge() { currentDetailVC?.adjustStartTimeFromHost(delta: -1.0) }
  @objc private func startLaterSmall() { currentDetailVC?.adjustStartTimeFromHost(delta: 0.3) }
  @objc private func startLaterLarge() { currentDetailVC?.adjustStartTimeFromHost(delta: 1.0) }

  @objc private func endEarlierSmall() { currentDetailVC?.adjustEndTimeFromHost(delta: -0.3) }
  @objc private func endEarlierLarge() { currentDetailVC?.adjustEndTimeFromHost(delta: -1.0) }
  @objc private func endLaterSmall() { currentDetailVC?.adjustEndTimeFromHost(delta: 0.3) }
  @objc private func endLaterLarge() { currentDetailVC?.adjustEndTimeFromHost(delta: 1.0) }

  // MARK: - Confirmation popups
  //
  // Every Skip / Make-Card invocation — whether via Y/N hotkey on the parent VC or via the
  // detail panel's own buttons — routes through these red/green giant confirmation popups
  // before firing the action on the embedded detail VC.

  private func askSkipConfirmation(for candidateID: MediaSourceCardCandidateModel.ID) {
    dismissConfirmationPopup()
    guard let subtitleIndex = subtitleIndexForCandidate(candidateID) else { return }
    let content = ConfirmationPopupContentView(
      message: "SKIP\nSubtitle #\(subtitleIndex)",
      hint: "Tap or press Enter to confirm · tap outside to cancel",
      accentColor: .systemRed
    )
    content.onConfirm = { [weak self] in
      self?.dismissConfirmationPopup()
      self?.currentDetailVC?.triggerSkipFromHost()
    }
    let popup = PopupOverlayView.present(content: content, in: view) { [weak self] in
      self?.activeConfirmationPopup = nil
      self?.pendingConfirmAction = nil
    }
    activeConfirmationPopup = popup
    pendingConfirmAction = { [weak self] in
      self?.dismissConfirmationPopup()
      self?.currentDetailVC?.triggerSkipFromHost()
    }
  }

  private func askMakeCardConfirmation(for candidateID: MediaSourceCardCandidateModel.ID) {
    dismissConfirmationPopup()
    guard let subtitleIndex = subtitleIndexForCandidate(candidateID) else { return }
    let content = ConfirmationPopupContentView(
      message: "MAKE CARD\nSubtitle #\(subtitleIndex)",
      hint: "Tap or press Enter to confirm · tap outside to cancel",
      accentColor: .systemGreen
    )
    content.onConfirm = { [weak self] in
      self?.dismissConfirmationPopup()
      self?.currentDetailVC?.triggerConfirmFromHost()
    }
    let popup = PopupOverlayView.present(content: content, in: view) { [weak self] in
      self?.activeConfirmationPopup = nil
      self?.pendingConfirmAction = nil
    }
    activeConfirmationPopup = popup
    pendingConfirmAction = { [weak self] in
      self?.dismissConfirmationPopup()
      self?.currentDetailVC?.triggerConfirmFromHost()
    }
  }

  private func dismissConfirmationPopup() {
    activeConfirmationPopup?.dismiss()
    activeConfirmationPopup = nil
    pendingConfirmAction = nil
  }

  private func subtitleIndexForCandidate(_ id: MediaSourceCardCandidateModel.ID) -> Int? {
    return contentView.subtitleIndexFor(rowID: id)
  }

  // MARK: - ProcessingQueueDisplayer

  private var totalCandidateCount: Int = 0

  func displayTitle(_ title: String) {
    self.title = title
  }

  func displayRows(_ rows: [ProcessingQueueModels.Row], totalCandidateCount: Int) {
    self.totalCandidateCount = totalCandidateCount
    contentView.setRows(rows, totalCandidateCount: totalCandidateCount)

    guard let currentID = currentDetailVCCandidateID,
          !rows.contains(where: { $0.id == currentID }) else {
      return
    }

    // The currently-embedded candidate just got filtered out (skip or card-create). Advance
    // to the next candidate at or after the same subtitle index; fall back to the previous
    // one if we were at the end; clear if no candidates remain.
    let pivotIndex = currentDetailVCSubtitleIndex ?? Int.max
    let nextRow = rows.first(where: { $0.subtitleIndex >= pivotIndex })
      ?? rows.last
    if let nextRow = nextRow {
      interactor.sendAction(.rowTapped(nextRow.id))
    } else {
      removeCurrentDetailVC()
      contentView.setSelectedRowID(nil)
      showPlaceholder()
    }
  }

  func displayError(_ message: String) {
    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
    alert.addAction(.init(title: "OK", style: .default))
    present(alert, animated: true)
  }

  func displayNavigateToCandidateDetail(
    candidateID: MediaSourceCardCandidateModel.ID,
    mediaSourceID: MediaSourceModel.ID
  ) {
    embedDetail(forCandidateID: candidateID)
    contentView.setSelectedRowID(candidateID)
  }

  // MARK: - Detail VC embedding

  private func embedDetail(forCandidateID candidateID: MediaSourceCardCandidateModel.ID) {
    removeCurrentDetailVC()

    let detailVC = CandidateDetailVC(
      candidateID: candidateID,
      mediaSourceID: mediaSourceID,
      dependencies: dependencies
    )
    // onDismiss intentionally not set — auto-advance in displayRows handles
    // transitioning to the next candidate after skip/card-create.
    detailVC.onSkipButtonTappedRequiresHostConfirmation = { [weak self] in
      if MSRSAppSettings.requireSkipOrMakeCardConfirmation {
        self?.askSkipConfirmation(for: candidateID)
      } else {
        self?.currentDetailVC?.triggerSkipFromHost()
      }
    }
    detailVC.onConfirmButtonTappedRequiresHostConfirmation = { [weak self] in
      if MSRSAppSettings.requireSkipOrMakeCardConfirmation {
        self?.askMakeCardConfirmation(for: candidateID)
      } else {
        self?.currentDetailVC?.triggerConfirmFromHost()
      }
    }
    addChild(detailVC)
    contentView.detailContainerView.subviews.forEach { $0.removeFromSuperview() }
    contentView.detailContainerView.addSubview(detailVC.view)
    detailVC.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      detailVC.view.topAnchor.constraint(equalTo: contentView.detailContainerView.topAnchor),
      detailVC.view.leadingAnchor.constraint(equalTo: contentView.detailContainerView.leadingAnchor),
      detailVC.view.trailingAnchor.constraint(equalTo: contentView.detailContainerView.trailingAnchor),
      detailVC.view.bottomAnchor.constraint(equalTo: contentView.detailContainerView.bottomAnchor),
    ])
    detailVC.didMove(toParent: self)
    currentDetailVC = detailVC
    currentDetailVCCandidateID = candidateID
    currentDetailVCSubtitleIndex = contentView.subtitleIndexFor(rowID: candidateID)
  }

  private func removeCurrentDetailVC() {
    guard let detailVC = currentDetailVC else { return }
    detailVC.willMove(toParent: nil)
    detailVC.view.removeFromSuperview()
    detailVC.removeFromParent()
    currentDetailVC = nil
    currentDetailVCCandidateID = nil
    currentDetailVCSubtitleIndex = nil
  }

  private func showPlaceholder() {
    let label = UILabel()
    label.text = "Select a candidate from the list"
    label.textColor = .secondaryLabel
    label.font = .preferredFont(forTextStyle: .title3)
    label.textAlignment = .center
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    contentView.detailContainerView.subviews.forEach { $0.removeFromSuperview() }
    contentView.detailContainerView.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: contentView.detailContainerView.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: contentView.detailContainerView.centerYAnchor),
      label.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.detailContainerView.leadingAnchor, constant: 24),
      label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.detailContainerView.trailingAnchor, constant: -24),
    ])
  }

  // MARK: - Instructions persistence

  private var instructionsUserDefaultsKey: String {
    "\(Self.instructionsUserDefaultsKeyPrefix).\(mediaSourceID.rawValue)"
  }

  private func loadInstructions() {
    let text = UserDefaults.standard.string(forKey: instructionsUserDefaultsKey) ?? ""
    contentView.setInstructionsText(text)
  }

  private func saveInstructions(_ text: String) {
    UserDefaults.standard.set(text, forKey: instructionsUserDefaultsKey)
  }
}
