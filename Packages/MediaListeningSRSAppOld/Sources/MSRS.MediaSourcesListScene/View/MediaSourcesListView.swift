import UIKit
import MSRS_SharedModels

final class MediaSourcesListView: UIView {

  var onRowTapped: ((MediaSourceModel.ID) -> Void)?

  private let tableView = UITableView(frame: .zero, style: .insetGrouped)
  private let emptyLabel = UILabel()
  private var rows: [MediaSourcesListModels.Row] = []

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .systemBackground
    setUpTableView()
    setUpEmptyLabel()
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

  private func setUpEmptyLabel() {
    emptyLabel.text = "No imported sources yet.\nTap + to import one from JML."
    emptyLabel.textColor = .secondaryLabel
    emptyLabel.numberOfLines = 0
    emptyLabel.textAlignment = .center
    addSubview(emptyLabel)
    emptyLabel.translatesAutoresizingMaskIntoConstraints = false
  }

  private func setUpConstraints() {
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: topAnchor),
      tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: bottomAnchor),

      emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
      emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
      emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
      emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
    ])
  }

  func setRows(_ rows: [MediaSourcesListModels.Row]) {
    self.rows = rows
    tableView.reloadData()
    updateEmptyState()
  }

  private func updateEmptyState() {
    emptyLabel.isHidden = !rows.isEmpty
    tableView.isHidden = rows.isEmpty
  }
}

extension MediaSourcesListView: UITableViewDataSource, UITableViewDelegate {

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    rows.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
    let row = rows[indexPath.row]
    var content = cell.defaultContentConfiguration()
    content.text = row.title
    content.secondaryText = row.subtitle
    cell.contentConfiguration = content
    cell.accessoryType = .disclosureIndicator
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    onRowTapped?(rows[indexPath.row].id)
  }
}
