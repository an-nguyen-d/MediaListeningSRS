import UIKit

final class MediaSourceImportPickerView: UIView {

  var onRowTapped: ((MediaSourceImportPickerModels.Row) -> Void)?

  private let tableView = UITableView(frame: .zero, style: .insetGrouped)

  private let loadingContainer = UIView()
  private let activityIndicator = UIActivityIndicatorView(style: .large)
  private let loadingLabel = UILabel()

  private let messageLabel = UILabel()

  private var rows: [MediaSourceImportPickerModels.Row] = []

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .systemBackground
    setUpTableView()
    setUpLoadingContainer()
    setUpMessageLabel()
    setUpConstraints()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Setup

  private func setUpTableView() {
    tableView.dataSource = self
    tableView.delegate = self
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    tableView.isHidden = true
    addSubview(tableView)
    tableView.translatesAutoresizingMaskIntoConstraints = false
  }

  private func setUpLoadingContainer() {
    activityIndicator.translatesAutoresizingMaskIntoConstraints = false
    loadingLabel.text = "Loading JML media…"
    loadingLabel.textColor = .secondaryLabel
    loadingLabel.font = .preferredFont(forTextStyle: .subheadline)
    loadingLabel.translatesAutoresizingMaskIntoConstraints = false

    loadingContainer.translatesAutoresizingMaskIntoConstraints = false
    loadingContainer.addSubview(activityIndicator)
    loadingContainer.addSubview(loadingLabel)
    addSubview(loadingContainer)

    NSLayoutConstraint.activate([
      activityIndicator.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
      activityIndicator.topAnchor.constraint(equalTo: loadingContainer.topAnchor),
      loadingLabel.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
      loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 12),
      loadingLabel.bottomAnchor.constraint(equalTo: loadingContainer.bottomAnchor),
    ])
  }

  private func setUpMessageLabel() {
    messageLabel.numberOfLines = 0
    messageLabel.textAlignment = .center
    messageLabel.font = .preferredFont(forTextStyle: .body)
    messageLabel.isHidden = true
    addSubview(messageLabel)
    messageLabel.translatesAutoresizingMaskIntoConstraints = false
  }

  private func setUpConstraints() {
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: topAnchor),
      tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: bottomAnchor),

      loadingContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
      loadingContainer.centerYAnchor.constraint(equalTo: centerYAnchor),

      messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
      messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
      messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
      messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
    ])
  }

  // MARK: - State

  func setState(_ state: MediaSourceImportPickerModels.DisplayState) {
    switch state {
    case .loading:
      tableView.isHidden = true
      messageLabel.isHidden = true
      loadingContainer.isHidden = false
      activityIndicator.startAnimating()

    case .loaded(let rows):
      self.rows = rows
      tableView.reloadData()
      loadingContainer.isHidden = true
      activityIndicator.stopAnimating()
      if rows.isEmpty {
        tableView.isHidden = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.text = "No JML media found.\nMake sure JapaneseMediaLibrary is populated."
        messageLabel.isHidden = false
      } else {
        tableView.isHidden = false
        messageLabel.isHidden = true
      }

    case .failed(let errorMessage):
      tableView.isHidden = true
      loadingContainer.isHidden = true
      activityIndicator.stopAnimating()
      messageLabel.textColor = .systemRed
      messageLabel.text = errorMessage
      messageLabel.isHidden = false
    }
  }
}

extension MediaSourceImportPickerView: UITableViewDataSource, UITableViewDelegate {

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
    onRowTapped?(rows[indexPath.row])
  }
}
