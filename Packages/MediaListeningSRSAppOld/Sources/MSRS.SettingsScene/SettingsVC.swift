import UIKit
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_Shared
import SYNC_ElixirSyncClient

public final class SettingsVC: UIViewController {

  private enum Section: Int, CaseIterable {
    case processingQueue
    case candidatePlayDelay
    case srsReview
    case condensedMode
    case buttonHeight
    case reviewFontSize
    case numpadHotkeys
    case feedbackEffects
    case videoEndSound
    case loopGapDelay
    case autoFlip
    case autoPass
    case clipPrefetch
    case scheduling
    case candidateFiltering
    case studyTracking
    case llmGrading
    case sync
    case floatingWindow
  }

  private let mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient
  private let elixirSyncClient: ElixirSyncClient
  private let tableView = UITableView(frame: .zero, style: .insetGrouped)
  private var retentionSlider: UISlider?
  private var retentionValueLabel: UILabel?
  private var coverageThresholdTextField: UITextField?
  private var inactivityTimeoutTextField: UITextField?
  private var syncIntervalTextField: UITextField?
  private var pushButton: UIButton?
  private var buttonHeightSlider: UISlider?
  private var buttonHeightValueLabel: UILabel?
  private var autoPassDelaySlider: UISlider?
  private var autoPassDelayValueLabel: UILabel?
  private var candidatePlayDelaySlider: UISlider?
  private var candidatePlayDelayValueLabel: UILabel?
  private var autoFlipDelaySlider: UISlider?
  private var autoFlipDelayValueLabel: UILabel?
  private var clipPrefetchStepper: UIStepper?
  private var clipPrefetchValueLabel: UILabel?
  private var videoEndSoundVolumeSlider: UISlider?
  private var videoEndSoundVolumeValueLabel: UILabel?
  private var loopGapDelaySlider: UISlider?
  private var loopGapDelayValueLabel: UILabel?
  private var transcriptFontSizeSlider: UISlider?
  private var transcriptFontSizeValueLabel: UILabel?
  private var transcriptFontPreviewLabel: UILabel?
  private var translationFontSizeSlider: UISlider?
  private var translationFontSizeValueLabel: UILabel?
  private var translationFontPreviewLabel: UILabel?

  public init(
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    elixirSyncClient: ElixirSyncClient
  ) {
    self.mediaListeningSRSDatabaseClient = mediaListeningSRSDatabaseClient
    self.elixirSyncClient = elixirSyncClient
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    title = "Settings"
    view.backgroundColor = .systemGroupedBackground
    tableView.dataSource = self
    tableView.delegate = self
    tableView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    SyncStatusTracker.onChange = { [weak self] in
      DispatchQueue.main.async {
        self?.reloadSyncSection()
      }
    }
  }

  deinit {
    SyncStatusTracker.onChange = nil
  }

  private func reloadSyncSection() {
    guard tableView.window != nil else { return }
    tableView.reloadSections(IndexSet(integer: Section.sync.rawValue), with: .none)
  }

  private func persistSettings() {
    let model = MSRSAppSettings.currentModel()
    Task { [mediaListeningSRSDatabaseClient] in
      try? await mediaListeningSRSDatabaseClient.appSettings.update(.init(model: model))
    }
  }

  @objc private func confirmationToggleChanged(_ sender: UISwitch) {
    MSRSAppSettings.requireSkipOrMakeCardConfirmation = sender.isOn
    persistSettings()
  }

  @objc private func showFrontTranscriptToggleChanged(_ sender: UISwitch) {
    MSRSAppSettings.showFrontTranscript = sender.isOn
    persistSettings()
  }

  @objc private func retentionSliderChanged(_ sender: UISlider) {
    let rounded = (Double(sender.value) * 100).rounded() / 100
    MSRSAppSettings.desiredRetention = rounded
    retentionValueLabel?.text = formatRetention(rounded)
    persistSettings()
  }

  @objc private func coverageThresholdEditingDidEnd(_ sender: UITextField) {
    let text = sender.text ?? ""
    let parsed = Int(text) ?? MSRSAppSettings.minimumCardCoverageCountDefault
    let clamped = max(1, parsed)
    MSRSAppSettings.minimumCardCoverageCount = clamped
    sender.text = "\(clamped)"
    persistSettings()
  }

  @objc private func inactivityTimeoutEditingDidEnd(_ sender: UITextField) {
    let text = sender.text ?? ""
    let parsed = Int(text) ?? MSRSAppSettings.studySessionInactivityTimeoutDefault
    let clamped = max(30, parsed)
    MSRSAppSettings.studySessionInactivityTimeout = clamped
    sender.text = "\(clamped)"
    persistSettings()
  }

  @objc private func syncIntervalEditingDidEnd(_ sender: UITextField) {
    let text = sender.text ?? ""
    let parsed = Int(text) ?? MSRSAppSettings.syncIntervalSecondsDefault
    let clamped = max(10, parsed)
    MSRSAppSettings.syncIntervalSeconds = clamped
    sender.text = "\(clamped)"
    persistSettings()
  }

