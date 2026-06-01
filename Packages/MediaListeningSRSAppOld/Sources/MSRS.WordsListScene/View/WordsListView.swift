import UIKit

final class WordsListView: UIView {

  var onSortChanged: ((WordsListModels.SortField) -> Void)?
  var onKnownFilterChanged: ((WordsListModels.KnownFilter) -> Void)?
  var onSearchQueryChanged: ((String) -> Void)?
  var onScrolledNearBottom: (() -> Void)?
  var onMarkAsKnownTapped: ((Int64) -> Void)?

  static let columnPosition: CGFloat = 60
  static let columnFrequencyRank: CGFloat = 90
  static let columnSpelling: CGFloat = 260
  static let columnReading: CGFloat = 260
  static let columnKnown: CGFloat = 120
  static let columnCoverage: CGFloat = 110

  private let toolbarContainer = UIView()
  private let sortSegmentedControl = UISegmentedControl(items: WordsListModels.SortField.allCases.map(\.rawValue))
  private let filterSegmentedControl = UISegmentedControl(items: WordsListModels.KnownFilter.allCases.map(\.rawValue))
  private let searchField = UISearchTextField()
  private let statsLabel = UILabel()

  private let legendRow = UIView()
  private let tableView = UITableView(frame: .zero, style: .plain)

  private var rows: [WordsListModels.WordRow] = []
  private var hasMorePages = true

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .systemBackground
    setUpToolbar()
    setUpLegend()
    setUpTableView()
    setUpConstraints()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Setup

