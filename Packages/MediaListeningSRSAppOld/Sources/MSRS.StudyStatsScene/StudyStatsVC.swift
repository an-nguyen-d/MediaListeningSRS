import UIKit
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_SharedModels

public final class StudyStatsVC: UIViewController {

  public typealias Dependencies = HasMediaListeningSRSDatabaseClient

  private let dbClient: MediaListeningSRSDatabaseClient
  private let tableView = UITableView(frame: .zero, style: .insetGrouped)

  private var todayDuration: TimeInterval = 0
  private var todayCards: Int = 0
  private var todaySessions: Int = 0
  private var recentSessions: [StudySessionModel] = []

  public init(dependencies: Dependencies) {
    self.dbClient = dependencies.mediaListeningSRSDatabaseClient
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    title = "Study Stats"
    view.backgroundColor = .systemGroupedBackground

    tableView.dataSource = self
    tableView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    loadData()
  }

  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    loadData()
  }

  private func loadData() {
    let calendar = Calendar.current
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)
    let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

    let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: startOfToday)!

    Task { [dbClient] in
      do {
        let todayResponse = try await dbClient.studySession.fetchInDateRange(
          .init(startDate: startOfToday, endDate: endOfToday)
        )
        let recentResponse = try await dbClient.studySession.fetchInDateRange(
          .init(startDate: thirtyDaysAgo, endDate: endOfToday)
        )

        await MainActor.run {
          self.todayDuration = todayResponse.models.reduce(0) {
            $0 + $1.endedAt.timeIntervalSince($1.startedAt)
          }
          self.todayCards = todayResponse.models.reduce(0) { $0 + $1.cardsReviewed }
          self.todaySessions = todayResponse.models.count

          self.recentSessions = recentResponse.models.reversed()
          self.tableView.reloadData()
        }
      } catch {
        // Best-effort display
      }
    }
  }

  private func formatDuration(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    if hours > 0 {
      return String(format: "%dh %02dm", hours, minutes)
    } else if minutes > 0 {
      return String(format: "%dm %02ds", minutes, secs)
    } else {
      return "\(secs)s"
    }
  }

  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
  }()

  private static let timeOnlyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .none
    f.timeStyle = .short
    return f
  }()
}

extension StudyStatsVC: UITableViewDataSource {

  public func numberOfSections(in tableView: UITableView) -> Int { 2 }

  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case 0: return 3
    case 1: return max(recentSessions.count, 1)
    default: return 0
    }
  }

  public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
    case 0: return "Today"
    case 1: return "Recent Sessions (30 days)"
    default: return nil
    }
  }

  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch indexPath.section {
    case 0:
      let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
      cell.selectionStyle = .none
      switch indexPath.row {
      case 0:
        cell.textLabel?.text = "Study Time"
        cell.detailTextLabel?.text = formatDuration(todayDuration)
      case 1:
        cell.textLabel?.text = "Cards Reviewed"
        cell.detailTextLabel?.text = "\(todayCards)"
      case 2:
        cell.textLabel?.text = "Sessions"
        cell.detailTextLabel?.text = "\(todaySessions)"
      default:
        break
      }
      return cell

    case 1:
      if recentSessions.isEmpty {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "No study sessions yet"
        cell.textLabel?.textColor = .secondaryLabel
        cell.selectionStyle = .none
        return cell
      }

      let session = recentSessions[indexPath.row]
      let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
      cell.selectionStyle = .none

      let duration = session.endedAt.timeIntervalSince(session.startedAt)
      let startStr = Self.dateFormatter.string(from: session.startedAt)
      let endStr = Self.timeOnlyFormatter.string(from: session.endedAt)
      cell.textLabel?.text = "\(startStr) – \(endStr)"
      cell.detailTextLabel?.text = "\(formatDuration(duration))  ·  \(session.cardsReviewed) cards"
      cell.detailTextLabel?.textColor = .secondaryLabel
      return cell

    default:
      return UITableViewCell()
    }
  }
}
