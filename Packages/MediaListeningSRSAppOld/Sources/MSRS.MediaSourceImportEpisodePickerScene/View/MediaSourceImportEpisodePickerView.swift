import UIKit

final class MediaSourceImportEpisodePickerView: UIView {

  var onRowTapped: ((MediaSourceImportEpisodePickerModels.Row) -> Void)?

  private let tableView = UITableView(frame: .zero, style: .insetGrouped)
  private let loadingContainer = UIView()
  private let activityIndicator = UIActivityIndicatorView(style: .large)
  private let loadingLabel = UILabel()
  private let messageLabel = UILabel()
  private let importingOverlay = UIView()
  private let importingSpinner = UIActivityIndicatorView(style: .large)
  private let importingLabel = UILabel()
  private var sections: [MediaSourceImportEpisodePickerModels.Section] = []

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .systemBackground
    setUp()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setUp() {
    tableView.dataSource = self
    tableView.delegate = self
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    tableView.isHidden = true
    tableView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(tableView)

    activityIndicator.translatesAutoresizingMaskIntoConstraints = false
    loadingLabel.text = "Loading episodes…"
    loadingLabel.textColor = .secondaryLabel
    loadingLabel.font = .preferredFont(forTextStyle: .subheadline)
    loadingLabel.translatesAutoresizingMaskIntoConstraints = false
    loadingContainer.translatesAutoresizingMaskIntoConstraints = false
    loadingContainer.addSubview(activityIndicator)
    loadingContainer.addSubview(loadingLabel)
    addSubview(loadingContainer)

    messageLabel.numberOfLines = 0
    messageLabel.textAlignment = .center
    messageLabel.font = .preferredFont(forTextStyle: .body)
    messageLabel.isHidden = true
    messageLabel.translatesAutoresizingMaskIntoConstraints = false
    addSubview(messageLabel)

    importingOverlay.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.85)
    importingOverlay.isHidden = true
    importingOverlay.translatesAutoresizingMaskIntoConstraints = false
    addSubview(importingOverlay)

    importingSpinner.translatesAutoresizingMaskIntoConstraints = false
    importingOverlay.addSubview(importingSpinner)

    importingLabel.text = "Importing…"
    importingLabel.textColor = .label
    importingLabel.font = .preferredFont(forTextStyle: .headline)
    importingLabel.translatesAutoresizingMaskIntoConstraints = false
    importingOverlay.addSubview(importingLabel)

    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: topAnchor),
      tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: bottomAnchor),

      activityIndicator.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
      activityIndicator.topAnchor.constraint(equalTo: loadingContainer.topAnchor),
      loadingLabel.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
      loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 12),
      loadingLabel.bottomAnchor.constraint(equalTo: loadingContainer.bottomAnchor),
      loadingContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
      loadingContainer.centerYAnchor.constraint(equalTo: centerYAnchor),

      messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
      messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
      messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
      messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),

      importingOverlay.topAnchor.constraint(equalTo: topAnchor),
      importingOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
      importingOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
      importingOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
      importingSpinner.centerXAnchor.constraint(equalTo: importingOverlay.centerXAnchor),
      importingSpinner.centerYAnchor.constraint(equalTo: importingOverlay.centerYAnchor, constant: -16),
      importingLabel.centerXAnchor.constraint(equalTo: importingOverlay.centerXAnchor),
      importingLabel.topAnchor.constraint(equalTo: importingSpinner.bottomAnchor, constant: 12),
    ])
  }

  func setImporting(_ importing: Bool) {
    importingOverlay.isHidden = !importing
    if importing {
      importingSpinner.startAnimating()
    } else {
      importingSpinner.stopAnimating()
    }
    tableView.isUserInteractionEnabled = !importing
  }

  func setState(_ state: MediaSourceImportEpisodePickerModels.DisplayState) {
    switch state {
    case .loading:
      tableView.isHidden = true
      messageLabel.isHidden = true
      loadingContainer.isHidden = false
      activityIndicator.startAnimating()

    case .loaded(let sections):
      self.sections = sections
      tableView.reloadData()
      loadingContainer.isHidden = true
      activityIndicator.stopAnimating()
      let totalRows = sections.reduce(0) { $0 + $1.rows.count }
      if totalRows == 0 {
        tableView.isHidden = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.text = "No episodes match."
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

extension MediaSourceImportEpisodePickerView: UITableViewDataSource, UITableViewDelegate {

  func numberOfSections(in tableView: UITableView) -> Int {
    sections.count
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    sections[section].rows.count
  }

  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    sections[section].title
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
    let row = sections[indexPath.section].rows[indexPath.row]
    var content = cell.defaultContentConfiguration()
    content.text = row.title
    content.secondaryText = row.subtitle
    cell.contentConfiguration = content
    cell.accessoryType = .disclosureIndicator
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    onRowTapped?(sections[indexPath.section].rows[indexPath.row])
  }
}