  private func setUpToolbar() {
    toolbarContainer.translatesAutoresizingMaskIntoConstraints = false
    toolbarContainer.backgroundColor = .secondarySystemBackground

    sortSegmentedControl.selectedSegmentIndex = 0
    sortSegmentedControl.addTarget(self, action: #selector(sortChanged), for: .valueChanged)
    sortSegmentedControl.translatesAutoresizingMaskIntoConstraints = false

    filterSegmentedControl.selectedSegmentIndex = 0
    filterSegmentedControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
    filterSegmentedControl.translatesAutoresizingMaskIntoConstraints = false

    searchField.placeholder = "Search spelling or meaning…"
    searchField.font = .systemFont(ofSize: 22)
    searchField.translatesAutoresizingMaskIntoConstraints = false
    searchField.addTarget(self, action: #selector(searchFieldChanged), for: .editingChanged)
    searchField.returnKeyType = .search

    statsLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .regular)
    statsLabel.textColor = .secondaryLabel
    statsLabel.translatesAutoresizingMaskIntoConstraints = false
    statsLabel.setContentHuggingPriority(.required, for: .horizontal)

    let sortLabel = UILabel()
    sortLabel.text = "Sort:"
    sortLabel.font = .systemFont(ofSize: 22, weight: .regular)
    sortLabel.textColor = .secondaryLabel
    sortLabel.setContentHuggingPriority(.required, for: .horizontal)

    let filterLabel = UILabel()
    filterLabel.text = "Filter:"
    filterLabel.font = .systemFont(ofSize: 22, weight: .regular)
    filterLabel.textColor = .secondaryLabel
    filterLabel.setContentHuggingPriority(.required, for: .horizontal)

    let topRow = UIStackView(arrangedSubviews: [
      sortLabel, sortSegmentedControl,
      filterLabel, filterSegmentedControl,
      statsLabel
    ])
    topRow.axis = .horizontal
    topRow.spacing = 12
    topRow.alignment = .center
    topRow.translatesAutoresizingMaskIntoConstraints = false

    toolbarContainer.addSubview(topRow)
    toolbarContainer.addSubview(searchField)

    NSLayoutConstraint.activate([
      topRow.topAnchor.constraint(equalTo: toolbarContainer.topAnchor, constant: 12),
      topRow.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor, constant: 16),
      topRow.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor, constant: -16),

      searchField.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 10),
      searchField.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor, constant: 16),
      searchField.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor, constant: -16),
      searchField.heightAnchor.constraint(equalToConstant: 40),
      searchField.bottomAnchor.constraint(equalTo: toolbarContainer.bottomAnchor, constant: -12),
    ])
  }

  private func setUpLegend() {
    legendRow.translatesAutoresizingMaskIntoConstraints = false
    legendRow.backgroundColor = .tertiarySystemBackground

    let separator = UIView()
    separator.backgroundColor = .separator
    separator.translatesAutoresizingMaskIntoConstraints = false
    legendRow.addSubview(separator)
    NSLayoutConstraint.activate([
      separator.leadingAnchor.constraint(equalTo: legendRow.leadingAnchor),
      separator.trailingAnchor.constraint(equalTo: legendRow.trailingAnchor),
      separator.bottomAnchor.constraint(equalTo: legendRow.bottomAnchor),
      separator.heightAnchor.constraint(equalToConstant: 0.5),
    ])

    let columns: [(String, CGFloat, NSTextAlignment)] = [
      ("#", Self.columnPosition, .right),
      ("Freq", Self.columnFrequencyRank, .right),
      ("Spelling", Self.columnSpelling, .left),
      ("Reading", Self.columnReading, .left),
      ("Definition", 0, .left),
      ("Known", Self.columnKnown, .center),
      ("Cards", Self.columnCoverage, .right),
    ]

    let stack = UIStackView()
    stack.axis = .horizontal
    stack.spacing = 0
    stack.translatesAutoresizingMaskIntoConstraints = false

    for (title, width, alignment) in columns {
      let label = UILabel()
      label.text = title
      label.font = .systemFont(ofSize: 20, weight: .semibold)
      label.textColor = .secondaryLabel
      label.textAlignment = alignment
      label.translatesAutoresizingMaskIntoConstraints = false

      if width > 0 {
        label.widthAnchor.constraint(equalToConstant: width).isActive = true
      } else {
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      }

      stack.addArrangedSubview(label)
    }

    legendRow.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: legendRow.topAnchor, constant: 10),
      stack.leadingAnchor.constraint(equalTo: legendRow.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: legendRow.trailingAnchor, constant: -16),
      stack.bottomAnchor.constraint(equalTo: legendRow.bottomAnchor, constant: -10),
    ])
  }

  private func setUpTableView() {
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.dataSource = self
    tableView.delegate = self
    tableView.register(WordsListRowCell.self, forCellReuseIdentifier: WordsListRowCell.reuseIdentifier)
    tableView.rowHeight = 72
    tableView.separatorInset = .init(top: 0, left: 16, bottom: 0, right: 16)
  }

  private func setUpConstraints() {
    addSubview(toolbarContainer)
    addSubview(legendRow)
    addSubview(tableView)

    NSLayoutConstraint.activate([
      toolbarContainer.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      toolbarContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
      toolbarContainer.trailingAnchor.constraint(equalTo: trailingAnchor),

      legendRow.topAnchor.constraint(equalTo: toolbarContainer.bottomAnchor),
      legendRow.leadingAnchor.constraint(equalTo: leadingAnchor),
      legendRow.trailingAnchor.constraint(equalTo: trailingAnchor),

      tableView.topAnchor.constraint(equalTo: legendRow.bottomAnchor),
      tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  // MARK: - Public

  func setViewModel(_ viewModel: WordsListModels.ViewModel) {
    rows = viewModel.rows
    hasMorePages = viewModel.hasMorePages
    let knownCount = viewModel.rows.filter(\.isKnown).count
    statsLabel.text = "\(viewModel.totalLoaded) loaded · \(knownCount) known"
    tableView.reloadData()
  }

  // MARK: - Actions

  @objc private func sortChanged() {
    let fields = WordsListModels.SortField.allCases
    guard sortSegmentedControl.selectedSegmentIndex < fields.count else { return }
    onSortChanged?(fields[sortSegmentedControl.selectedSegmentIndex])
  }

  @objc private func filterChanged() {
    let filters = WordsListModels.KnownFilter.allCases
    guard filterSegmentedControl.selectedSegmentIndex < filters.count else { return }
    onKnownFilterChanged?(filters[filterSegmentedControl.selectedSegmentIndex])
  }

  @objc private func searchFieldChanged() {
    onSearchQueryChanged?(searchField.text ?? "")
  }
}

// MARK: - UITableViewDataSource

extension WordsListView: UITableViewDataSource {

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    rows.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(
      withIdentifier: WordsListRowCell.reuseIdentifier,
      for: indexPath
    ) as! WordsListRowCell
    let row = rows[indexPath.row]
    cell.configure(with: row)
    cell.onMarkAsKnownTapped = { [weak self] termID in
      self?.onMarkAsKnownTapped?(termID)
    }
    return cell
  }
}

// MARK: - UITableViewDelegate

extension WordsListView: UITableViewDelegate {

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let offsetY = scrollView.contentOffset.y
    let contentHeight = scrollView.contentSize.height
    let frameHeight = scrollView.frame.height
    if offsetY > contentHeight - frameHeight * 2, hasMorePages {
      onScrolledNearBottom?()
    }
  }

  func tableView(
    _ tableView: UITableView,
    contextMenuConfigurationForRowAt indexPath: IndexPath,
    point: CGPoint
  ) -> UIContextMenuConfiguration? {
    let row = rows[indexPath.row]
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
      var actions: [UIAction] = []
      if !row.isKnown {
        actions.append(UIAction(
          title: "Mark as Known",
          image: UIImage(systemName: "checkmark.circle")
        ) { _ in
          self?.onMarkAsKnownTapped?(row.termID)
        })
      }
      actions.append(UIAction(
        title: "Copy Spelling",
        image: UIImage(systemName: "doc.on.doc")
      ) { _ in
        UIPasteboard.general.string = row.primarySpelling
      })
      return UIMenu(children: actions)
    }
  }
}

