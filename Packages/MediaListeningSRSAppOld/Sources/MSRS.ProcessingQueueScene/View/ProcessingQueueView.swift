import UIKit
import MSRS_Shared
import MSRS_SharedModels

final class ProcessingQueueView: UIView {

  var onRowTapped: ((MediaSourceCardCandidateModel.ID) -> Void)?
  var onCreateAllTapped: (() -> Void)?

  let detailContainerView = UIView()

  var onInstructionsSaveRequested: ((String) -> Void)? {
    get { instructionsView.onSaveInstructions }
    set { instructionsView.onSaveInstructions = newValue }
  }

  var isEditingInstructions: Bool {
    instructionsView.isEditingInstructions
  }

  private let progressLabel = UILabel()
  private let progressSeparatorView = UIView()
  private let createAllButton = UIButton(type: .system)
  private let createAllSeparatorView = UIView()
  private let tableView = UITableView(frame: .zero, style: .insetGrouped)
  private let emptyLabel = UILabel()
  private let separatorView = UIView()
  private let instructionsView = ProcessingQueueInstructionsView()
  private let instructionsSeparatorView = UIView()
  private var rows: [ProcessingQueueModels.Row] = []
  private var selectedRowID: MediaSourceCardCandidateModel.ID?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .systemBackground
    setUpProgressLabel()
    setUpCreateAllBar()
    setUpTableView()
    setUpDetailContainer()
    setUpInstructionsPanel()
    setUpEmptyLabel()
    setUpSeparator()
    setUpConstraints()
    updateEmptyState()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setUpProgressLabel() {
    progressLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
    progressLabel.textColor = .secondaryLabel
    progressLabel.textAlignment = .center
    progressLabel.backgroundColor = .secondarySystemBackground
    addSubview(progressLabel)
    progressLabel.translatesAutoresizingMaskIntoConstraints = false

    progressSeparatorView.backgroundColor = .separator
    addSubview(progressSeparatorView)
    progressSeparatorView.translatesAutoresizingMaskIntoConstraints = false
  }

