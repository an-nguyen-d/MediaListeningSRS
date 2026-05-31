import UIKit
import MSRS_Shared
import MSRS_SharedModels

final class ProcessingQueueView: UIView {

  var onRowTapped: ((MediaSourceCardCandidateModel.ID) -> Void)?

  let detailContainerView = UIView()

  private let tableView = UITableView(frame: .zero, style: .insetGrouped)
  private let emptyLabel = UILabel()
  private let separatorView = UIView()
  private var rows: [ProcessingQueueModels.Row] = []
  private var selectedRowID: MediaSourceCardCandidateModel.ID?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .systemBackground
    setUpTableView()
    setUpDetailContainer()
    setUpEmptyLabel()
    setUpSeparator()
    setUpConstraints()
    updateEmptyState()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
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

  private func setUpSeparator() {
    separatorView.backgroundColor = .separator
    addSubview(separatorView)
    separatorView.translatesAutoresizingMaskIntoConstraints = false
  }

  private func setUpConstraints() {
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: topAnchor),
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
      detailContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),

      emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
      emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
    ])
  }

  func setRows(_ rows: [ProcessingQueueModels.Row]) {
    self.rows = rows
    tableView.reloadData()
    updateEmptyState()
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

  private func updateEmptyState() {
    emptyLabel.isHidden = !rows.isEmpty
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