  @objc private func floatingWindowToggleChanged(_ sender: UISwitch) {
    FloatingWindowSettings.isEnabled = sender.isOn
  }

  @objc private func condensedModeToggleChanged(_ sender: UISwitch) {
    MSRSAppSettings.condensedReviewMode = sender.isOn
  }

  @objc private func buttonHeightSliderChanged(_ sender: UISlider) {
    let rounded = CGFloat(sender.value.rounded())
    MSRSAppSettings.srsButtonHeight = rounded
    buttonHeightValueLabel?.text = "\(Int(rounded))pt"
  }

  @objc private func numpadHotkeysToggleChanged(_ sender: UISwitch) {
    MSRSAppSettings.numpadHotkeysEnabled = sender.isOn
  }

  @objc private func feedbackEffectsToggleChanged(_ sender: UISwitch) {
    MSRSAppSettings.reviewFeedbackEffectsEnabled = sender.isOn
  }

  @objc private func videoEndSoundVolumeSliderChanged(_ sender: UISlider) {
    let rounded = (Double(sender.value) * 100).rounded() / 100
    MSRSAppSettings.videoEndSoundVolume = rounded
    videoEndSoundVolumeValueLabel?.text = String(format: "%.0f%%", rounded * 100)
  }

  @objc private func loopGapDelaySliderChanged(_ sender: UISlider) {
    let rounded = (Double(sender.value) * 10).rounded() / 10
    MSRSAppSettings.loopGapDelay = rounded
    loopGapDelayValueLabel?.text = String(format: "%.1fs", rounded)
  }

  @objc private func autoFlipToggleChanged(_ sender: UISwitch) {
    MSRSAppSettings.autoFlipEnabled = sender.isOn
    tableView.reloadSections(IndexSet(integer: Section.autoFlip.rawValue), with: .none)
  }

  @objc private func autoFlipDelaySliderChanged(_ sender: UISlider) {
    let rounded = (Double(sender.value) * 10).rounded() / 10
    MSRSAppSettings.autoFlipDelay = rounded
    autoFlipDelayValueLabel?.text = String(format: "%.1fs", rounded)
  }

  @objc private func autoPassToggleChanged(_ sender: UISwitch) {
    MSRSAppSettings.autoPassEnabled = sender.isOn
    tableView.reloadSections(IndexSet(integer: Section.autoPass.rawValue), with: .none)
  }

  @objc private func autoPassDelaySliderChanged(_ sender: UISlider) {
    let rounded = (Double(sender.value) * 10).rounded() / 10
    MSRSAppSettings.autoPassDelay = rounded
    autoPassDelayValueLabel?.text = String(format: "%.1fs", rounded)
  }

  @objc private func candidatePlayDelaySliderChanged(_ sender: UISlider) {
    let rounded = (Double(sender.value) * 100).rounded() / 100
    MSRSAppSettings.candidatePlayDelay = rounded
    candidatePlayDelayValueLabel?.text = String(format: "%.2fs", rounded)
    persistSettings()
  }

  @objc private func transcriptFontSizeSliderChanged(_ sender: UISlider) {
    let rounded = CGFloat(sender.value.rounded())
    MSRSAppSettings.reviewTranscriptFontSize = rounded
    transcriptFontSizeValueLabel?.text = "\(Int(rounded))pt"
    transcriptFontPreviewLabel?.font = .systemFont(ofSize: rounded, weight: .regular)
  }

  @objc private func translationFontSizeSliderChanged(_ sender: UISlider) {
    let rounded = CGFloat(sender.value.rounded())
    MSRSAppSettings.reviewTranslationFontSize = rounded
    translationFontSizeValueLabel?.text = "\(Int(rounded))pt"
    translationFontPreviewLabel?.font = .systemFont(ofSize: rounded, weight: .regular)
  }

  @objc private func clipPrefetchStepperChanged(_ sender: UIStepper) {
    let value = Int(sender.value)
    MSRSAppSettings.clipPrefetchCount = value
    clipPrefetchValueLabel?.text = "\(value)"
  }

  @objc private func pushNowTapped() {
    pushButton?.isEnabled = false
    SyncStatusTracker.status = .pushing
    elixirSyncClient.push { result in
      DispatchQueue.main.async {
        switch result {
        case .failure(let error):
          SyncStatusTracker.status = .error(error.localizedDescription)
        case .success:
          SyncStatusTracker.status = .inSync
          SyncStatusTracker.lastPushDate = Date()
        }
      }
    }
  }

  private func formatRetention(_ value: Double) -> String {
    "\(Int(value * 100))%"
  }