// MARK: - WordsListRowCell

final class WordsListRowCell: UITableViewCell {

  static let reuseIdentifier = "WordsListRowCell"

  var onMarkAsKnownTapped: ((Int64) -> Void)?

  private let positionLabel = UILabel()
  private let frequencyRankLabel = UILabel()
  private let spellingLabel = UILabel()
  private let readingLabel = UILabel()
  private let definitionLabel = UILabel()
  private let knownButton = UIButton(type: .system)
  private let coverageLabel = UILabel()
  private let rowStack = UIStackView()
  private var currentTermID: Int64 = 0

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    setUpRow()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setUpRow() {
    positionLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .regular)
    positionLabel.textColor = .tertiaryLabel
    positionLabel.textAlignment = .right
    positionLabel.translatesAutoresizingMaskIntoConstraints = false
    positionLabel.widthAnchor.constraint(equalToConstant: WordsListView.columnPosition).isActive = true

    frequencyRankLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .regular)
    frequencyRankLabel.textColor = .secondaryLabel
    frequencyRankLabel.textAlignment = .right
    frequencyRankLabel.translatesAutoresizingMaskIntoConstraints = false
    frequencyRankLabel.widthAnchor.constraint(equalToConstant: WordsListView.columnFrequencyRank).isActive = true

    spellingLabel.font = .systemFont(ofSize: 26, weight: .medium)
    spellingLabel.translatesAutoresizingMaskIntoConstraints = false
    spellingLabel.widthAnchor.constraint(equalToConstant: WordsListView.columnSpelling).isActive = true

    readingLabel.font = .systemFont(ofSize: 24, weight: .regular)
    readingLabel.textColor = .secondaryLabel
    readingLabel.translatesAutoresizingMaskIntoConstraints = false
    readingLabel.widthAnchor.constraint(equalToConstant: WordsListView.columnReading).isActive = true

    definitionLabel.font = .systemFont(ofSize: 22, weight: .regular)
    definitionLabel.textColor = .secondaryLabel
    definitionLabel.lineBreakMode = .byTruncatingTail
    definitionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    definitionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    knownButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .medium)
    knownButton.translatesAutoresizingMaskIntoConstraints = false
    knownButton.widthAnchor.constraint(equalToConstant: WordsListView.columnKnown).isActive = true
    knownButton.addTarget(self, action: #selector(knownButtonTapped), for: .touchUpInside)

    coverageLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .regular)
    coverageLabel.textColor = .secondaryLabel
    coverageLabel.textAlignment = .right
    coverageLabel.translatesAutoresizingMaskIntoConstraints = false
    coverageLabel.widthAnchor.constraint(equalToConstant: WordsListView.columnCoverage).isActive = true

    rowStack.axis = .horizontal
    rowStack.spacing = 0
    rowStack.alignment = .center
    rowStack.translatesAutoresizingMaskIntoConstraints = false

    rowStack.addArrangedSubview(positionLabel)
    rowStack.addArrangedSubview(frequencyRankLabel)
    rowStack.addArrangedSubview(spellingLabel)
    rowStack.addArrangedSubview(readingLabel)
    rowStack.addArrangedSubview(definitionLabel)
    rowStack.addArrangedSubview(knownButton)
    rowStack.addArrangedSubview(coverageLabel)

    contentView.addSubview(rowStack)
    NSLayoutConstraint.activate([
      rowStack.topAnchor.constraint(equalTo: contentView.topAnchor),
      rowStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      rowStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      rowStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
    ])
  }

  func configure(with row: WordsListModels.WordRow) {
    currentTermID = row.termID
    positionLabel.text = "\(row.position)"
    frequencyRankLabel.text = row.frequencyRank.map { "\($0)" } ?? "—"
    spellingLabel.text = row.primarySpelling
    readingLabel.text = row.reading
    definitionLabel.text = row.definitionSummary

    if row.isKnown {
      knownButton.setTitle("✓ Known", for: .normal)
      knownButton.setTitleColor(.systemGreen, for: .normal)
      knownButton.isEnabled = false
    } else {
      knownButton.setTitle("Mark", for: .normal)
      knownButton.setTitleColor(.systemBlue, for: .normal)
      knownButton.isEnabled = true
    }

    coverageLabel.text = row.cardCoverageCount > 0 ? "\(row.cardCoverageCount)" : "—"
  }

  @objc private func knownButtonTapped() {
    onMarkAsKnownTapped?(currentTermID)
  }
}
