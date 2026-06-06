import UIKit
import MSRS_MediaListeningSRSDatabaseClient

final class CardReviewHistoryVC: UIViewController {

  private let events: [MediaListeningSRSDatabaseClient.SRSCard.RecentReviewEvent]
  private let tableView = UITableView(frame: .zero, style: .insetGrouped)

  private static let relativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .short
    return f
  }()

  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
  }()

  init(events: [MediaListeningSRSDatabaseClient.SRSCard.RecentReviewEvent]) {
    self.events = events
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Review History"
    view.backgroundColor = .systemGroupedBackground

    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .done,
      target: self,
      action: #selector(dismissTapped)
    )

    tableView.dataSource = self
    tableView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }

  @objc private func dismissTapped() {
    dismiss(animated: true)
  }
}

extension CardReviewHistoryVC: UITableViewDataSource {

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    max(events.count, 1)
  }

  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    "\(events.count) review\(events.count == 1 ? "" : "s")"
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if events.isEmpty {
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.textLabel?.text = "No reviews yet"
      cell.textLabel?.textColor = .secondaryLabel
      cell.selectionStyle = .none
      return cell
    }

    let event = events[indexPath.row]
    let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
    cell.selectionStyle = .none

    let grade = event.ratingRawValue <= 2 ? "Fail" : "Pass"
    let gradeColor: UIColor = event.ratingRawValue <= 2 ? .systemRed : .systemGreen
    let dateStr = Self.dateFormatter.string(from: event.occurredAt)
    let relativeStr = Self.relativeFormatter.localizedString(for: event.occurredAt, relativeTo: Date())

    cell.textLabel?.text = "\(grade) — \(dateStr) (\(relativeStr))"
    cell.textLabel?.textColor = gradeColor

    if let listens = event.listenCount {
      cell.detailTextLabel?.text = "\(listens) listen\(listens == 1 ? "" : "s")"
    }
    cell.detailTextLabel?.textColor = .secondaryLabel
    return cell
  }
}