  private func formatSyncDate(_ date: Date?) -> String {
    guard let date else { return "Never" }
    let interval = Date().timeIntervalSince(date)
    if interval < 60 { return "Just now" }
    if interval < 3600 {
      let minutes = Int(interval / 60)
      return "\(minutes)m ago"
    }
    if interval < 86400 {
      let hours = Int(interval / 3600)
      return "\(hours)h ago"
    }
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private func syncStatusText() -> (String, UIColor) {
    switch SyncStatusTracker.status {
    case .unknown: return ("Unknown", .secondaryLabel)
    case .inSync: return ("In Sync", .systemGreen)
    case .localNewer: return ("Local Newer", .systemOrange)
    case .checking: return ("Checking…", .secondaryLabel)
    case .pushing: return ("Pushing…", .secondaryLabel)
    case .error(let message): return ("Error: \(message)", .systemRed)
    }
  }
}

extension SettingsVC: UITableViewDataSource {

  public func numberOfSections(in tableView: UITableView) -> Int {
    Section.allCases.count
  }

  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    guard let s = Section(rawValue: section) else { return 0 }
    switch s {
    case .sync: return 4
    case .autoFlip: return MSRSAppSettings.autoFlipEnabled ? 2 : 1
    case .autoPass: return MSRSAppSettings.autoPassEnabled ? 2 : 1
    case .reviewFontSize: return 2
    #if targetEnvironment(macCatalyst)
    case .floatingWindow: return 1
    #else
    case .floatingWindow: return 0
    #endif
    default: return 1
    }
  }

