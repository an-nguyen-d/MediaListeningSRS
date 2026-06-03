import UIKit
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_Shared
import SYNC_ElixirSyncClient

public final class SettingsVC: UIViewController {

  private let mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient
  private let elixirSyncClient: ElixirSyncClient
  private let tableView = UITableView(frame: .zero, style: .insetGrouped)
  private var retentionSlider: UISlider?
  private var retentionValueLabel: UILabel?
  private var coverageThresholdTextField: UITextField?
  private var inactivityTimeoutTextField: UITextField?
  private var syncIntervalTextField: UITextField?
  private var pushButton: UIButton?

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
    tableView.reloadSections(IndexSet(integer: syncSection), with: .none)
  }

  private let syncSection = 6

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

  public func numberOfSections(in tableView: UITableView) -> Int { 7 }

  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == syncSection { return 4 }
    return 1
  }

  public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
    case 0: return "Processing Queue"
    case 1: return "SRS Review"
    case 2: return "SRS Scheduling"
    case 3: return "Candidate Filtering"
    case 4: return "Study Tracking"
    case 5: return "LLM Grading"
    case 6: return "Sync"
    default: return nil
    }
  }

  public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    switch section {
    case 0:
      return "When enabled, a confirmation popup appears before skipping or making a card."
    case 1:
      return "Show or hide the Japanese transcript reveal area on the front of SRS review cards."
    case 2:
      return "Lower retention = longer intervals between reviews (more aggressive). Higher retention = shorter intervals (more conservative). Default is 90%. Takes effect on the next review of each card."
    case 3:
      return "Candidates where all tagged words are either known or already covered by this many cards will be auto-filtered from the processing queue. Only affects new imports and card creations going forward."
    case 4:
      return "If no review action occurs within this many seconds, the current study session ends. The next review action starts a new session. Default is 300 seconds (5 minutes)."
    case 5:
      return "System prompt sent to the local Ollama LLM when grading typed answers. Tap to edit. The Japanese transcript and English translation are appended automatically."
    case 6:
      return "Sync interval: how often the app checks for changes (minimum 10s). Takes effect on next app launch or foreground."
    default:
      return nil
    }
  }

  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch indexPath.section {
    case 0:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.textLabel?.text = "Require Confirmation"
      cell.selectionStyle = .none
      let toggle = UISwitch()
      toggle.isOn = MSRSAppSettings.requireSkipOrMakeCardConfirmation
      toggle.addTarget(self, action: #selector(confirmationToggleChanged(_:)), for: .valueChanged)
      cell.accessoryView = toggle
      return cell

    case 1:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.textLabel?.text = "Show Front Transcript"
      cell.selectionStyle = .none
      let toggle = UISwitch()
      toggle.isOn = MSRSAppSettings.showFrontTranscript
      toggle.addTarget(self, action: #selector(showFrontTranscriptToggleChanged(_:)), for: .valueChanged)
      cell.accessoryView = toggle
      return cell

    case 2:
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

    case 3:
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

    case 4:
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

    case 5:
      let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
      cell.textLabel?.text = "Grading Prompt"
      let prompt = MSRSAppSettings.llmGradingPrompt
      let preview = prompt.prefix(80).replacingOccurrences(of: "\n", with: " ")
      cell.detailTextLabel?.text = String(preview) + (prompt.count > 80 ? "…" : "")
      cell.detailTextLabel?.textColor = .secondaryLabel
      cell.accessoryType = .disclosureIndicator
      return cell

    case syncSection:
      return buildSyncCell(row: indexPath.row)

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
    if indexPath.section == 5 {
      let editor = LLMPromptEditorVC(mediaListeningSRSDatabaseClient: mediaListeningSRSDatabaseClient)
      editor.onSave = { [weak self] in
        self?.tableView.reloadSections(IndexSet(integer: 5), with: .none)
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