  private func setUpCreateAllBar() {
    var config = UIButton.Configuration.tinted()
    config.title = "Create All"
    config.image = UIImage(systemName: "plus.circle.fill")
    config.imagePadding = 6
    config.baseForegroundColor = .systemGreen
    config.baseBackgroundColor = .systemGreen
    config.buttonSize = .small
    createAllButton.configuration = config
    createAllButton.addTarget(self, action: #selector(createAllButtonTapped), for: .touchUpInside)
    addSubview(createAllButton)
    createAllButton.translatesAutoresizingMaskIntoConstraints = false

    createAllSeparatorView.backgroundColor = .separator
    addSubview(createAllSeparatorView)
    createAllSeparatorView.translatesAutoresizingMaskIntoConstraints = false
  }

  @objc private func createAllButtonTapped() {
    onCreateAllTapped?()
  }

  private func setUpTableView() {
    tableView.dataSource = self
    tableView.delegate = self
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    addSubview(tableView)
    tableView.translatesAutoresizingMaskIntoConstraints = false
  }

  private func setUpDetailContainer() {
    detailContainerView.backgroundColor = .systemBackground
    addSubview(detailContainerView)
    detailContainerView.translatesAutoresizingMaskIntoConstraints = false
  }

  private func setUpEmptyLabel() {
    emptyLabel.text = "All candidates processed."
    emptyLabel.textColor = .secondaryLabel
    emptyLabel.textAlignment = .center
    addSubview(emptyLabel)
    emptyLabel.translatesAutoresizingMaskIntoConstraints = false
  }

  private func setUpInstructionsPanel() {
    instructionsSeparatorView.backgroundColor = .separator
    addSubview(instructionsSeparatorView)
    instructionsSeparatorView.translatesAutoresizingMaskIntoConstraints = false

    addSubview(instructionsView)
    instructionsView.translatesAutoresizingMaskIntoConstraints = false
  }

  private func setUpSeparator() {
    separatorView.backgroundColor = .separator
    addSubview(separatorView)
    separatorView.translatesAutoresizingMaskIntoConstraints = false
  }

  private func setUpConstraints() {
    NSLayoutConstraint.activate([
      progressLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      progressLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
      progressLabel.widthAnchor.constraint(equalToConstant: 360),
      progressLabel.heightAnchor.constraint(equalToConstant: 36),

      progressSeparatorView.topAnchor.constraint(equalTo: progressLabel.bottomAnchor),
      progressSeparatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
      progressSeparatorView.widthAnchor.constraint(equalToConstant: 360),
      progressSeparatorView.heightAnchor.constraint(equalToConstant: 0.5),

      createAllButton.topAnchor.constraint(equalTo: progressSeparatorView.bottomAnchor, constant: 8),
      createAllButton.centerXAnchor.constraint(equalTo: progressLabel.centerXAnchor),

      createAllSeparatorView.topAnchor.constraint(equalTo: createAllButton.bottomAnchor, constant: 8),
      createAllSeparatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
      createAllSeparatorView.widthAnchor.constraint(equalToConstant: 360),
      createAllSeparatorView.heightAnchor.constraint(equalToConstant: 0.5),

      tableView.topAnchor.constraint(equalTo: createAllSeparatorView.bottomAnchor),
      tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
      tableView.widthAnchor.constraint(equalToConstant: 360),
      tableView.bottomAnchor.constraint(equalTo: bottomAnchor),

      separatorView.topAnchor.constraint(equalTo: topAnchor),
      separatorView.leadingAnchor.constraint(equalTo: tableView.trailingAnchor),
      separatorView.bottomAnchor.constraint(equalTo: bottomAnchor),
      separatorView.widthAnchor.constraint(equalToConstant: 1),

      detailContainerView.topAnchor.constraint(equalTo: topAnchor),
      detailContainerView.leadingAnchor.constraint(equalTo: separatorView.trailingAnchor),
      detailContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
      detailContainerView.bottomAnchor.constraint(equalTo: instructionsSeparatorView.topAnchor),

      instructionsSeparatorView.leadingAnchor.constraint(equalTo: separatorView.trailingAnchor),
      instructionsSeparatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
      instructionsSeparatorView.heightAnchor.constraint(equalToConstant: 1),

      instructionsView.topAnchor.constraint(equalTo: instructionsSeparatorView.bottomAnchor),
      instructionsView.leadingAnchor.constraint(equalTo: separatorView.trailingAnchor),
      instructionsView.trailingAnchor.constraint(equalTo: trailingAnchor),
      instructionsView.bottomAnchor.constraint(equalTo: bottomAnchor),

      emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
      emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
    ])
  }

  func setRows(_ rows: [ProcessingQueueModels.Row], totalCandidateCount: Int) {
    self.rows = rows
    tableView.reloadData()
    updateEmptyState()
    updateProgressLabel(remainingCount: rows.count, totalCount: totalCandidateCount)
    if let selectedRowID = self.selectedRowID,
       let index = rows.firstIndex(where: { $0.id == selectedRowID }) {
      let indexPath = IndexPath(row: index, section: 0)
      tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
    }
  }

  func setSelectedRowID(_ id: MediaSourceCardCandidateModel.ID?) {
    self.selectedRowID = id
    if let id = id, let index = rows.firstIndex(where: { $0.id == id }) {
      let indexPath = IndexPath(row: index, section: 0)
      tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
    } else {
      tableView.indexPathsForSelectedRows?.forEach {
        tableView.deselectRow(at: $0, animated: false)
      }
    }
  }

  /// Returns the row id at the current selection offset by `direction` (+1 or -1).
  /// Returns nil if at edge or if no row is selected.
  func rowIDAdjacentTo(_ currentID: MediaSourceCardCandidateModel.ID?, direction: Int) -> MediaSourceCardCandidateModel.ID? {
    guard !rows.isEmpty else { return nil }
    guard let currentID = currentID else {
      return direction >= 0 ? rows.first?.id : rows.last?.id
    }
    guard let currentIndex = rows.firstIndex(where: { $0.id == currentID }) else {
      return rows.first?.id
    }
    let newIndex = currentIndex + direction
    guard newIndex >= 0, newIndex < rows.count else { return nil }
    return rows[newIndex].id
  }

  func subtitleIndexFor(rowID: MediaSourceCardCandidateModel.ID) -> Int? {
    rows.first(where: { $0.id == rowID })?.subtitleIndex
  }

  func setInstructionsText(_ text: String) {
    instructionsView.setInstructionsText(text)
  }

  private func updateProgressLabel(remainingCount: Int, totalCount: Int) {
    guard totalCount > 0 else {
      progressLabel.text = ""
      return
    }
    let completedCount = totalCount - remainingCount
    let percentage = Int(round(Double(completedCount) / Double(totalCount) * 100))
    progressLabel.text = "\(completedCount)/\(totalCount)  \(percentage)%"
  }

  var currentRows: [ProcessingQueueModels.Row] { rows }

  func setCreateAllEnabled(_ enabled: Bool) {
    createAllButton.isEnabled = enabled
    createAllButton.alpha = enabled ? 1 : 0.5
  }

  private func updateEmptyState() {
    let empty = rows.isEmpty
    emptyLabel.isHidden = !empty
    createAllButton.isHidden = empty
    createAllSeparatorView.isHidden = empty
  }
}

extension ProcessingQueueView: UITableViewDataSource, UITableViewDelegate {

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    rows.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
    let row = rows[indexPath.row]
    var content = cell.defaultContentConfiguration()
    content.text = "Subtitle #\(row.subtitleIndex)"
    cell.contentConfiguration = content
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    onRowTapped?(rows[indexPath.row].id)
  }
}