  public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    guard let s = Section(rawValue: section) else { return nil }
    switch s {
    case .processingQueue: return "Processing Queue"
    case .candidatePlayDelay: return "Candidate Auto-Play Delay"
    case .srsReview: return "SRS Review"
    case .condensedMode: return "SRS Review Layout"
    case .buttonHeight: return "SRS Button Height"
    case .reviewFontSize: return "SRS Review Font Size"
    case .numpadHotkeys: return "Numpad Hotkeys"
    case .feedbackEffects: return "Review Feedback Effects"
    case .videoEndSound: return "Video End Sound"
    case .loopGapDelay: return "Loop Gap Delay"
    case .autoFlip: return "Auto-Flip to Back"
    case .autoPass: return "Auto-Pass"
    case .clipPrefetch: return "Clip Prefetch"
    case .scheduling: return "SRS Scheduling"
    case .candidateFiltering: return "Candidate Filtering"
    case .studyTracking: return "Study Tracking"
    case .llmGrading: return "LLM Grading"
    case .sync: return "Sync"
    #if targetEnvironment(macCatalyst)
    case .floatingWindow: return "Mac Window"
    #else
    case .floatingWindow: return nil
    #endif
    }
  }

  public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    guard let s = Section(rawValue: section) else { return nil }
    switch s {
    case .processingQueue:
      return "When enabled, a confirmation popup appears before skipping or making a card."
    case .candidatePlayDelay:
      return "Delay before auto-playing the video when a new processing candidate is shown. Set to 0 for immediate playback. Does not affect SRS reviews."
    case .srsReview:
      return "Show or hide the Japanese transcript reveal area on the front of SRS review cards."
    case .condensedMode:
      return "When enabled, the video fills the screen and all review UI floats on top with a gradient. Loop, speed, and other settings are available via a gear button. Dismiss review from the settings panel."
    case .buttonHeight:
      return "Height of the Show Back / Fail / Pass buttons during SRS review. Min \(Int(MSRSAppSettings.srsButtonHeightMin))pt, max \(Int(MSRSAppSettings.srsButtonHeightMax))pt."
    case .reviewFontSize:
      return "Font size for the Japanese transcript and English translation shown on the back of SRS review cards. Changes take effect on the next card."
    case .numpadHotkeys:
      return "Adds number key shortcuts during SRS review: 7 = show back, 8 = fail, 9 = pass, 4 = speed −0.1, 5 = play/pause, 6 = speed +0.1."
    case .feedbackEffects:
      return "Sound effects and screen flash overlay on grading cards. Applies to both SRS review and candidate processing."
    case .videoEndSound:
      return "Plays a sound when video/audio reaches the end during SRS review. Set volume to 0% to disable."
    case .loopGapDelay:
      return "Pause between the end of one loop and the start of the next when auto-loop is enabled. Applies to both SRS review and candidate processing."
    case .autoFlip:
      return "When enabled, after the audio plays through once, a countdown begins. When it reaches zero, the card automatically flips to show the back. Any tap while on the front cancels the auto-flip."
    case .autoPass:
      return "When enabled, the card auto-passes after the countdown expires. You can still manually grade or tap anywhere to cancel the auto-pass for that card."
    case .clipPrefetch:
      return "Number of upcoming clips to download ahead of the current card during SRS review. Higher values reduce wait times but use more bandwidth. Set to 0 to disable prefetching."
    case .scheduling:
      return "Lower retention = longer intervals between reviews (more aggressive). Higher retention = shorter intervals (more conservative). Default is 90%. Takes effect on the next review of each card."
    case .candidateFiltering:
      return "Candidates where all tagged words are either known or already covered by this many cards will be auto-filtered from the processing queue. Only affects new imports and card creations going forward."
    case .studyTracking:
      return "If no review action occurs within this many seconds, the current study session ends. The next review action starts a new session. Default is 300 seconds (5 minutes)."
    case .llmGrading:
      return "System prompt sent to the local Ollama LLM when grading typed answers. Tap to edit. The Japanese transcript and English translation are appended automatically."
    case .sync:
      return "Sync interval: how often the app checks for changes (minimum 10s). Takes effect on next app launch or foreground."
    case .floatingWindow:
      return "When enabled, the app window stays above all other windows."
    }
  }

  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }
    switch section {
    case .processingQueue:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.textLabel?.text = "Require Confirmation"
      cell.selectionStyle = .none
      let toggle = UISwitch()
      toggle.isOn = MSRSAppSettings.requireSkipOrMakeCardConfirmation
      toggle.addTarget(self, action: #selector(confirmationToggleChanged(_:)), for: .valueChanged)
      cell.accessoryView = toggle
      return cell

    case .candidatePlayDelay:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = ""

      let label = UILabel()
      label.text = "Delay"
      label.font = .preferredFont(forTextStyle: .body)
      label.setContentHuggingPriority(.required, for: .horizontal)

      let valueLabel = UILabel()
      valueLabel.text = String(format: "%.2fs", MSRSAppSettings.candidatePlayDelay)
      valueLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
      valueLabel.textAlignment = .right
      valueLabel.setContentHuggingPriority(.required, for: .horizontal)
      candidatePlayDelayValueLabel = valueLabel

      let slider = UISlider()
      slider.minimumValue = Float(MSRSAppSettings.candidatePlayDelayMin)
      slider.maximumValue = Float(MSRSAppSettings.candidatePlayDelayMax)
      slider.value = Float(MSRSAppSettings.candidatePlayDelay)
      slider.addTarget(self, action: #selector(candidatePlayDelaySliderChanged(_:)), for: .valueChanged)
      candidatePlayDelaySlider = slider

      let topRow = UIStackView(arrangedSubviews: [label, valueLabel])
      topRow.axis = .horizontal
      topRow.spacing = 8

      let stack = UIStackView(arrangedSubviews: [topRow, slider])
      stack.axis = .vertical
      stack.spacing = 8
      stack.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(stack)
      NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
        stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
        stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
        stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
      ])
      return cell

    case .srsReview:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.textLabel?.text = "Show Front Transcript"
      cell.selectionStyle = .none
      let toggle = UISwitch()
      toggle.isOn = MSRSAppSettings.showFrontTranscript
      toggle.addTarget(self, action: #selector(showFrontTranscriptToggleChanged(_:)), for: .valueChanged)
      cell.accessoryView = toggle
      return cell

    case .condensedMode:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.textLabel?.text = "Condensed Review Mode"
      cell.selectionStyle = .none
      let toggle = UISwitch()
      toggle.isOn = MSRSAppSettings.condensedReviewMode
      toggle.addTarget(self, action: #selector(condensedModeToggleChanged(_:)), for: .valueChanged)
      cell.accessoryView = toggle
      return cell

    case .buttonHeight:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = ""

      let label = UILabel()
      label.text = "Button Height"
      label.font = .preferredFont(forTextStyle: .body)
      label.setContentHuggingPriority(.required, for: .horizontal)

      let valueLabel = UILabel()
      valueLabel.text = "\(Int(MSRSAppSettings.srsButtonHeight))pt"
      valueLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
      valueLabel.textAlignment = .right
      valueLabel.setContentHuggingPriority(.required, for: .horizontal)
      buttonHeightValueLabel = valueLabel

      let slider = UISlider()
      slider.minimumValue = Float(MSRSAppSettings.srsButtonHeightMin)
      slider.maximumValue = Float(MSRSAppSettings.srsButtonHeightMax)
      slider.value = Float(MSRSAppSettings.srsButtonHeight)
      slider.addTarget(self, action: #selector(buttonHeightSliderChanged(_:)), for: .valueChanged)
      buttonHeightSlider = slider

      let topRow = UIStackView(arrangedSubviews: [label, valueLabel])
      topRow.axis = .horizontal
      topRow.spacing = 8

      let stack = UIStackView(arrangedSubviews: [topRow, slider])
      stack.axis = .vertical
      stack.spacing = 8
      stack.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(stack)
      NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
        stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
        stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
        stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
      ])
      return cell

    case .reviewFontSize:
      return buildReviewFontSizeCell(row: indexPath.row)

    case .numpadHotkeys:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.textLabel?.text = "Enable Numpad Hotkeys"
      cell.selectionStyle = .none
      let toggle = UISwitch()
      toggle.isOn = MSRSAppSettings.numpadHotkeysEnabled
      toggle.addTarget(self, action: #selector(numpadHotkeysToggleChanged(_:)), for: .valueChanged)
      cell.accessoryView = toggle
      return cell

    case .feedbackEffects:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.textLabel?.text = "Sound & Flash Effects"
      cell.selectionStyle = .none
      let toggle = UISwitch()
      toggle.isOn = MSRSAppSettings.reviewFeedbackEffectsEnabled
      toggle.addTarget(self, action: #selector(feedbackEffectsToggleChanged(_:)), for: .valueChanged)
      cell.accessoryView = toggle
      return cell

    case .videoEndSound:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = ""

      let label = UILabel()
      label.text = "Volume"
      label.font = .preferredFont(forTextStyle: .body)
      label.setContentHuggingPriority(.required, for: .horizontal)

      let valueLabel = UILabel()
      let currentVolume = MSRSAppSettings.videoEndSoundVolume
      valueLabel.text = String(format: "%.0f%%", currentVolume * 100)
      valueLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
      valueLabel.textAlignment = .right
      valueLabel.setContentHuggingPriority(.required, for: .horizontal)
      videoEndSoundVolumeValueLabel = valueLabel

      let slider = UISlider()
      slider.minimumValue = Float(MSRSAppSettings.videoEndSoundVolumeMin)
      slider.maximumValue = Float(MSRSAppSettings.videoEndSoundVolumeMax)
      slider.value = Float(currentVolume)
      slider.addTarget(self, action: #selector(videoEndSoundVolumeSliderChanged(_:)), for: .valueChanged)
      videoEndSoundVolumeSlider = slider

      let row = UIStackView(arrangedSubviews: [label, slider, valueLabel])
      row.axis = .horizontal
      row.spacing = 12
      row.alignment = .center
      row.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(row)
      NSLayoutConstraint.activate([
        row.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
        row.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
        row.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
        row.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
        valueLabel.widthAnchor.constraint(equalToConstant: 50),
      ])
      return cell

    case .loopGapDelay:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = ""

      let label = UILabel()
      label.text = "Delay"
      label.font = .preferredFont(forTextStyle: .body)
      label.setContentHuggingPriority(.required, for: .horizontal)

      let valueLabel = UILabel()
      let currentDelay = MSRSAppSettings.loopGapDelay
      valueLabel.text = String(format: "%.1fs", currentDelay)
      valueLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
      valueLabel.textAlignment = .right
      valueLabel.setContentHuggingPriority(.required, for: .horizontal)
      loopGapDelayValueLabel = valueLabel

      let slider = UISlider()
      slider.minimumValue = Float(MSRSAppSettings.loopGapDelayMin)
      slider.maximumValue = Float(MSRSAppSettings.loopGapDelayMax)
      slider.value = Float(currentDelay)
      slider.addTarget(self, action: #selector(loopGapDelaySliderChanged(_:)), for: .valueChanged)
      loopGapDelaySlider = slider

      let row = UIStackView(arrangedSubviews: [label, slider, valueLabel])
      row.axis = .horizontal
      row.spacing = 12
      row.alignment = .center
      row.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(row)
      NSLayoutConstraint.activate([
        row.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
        row.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
        row.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
        row.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
        valueLabel.widthAnchor.constraint(equalToConstant: 50),
      ])
      return cell

    case .autoFlip:
      return buildAutoFlipCell(row: indexPath.row)

    case .autoPass:
      return buildAutoPassCell(row: indexPath.row)

    case .clipPrefetch:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = ""

      let label = UILabel()
      label.text = "Prefetch Count"
      label.font = .preferredFont(forTextStyle: .body)
      label.setContentHuggingPriority(.defaultLow, for: .horizontal)

      let valueLabel = UILabel()
      valueLabel.text = "\(MSRSAppSettings.clipPrefetchCount)"
      valueLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
      valueLabel.textAlignment = .right
      valueLabel.setContentHuggingPriority(.required, for: .horizontal)
      clipPrefetchValueLabel = valueLabel

      let stepper = UIStepper()
      stepper.minimumValue = Double(MSRSAppSettings.clipPrefetchCountMin)
      stepper.maximumValue = Double(MSRSAppSettings.clipPrefetchCountMax)
      stepper.stepValue = 1
      stepper.value = Double(MSRSAppSettings.clipPrefetchCount)
      stepper.addTarget(self, action: #selector(clipPrefetchStepperChanged(_:)), for: .valueChanged)
      clipPrefetchStepper = stepper

      let row = UIStackView(arrangedSubviews: [label, valueLabel, stepper])
      row.axis = .horizontal
      row.spacing = 12
      row.alignment = .center
      row.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(row)
      NSLayoutConstraint.activate([
        row.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
        row.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
        row.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
        row.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
      ])
      return cell

    case .scheduling:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = ""

      let currentRetention = MSRSAppSettings.desiredRetention

      let label = UILabel()
      label.text = "Desired Retention"
      label.font = .preferredFont(forTextStyle: .body)
      label.setContentHuggingPriority(.required, for: .horizontal)

      let valueLabel = UILabel()
      valueLabel.text = formatRetention(currentRetention)
      valueLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
      valueLabel.textAlignment = .right
      valueLabel.setContentHuggingPriority(.required, for: .horizontal)
      retentionValueLabel = valueLabel

      let slider = UISlider()
      slider.minimumValue = 0.70
      slider.maximumValue = 0.97
      slider.value = Float(currentRetention)
      slider.addTarget(self, action: #selector(retentionSliderChanged(_:)), for: .valueChanged)
      retentionSlider = slider

      let topRow = UIStackView(arrangedSubviews: [label, valueLabel])
      topRow.axis = .horizontal
      topRow.spacing = 8

      let stack = UIStackView(arrangedSubviews: [topRow, slider])
      stack.axis = .vertical
      stack.spacing = 8
      stack.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(stack)
      NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
        stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
        stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
        stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
      ])
      return cell

    case .candidateFiltering:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = ""

      let label = UILabel()
      label.text = "Minimum Card Coverage Count"
      label.font = .preferredFont(forTextStyle: .body)
      label.setContentHuggingPriority(.defaultLow, for: .horizontal)

      let textField = UITextField()
      textField.text = "\(MSRSAppSettings.minimumCardCoverageCount)"
      textField.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
      textField.textAlignment = .right
      textField.keyboardType = .numberPad
      textField.borderStyle = .roundedRect
      textField.widthAnchor.constraint(equalToConstant: 80).isActive = true
      textField.addTarget(self, action: #selector(coverageThresholdEditingDidEnd(_:)), for: .editingDidEnd)
      coverageThresholdTextField = textField

      let row = UIStackView(arrangedSubviews: [label, textField])
      row.axis = .horizontal
      row.spacing = 12
      row.alignment = .center
      row.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(row)
      NSLayoutConstraint.activate([
        row.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
        row.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
        row.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
        row.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
      ])
      return cell

    case .studyTracking:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = ""

      let label = UILabel()
      label.text = "Inactivity Timeout (seconds)"
      label.font = .preferredFont(forTextStyle: .body)
      label.setContentHuggingPriority(.defaultLow, for: .horizontal)

      let textField = UITextField()
      textField.text = "\(MSRSAppSettings.studySessionInactivityTimeout)"
      textField.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
      textField.textAlignment = .right
      textField.keyboardType = .numberPad
      textField.borderStyle = .roundedRect
      textField.widthAnchor.constraint(equalToConstant: 80).isActive = true
      textField.addTarget(self, action: #selector(inactivityTimeoutEditingDidEnd(_:)), for: .editingDidEnd)
      inactivityTimeoutTextField = textField

      let row = UIStackView(arrangedSubviews: [label, textField])
      row.axis = .horizontal
      row.spacing = 12
      row.alignment = .center
      row.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(row)
      NSLayoutConstraint.activate([
        row.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
        row.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
        row.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
        row.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
      ])
      return cell

    case .llmGrading:
      let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
      cell.textLabel?.text = "Grading Prompt"
      let prompt = MSRSAppSettings.llmGradingPrompt
      let preview = prompt.prefix(80).replacingOccurrences(of: "\n", with: " ")
      cell.detailTextLabel?.text = String(preview) + (prompt.count > 80 ? "…" : "")
      cell.detailTextLabel?.textColor = .secondaryLabel
      cell.accessoryType = .disclosureIndicator
      return cell

    case .sync:
      return buildSyncCell(row: indexPath.row)

    case .floatingWindow:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.textLabel?.text = "Floating Window (Always on Top)"
      cell.selectionStyle = .none
      let toggle = UISwitch()
      toggle.isOn = FloatingWindowSettings.isEnabled
      toggle.addTarget(self, action: #selector(floatingWindowToggleChanged(_:)), for: .valueChanged)
      cell.accessoryView = toggle
      return cell
    }
  }

  private func buildReviewFontSizeCell(row: Int) -> UITableViewCell {
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.selectionStyle = .none
    cell.textLabel?.text = ""

    switch row {
    case 0:
      let label = UILabel()
      label.text = "Japanese Transcript"
      label.font = .preferredFont(forTextStyle: .body)
      label.setContentHuggingPriority(.required, for: .horizontal)

      let valueLabel = UILabel()
      let currentSize = MSRSAppSettings.reviewTranscriptFontSize
      valueLabel.text = "\(Int(currentSize))pt"
      valueLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
      valueLabel.textAlignment = .right
      valueLabel.setContentHuggingPriority(.required, for: .horizontal)
      transcriptFontSizeValueLabel = valueLabel

      let slider = UISlider()
      slider.minimumValue = Float(MSRSAppSettings.reviewTranscriptFontSizeMin)
      slider.maximumValue = Float(MSRSAppSettings.reviewTranscriptFontSizeMax)
      slider.value = Float(currentSize)
      slider.addTarget(self, action: #selector(transcriptFontSizeSliderChanged(_:)), for: .valueChanged)
      transcriptFontSizeSlider = slider

      let preview = UILabel()
      preview.text = "日本語のプレビュー"
      preview.font = .systemFont(ofSize: currentSize, weight: .regular)
      preview.textColor = .label
      preview.numberOfLines = 0
      preview.textAlignment = .center
      transcriptFontPreviewLabel = preview

      let topRow = UIStackView(arrangedSubviews: [label, valueLabel])
      topRow.axis = .horizontal
      topRow.spacing = 8

      let stack = UIStackView(arrangedSubviews: [topRow, slider, preview])
      stack.axis = .vertical
      stack.spacing = 8
      stack.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(stack)
      NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
        stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
        stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
        stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
      ])

    case 1:
      let label = UILabel()
      label.text = "English Translation"
      label.font = .preferredFont(forTextStyle: .body)
      label.setContentHuggingPriority(.required, for: .horizontal)

      let valueLabel = UILabel()
      let currentSize = MSRSAppSettings.reviewTranslationFontSize
      valueLabel.text = "\(Int(currentSize))pt"
      valueLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
      valueLabel.textAlignment = .right
      valueLabel.setContentHuggingPriority(.required, for: .horizontal)
      translationFontSizeValueLabel = valueLabel

      let slider = UISlider()
      slider.minimumValue = Float(MSRSAppSettings.reviewTranslationFontSizeMin)
      slider.maximumValue = Float(MSRSAppSettings.reviewTranslationFontSizeMax)
      slider.value = Float(currentSize)
      slider.addTarget(self, action: #selector(translationFontSizeSliderChanged(_:)), for: .valueChanged)
      translationFontSizeSlider = slider

      let preview = UILabel()
      preview.text = "English translation preview"
      preview.font = .systemFont(ofSize: currentSize, weight: .regular)
      preview.textColor = .secondaryLabel
      preview.numberOfLines = 0
      preview.textAlignment = .center
      translationFontPreviewLabel = preview

      let topRow = UIStackView(arrangedSubviews: [label, valueLabel])
      topRow.axis = .horizontal
      topRow.spacing = 8

      let stack = UIStackView(arrangedSubviews: [topRow, slider, preview])
      stack.axis = .vertical
      stack.spacing = 8
      stack.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(stack)
      NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
        stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
        stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
        stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
      ])

    default:
      break
    }

    return cell
  }

  private func buildAutoFlipCell(row: Int) -> UITableViewCell {
    switch row {
    case 0:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.textLabel?.text = "Auto-Flip to Back"
      cell.selectionStyle = .none
      let toggle = UISwitch()
      toggle.isOn = MSRSAppSettings.autoFlipEnabled
      toggle.addTarget(self, action: #selector(autoFlipToggleChanged(_:)), for: .valueChanged)
      cell.accessoryView = toggle
      return cell

    case 1:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = ""

      let label = UILabel()
      label.text = "Delay"
      label.font = .preferredFont(forTextStyle: .body)
      label.setContentHuggingPriority(.required, for: .horizontal)

      let valueLabel = UILabel()
      valueLabel.text = String(format: "%.1fs", MSRSAppSettings.autoFlipDelay)
      valueLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
      valueLabel.textAlignment = .right
      valueLabel.setContentHuggingPriority(.required, for: .horizontal)
      autoFlipDelayValueLabel = valueLabel

      let slider = UISlider()
      slider.minimumValue = Float(MSRSAppSettings.autoFlipDelayMin)
      slider.maximumValue = Float(MSRSAppSettings.autoFlipDelayMax)
      slider.value = Float(MSRSAppSettings.autoFlipDelay)
      slider.addTarget(self, action: #selector(autoFlipDelaySliderChanged(_:)), for: .valueChanged)
      autoFlipDelaySlider = slider

      let topRow = UIStackView(arrangedSubviews: [label, valueLabel])
      topRow.axis = .horizontal
      topRow.spacing = 8

      let stack = UIStackView(arrangedSubviews: [topRow, slider])
      stack.axis = .vertical
      stack.spacing = 8
      stack.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(stack)
      NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
        stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
        stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
        stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
      ])
      return cell

    default:
      return UITableViewCell()
    }
  }

  private func buildAutoPassCell(row: Int) -> UITableViewCell {
    switch row {
    case 0:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.textLabel?.text = "Auto-Pass"
      cell.selectionStyle = .none
      let toggle = UISwitch()
      toggle.isOn = MSRSAppSettings.autoPassEnabled
      toggle.addTarget(self, action: #selector(autoPassToggleChanged(_:)), for: .valueChanged)
      cell.accessoryView = toggle
      return cell

    case 1:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = ""

      let label = UILabel()
      label.text = "Delay"
      label.font = .preferredFont(forTextStyle: .body)
      label.setContentHuggingPriority(.required, for: .horizontal)

      let valueLabel = UILabel()
      valueLabel.text = String(format: "%.1fs", MSRSAppSettings.autoPassDelay)
      valueLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
      valueLabel.textAlignment = .right
      valueLabel.setContentHuggingPriority(.required, for: .horizontal)
      autoPassDelayValueLabel = valueLabel

      let slider = UISlider()
      slider.minimumValue = Float(MSRSAppSettings.autoPassDelayMin)
      slider.maximumValue = Float(MSRSAppSettings.autoPassDelayMax)
      slider.value = Float(MSRSAppSettings.autoPassDelay)
      slider.addTarget(self, action: #selector(autoPassDelaySliderChanged(_:)), for: .valueChanged)
      autoPassDelaySlider = slider

      let topRow = UIStackView(arrangedSubviews: [label, valueLabel])
      topRow.axis = .horizontal
      topRow.spacing = 8

      let stack = UIStackView(arrangedSubviews: [topRow, slider])
      stack.axis = .vertical
      stack.spacing = 8
      stack.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(stack)
      NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
        stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
        stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
        stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
      ])
      return cell

    default:
      return UITableViewCell()
    }
  }

  private func buildSyncCell(row: Int) -> UITableViewCell {
    switch row {
    case 0:
      let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = "Status"
      let (text, color) = syncStatusText()
      cell.detailTextLabel?.text = text
      cell.detailTextLabel?.textColor = color
      return cell

    case 1:
      let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = "Last Check"
      cell.detailTextLabel?.text = formatSyncDate(SyncStatusTracker.lastSyncCheckDate)
      cell.detailTextLabel?.textColor = .secondaryLabel
      return cell

    case 2:
      let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = "Last Push"
      cell.detailTextLabel?.text = formatSyncDate(SyncStatusTracker.lastPushDate)
      cell.detailTextLabel?.textColor = .secondaryLabel
      return cell

    case 3:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = ""

      let intervalLabel = UILabel()
      intervalLabel.text = "Interval (seconds)"
      intervalLabel.font = .preferredFont(forTextStyle: .body)
      intervalLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

      let textField = UITextField()
      textField.text = "\(MSRSAppSettings.syncIntervalSeconds)"
      textField.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
      textField.textAlignment = .right
      textField.keyboardType = .numberPad
      textField.borderStyle = .roundedRect
      textField.widthAnchor.constraint(equalToConstant: 80).isActive = true
      textField.addTarget(self, action: #selector(syncIntervalEditingDidEnd(_:)), for: .editingDidEnd)
      syncIntervalTextField = textField

      var pushConfig = UIButton.Configuration.tinted()
      pushConfig.title = "Push Now"
      pushConfig.baseBackgroundColor = .systemBlue
      pushConfig.baseForegroundColor = .systemBlue
      pushConfig.cornerStyle = .medium
      pushConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
      let button = UIButton(configuration: pushConfig)
      button.translatesAutoresizingMaskIntoConstraints = false
      button.addTarget(self, action: #selector(pushNowTapped), for: .touchUpInside)

      let isPushable: Bool
      switch SyncStatusTracker.status {
      case .localNewer: isPushable = true
      default: isPushable = false
      }
      button.isEnabled = isPushable
      pushButton = button

      let row = UIStackView(arrangedSubviews: [intervalLabel, textField, button])
      row.axis = .horizontal
      row.spacing = 12
      row.alignment = .center
      row.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(row)
      NSLayoutConstraint.activate([
        row.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
        row.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
        row.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
        row.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
      ])
      return cell

    default:
      return UITableViewCell()
    }
  }
}

extension SettingsVC: UITableViewDelegate {
  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard let section = Section(rawValue: indexPath.section) else { return }
    if section == .llmGrading {
      let editor = LLMPromptEditorVC(mediaListeningSRSDatabaseClient: mediaListeningSRSDatabaseClient)
      editor.onSave = { [weak self] in
        self?.tableView.reloadSections(IndexSet(integer: Section.llmGrading.rawValue), with: .none)
      }
      navigationController?.pushViewController(editor, animated: true)
    }
  }
}

private final class LLMPromptEditorVC: UIViewController {

  private let mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient
  private let textView = UITextView()
  var onSave: (() -> Void)?

  init(mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient) {
    self.mediaListeningSRSDatabaseClient = mediaListeningSRSDatabaseClient
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Grading Prompt"
    view.backgroundColor = .systemBackground

    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: "Reset", style: .plain, target: self, action: #selector(resetToDefault)
    )

    textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
    textView.text = MSRSAppSettings.llmGradingPrompt
    textView.autocorrectionType = .no
    textView.autocapitalizationType = .none
    textView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(textView)

    NSLayoutConstraint.activate([
      textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
    ])
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    let trimmed = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
      MSRSAppSettings.llmGradingPrompt = trimmed
      persistSettings()
    }
    onSave?()
  }

  @objc private func resetToDefault() {
    textView.text = MSRSAppSettings.llmGradingPromptDefault
    MSRSAppSettings.llmGradingPrompt = MSRSAppSettings.llmGradingPromptDefault
    persistSettings()
  }

  private func persistSettings() {
    let model = MSRSAppSettings.currentModel()
    Task { [mediaListeningSRSDatabaseClient] in
      try? await mediaListeningSRSDatabaseClient.appSettings.update(.init(model: model))
    }
  }
}
